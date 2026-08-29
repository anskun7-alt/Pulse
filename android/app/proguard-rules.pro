# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Better Player (ExoPlayer)
-keep class com.better.player.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }
-dontwarn com.better.player.**
-dontwarn com.google.android.exoplayer2.**
-dontwarn androidx.media3.**

# Google Play Core (for dynamic features)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep serialization
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses

# Keep Hive
-keep class androidx.room.** { *; }
-keep class com.hivex.** { *; }

# Keep just_audio
-keep class com.github.nielsendev.** { *; }
-dontwarn com.github.nielsendev.*

# Keep media metadata
-keep class com.github.nielsendev.** { *; }

# Keep reflection for metadata extraction
-keep class com.github.nielsendev.player.** { *; }
-keep class com.github.nielsendev.media.** { *; }

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Keep permission handler
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# Keep path provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# Keep share_plus
-keep class io.flutter.plugins.shareplus.** { *; }
