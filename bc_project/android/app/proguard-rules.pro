# Keep Drift ORM
-keep class app.cash.sqldelight.** { *; }
-keep class com.squareup.sqldelight.** { *; }

# Keep Google Sign-In
-keep class com.google.android.gms.** { *; }
-keep class com.google.api.** { *; }
-dontwarn com.google.android.gms.**

# Keep Kotlin coroutines
-keepclassmembers class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Keep Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Keep OkHttp (used by Google APIs)
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep JSON serialization
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep Biometric
-keep class androidx.biometric.** { *; }

# Keep local_auth plugin
-keep class io.flutter.plugins.localauth.** { *; }

# Remove debug logging in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
