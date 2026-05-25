// lib/core/backup/backup_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/app_database.dart';

class BackupService {
  static const _backupFolderName = 'FamilyFinanceBackup';
  static const _scopes = [drive.DriveApi.driveFileScope];

  final AppDatabase db;
  final GoogleSignIn _googleSignIn;

  BackupService({required this.db})
      : _googleSignIn = GoogleSignIn(scopes: _scopes);

  // ─── AUTH ──────────────────────────────────────────────────────────────────

  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account;
    } catch (e) {
      throw BackupException('Failed to sign in to Google: $e');
    }
  }

  Future<void> signOut() => _googleSignIn.signOut();

  Future<bool> get isSignedIn => _googleSignIn.isSignedIn();

  Future<GoogleSignInAccount?> get currentUser async => _googleSignIn.currentUser;

  // ─── BACKUP ────────────────────────────────────────────────────────────────

  Future<BackupResult> createAndUploadBackup() async {
    final account = _googleSignIn.currentUser ?? await _googleSignIn.signIn();
    if (account == null) throw BackupException('Not signed in to Google');

    final authHeaders = await account.authHeaders;
    final client = _GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(client);

    // Step 1: Export data to JSON
    final jsonData = await _exportToJson();

    // Step 2: Compress to ZIP
    final zipBytes = await _compressToZip(jsonData);

    // Step 3: Get/create backup folder
    final folderId = await _getOrCreateFolder(driveApi);

    // Step 4: Upload to Drive
    final now = DateTime.now();
    final fileName =
        'family_finance_${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}.zip';

    final media = drive.Media(
      Stream.fromIterable([zipBytes]),
      zipBytes.length,
      contentType: 'application/zip',
    );

    final fileMetadata = drive.File()
      ..name = fileName
      ..parents = [folderId]
      ..description = 'Family Finance & Zakat Manager backup';

    final uploaded = await driveApi.files.create(
      fileMetadata,
      uploadMedia: media,
    );

    // Step 5: Update last backup timestamp
    await db.settingsDao.set('last_backup', now.toIso8601String());

    client.close();

    return BackupResult(
      fileId: uploaded.id ?? '',
      fileName: fileName,
      fileSize: zipBytes.length,
      timestamp: now,
    );
  }

  // ─── RESTORE ───────────────────────────────────────────────────────────────

  Future<List<BackupFile>> listBackups() async {
    final account = _googleSignIn.currentUser ?? await _googleSignIn.signIn();
    if (account == null) throw BackupException('Not signed in to Google');

    final authHeaders = await account.authHeaders;
    final client = _GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(client);

    final folderId = await _getOrCreateFolder(driveApi);
    final fileList = await driveApi.files.list(
      q: "'$folderId' in parents and trashed = false and name contains 'family_finance'",
      orderBy: 'createdTime desc',
      $fields: 'files(id, name, size, createdTime)',
    );

    client.close();
    return (fileList.files ?? []).map((f) => BackupFile(
      id: f.id ?? '',
      name: f.name ?? '',
      size: int.tryParse(f.size ?? '0') ?? 0,
      createdAt: f.createdTime ?? DateTime.now(),
    )).toList();
  }

  Future<void> restoreFromBackup(String fileId) async {
    final account = _googleSignIn.currentUser ?? await _googleSignIn.signIn();
    if (account == null) throw BackupException('Not signed in to Google');

    final authHeaders = await account.authHeaders;
    final client = _GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(client);

    // Download file
    final media = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    client.close();

    // Extract ZIP
    final archive = ZipDecoder().decodeBytes(bytes);
    Map<String, dynamic>? jsonData;

    for (final file in archive) {
      if (file.name == 'backup.json') {
        final content = utf8.decode(file.content as List<int>);
        jsonData = json.decode(content) as Map<String, dynamic>;
        break;
      }
    }

    if (jsonData == null) throw BackupException('Invalid backup file format');

    // Restore data
    await _importFromJson(jsonData);
  }

  // ─── LOCAL EXPORT ──────────────────────────────────────────────────────────

  Future<File> exportToLocalFile() async {
    final jsonData = await _exportToJson();
    final zipBytes = await _compressToZip(jsonData);
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final fileName =
        'family_finance_${now.year}${_pad(now.month)}${_pad(now.day)}.zip';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(zipBytes);
    return file;
  }

  Future<void> importFromLocalFile(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    Map<String, dynamic>? jsonData;

    for (final archiveFile in archive) {
      if (archiveFile.name == 'backup.json') {
        final content = utf8.decode(archiveFile.content as List<int>);
        jsonData = json.decode(content) as Map<String, dynamic>;
        break;
      }
    }

    if (jsonData == null) throw BackupException('Invalid backup file format');
    await _importFromJson(jsonData);
  }

  // ─── PRIVATE HELPERS ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _exportToJson() async {
    final transactions = await db.transactionDao.getAllForExport();
    final assets = await db.assetDao.getAllForExport();
    final liabilitiesList = await db.liabilityDao.getAllForExport();
    final zakatSnapshots = await db.zakatDao.getAllForExport();
    final categories = await db.categoryDao.getAll();
    final settings = await db.settingsDao.getAll();

    return {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'transactions': transactions.map(_transactionToJson).toList(),
      'assets': assets.map(_assetToJson).toList(),
      'liabilities': liabilitiesList.map(_liabilityToJson).toList(),
      'zakatSnapshots': zakatSnapshots.map(_zakatSnapshotToJson).toList(),
      'categories': categories.map(_categoryToJson).toList(),
      'settings': settings,
    };
  }

  Future<List<int>> _compressToZip(Map<String, dynamic> jsonData) async {
    final jsonString = json.encode(jsonData);
    final jsonBytes = utf8.encode(jsonString);

    final archive = Archive();
    archive.addFile(ArchiveFile('backup.json', jsonBytes.length, jsonBytes));

    return ZipEncoder().encode(archive)!;
  }

  Future<String> _getOrCreateFolder(drive.DriveApi driveApi) async {
    // Search for existing folder
    final existing = await driveApi.files.list(
      q: "mimeType='application/vnd.google-apps.folder' and name='$_backupFolderName' and trashed=false",
      $fields: 'files(id)',
    );

    if (existing.files != null && existing.files!.isNotEmpty) {
      return existing.files!.first.id!;
    }

    // Create new folder
    final folder = drive.File()
      ..name = _backupFolderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await driveApi.files.create(folder);
    return created.id!;
  }

  Future<void> _importFromJson(Map<String, dynamic> data) async {
    await db.transaction(() async {
      // Import categories first (skip system ones)
      if (data['categories'] != null) {
        for (final cat in data['categories'] as List) {
          final m = cat as Map<String, dynamic>;
          if (m['isSystem'] == true) continue;
          await db.categoryDao.insertCategory(CategoriesCompanion.insert(
            uuid: m['uuid'] as String,
            name: m['name'] as String,
            nameUrdu: Value(m['nameUrdu'] as String?),
            type: m['type'] as String,
            icon: Value(m['icon'] as String? ?? 'category'),
            color: Value(m['color'] as String? ?? '#2196F3'),
          ));
        }
      }

      // Import assets
      if (data['assets'] != null) {
        for (final asset in data['assets'] as List) {
          final m = asset as Map<String, dynamic>;
          await db.assetDao.insertAsset(AssetsCompanion.insert(
            uuid: m['uuid'] as String,
            name: m['name'] as String,
            type: m['type'] as String,
            currentValue: m['currentValue'] as double,
            purchaseValue: Value((m['purchaseValue'] as num?)?.toDouble() ?? 0.0),
            quantity: Value((m['quantity'] as num?)?.toDouble()),
            unit: Value(m['unit'] as String?),
            location: Value(m['location'] as String?),
            notes: Value(m['notes'] as String?),
            isZakatApplicable: Value(m['isZakatApplicable'] as bool? ?? true),
            purchaseDate: Value(m['purchaseDate'] != null ? DateTime.parse(m['purchaseDate'] as String) : null),
          ));
        }
      }

      // Import transactions
      if (data['transactions'] != null) {
        for (final tx in data['transactions'] as List) {
          final m = tx as Map<String, dynamic>;
          await db.transactionDao.insertTransaction(TransactionsCompanion.insert(
            uuid: m['uuid'] as String,
            title: m['title'] as String,
            amount: (m['amount'] as num).toDouble(),
            type: m['type'] as String,
            categoryId: m['categoryId'] as String,
            subcategory: Value(m['subcategory'] as String?),
            paymentMethod: m['paymentMethod'] as String,
            notes: Value(m['notes'] as String?),
            transactionDate: DateTime.parse(m['transactionDate'] as String),
          ));
        }
      }

      // Import liabilities
      if (data['liabilities'] != null) {
        for (final lib in data['liabilities'] as List) {
          final m = lib as Map<String, dynamic>;
          await db.liabilityDao.insertLiability(LiabilitiesCompanion.insert(
            uuid: m['uuid'] as String,
            personName: m['personName'] as String,
            personPhone: Value(m['personPhone'] as String?),
            type: m['type'] as String,
            totalAmount: (m['totalAmount'] as num).toDouble(),
            remainingAmount: (m['remainingAmount'] as num).toDouble(),
            monthlyInstallment: Value((m['monthlyInstallment'] as num?)?.toDouble() ?? 0.0),
            startDate: DateTime.parse(m['startDate'] as String),
            dueDate: Value(m['dueDate'] != null ? DateTime.parse(m['dueDate'] as String) : null),
            status: Value(m['status'] as String? ?? 'active'),
            notes: Value(m['notes'] as String?),
          ));
        }
      }
    });
  }

  // ─── JSON SERIALIZERS ──────────────────────────────────────────────────────

  Map<String, dynamic> _transactionToJson(Transaction t) => {
    'uuid': t.uuid, 'title': t.title, 'amount': t.amount, 'type': t.type,
    'categoryId': t.categoryId, 'subcategory': t.subcategory,
    'paymentMethod': t.paymentMethod, 'notes': t.notes,
    'transactionDate': t.transactionDate.toIso8601String(),
  };

  Map<String, dynamic> _assetToJson(Asset a) => {
    'uuid': a.uuid, 'name': a.name, 'type': a.type,
    'currentValue': a.currentValue, 'purchaseValue': a.purchaseValue,
    'quantity': a.quantity, 'unit': a.unit, 'location': a.location,
    'notes': a.notes, 'isZakatApplicable': a.isZakatApplicable,
    'purchaseDate': a.purchaseDate?.toIso8601String(),
  };

  Map<String, dynamic> _liabilityToJson(Liability l) => {
    'uuid': l.uuid, 'personName': l.personName, 'personPhone': l.personPhone,
    'type': l.type, 'totalAmount': l.totalAmount,
    'remainingAmount': l.remainingAmount, 'monthlyInstallment': l.monthlyInstallment,
    'startDate': l.startDate.toIso8601String(), 'dueDate': l.dueDate?.toIso8601String(),
    'status': l.status, 'notes': l.notes,
  };

  Map<String, dynamic> _zakatSnapshotToJson(ZakatSnapshot z) => {
    'year': z.year, 'cashAmount': z.cashAmount, 'goldValue': z.goldValue,
    'silverValue': z.silverValue, 'businessAssets': z.businessAssets,
    'otherAssets': z.otherAssets, 'totalLiabilities': z.totalLiabilities,
    'zakatableWealth': z.zakatableWealth, 'zakatAmount': z.zakatAmount,
    'zakatDue': z.zakatDue, 'calculatedAt': z.calculatedAt.toIso8601String(),
  };

  Map<String, dynamic> _categoryToJson(Category c) => {
    'uuid': c.uuid, 'name': c.name, 'nameUrdu': c.nameUrdu,
    'type': c.type, 'icon': c.icon, 'color': c.color,
    'isSystem': c.isSystem,
  };

  String _pad(int n) => n.toString().padLeft(2, '0');
}

// ─── HTTP CLIENT ──────────────────────────────────────────────────────────────

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

// ─── MODELS ───────────────────────────────────────────────────────────────────

class BackupResult {
  final String fileId;
  final String fileName;
  final int fileSize;
  final DateTime timestamp;

  const BackupResult({
    required this.fileId,
    required this.fileName,
    required this.fileSize,
    required this.timestamp,
  });
}

class BackupFile {
  final String id;
  final String name;
  final int size;
  final DateTime createdAt;

  const BackupFile({
    required this.id,
    required this.name,
    required this.size,
    required this.createdAt,
  });
}

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);
  @override
  String toString() => 'BackupException: $message';
}
