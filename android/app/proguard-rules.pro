# Flutter / Dart default rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# FFmpegKit — keep all JNI native methods, configs, and flutter plugin paths
-keep class com.arthenica.ffmpegkit.** { *; }
-keepclassmembers class com.arthenica.ffmpegkit.** { *; }
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-keepclassmembers class com.antonkarpenko.ffmpegkit.** { *; }
-keep class com.arthenica.smartexception.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Kotlin metadata (needed by some reflection-based libraries)
-keep class kotlin.Metadata { *; }

# Suppress warnings for missing optional dependencies
-dontwarn com.arthenica.**
-dontwarn org.bouncycastle.**

# Google Play Core — Flutter engine references these for deferred components
# but they are not needed for direct APK distribution.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# File picker plugin — R8 strips this in release builds causing silent failure
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Permission handler plugin
-keep class com.baseflow.permissionhandler.** { *; }

# open_filex — opens converted files and the output folder
-keep class com.crazecoder.openfile.** { *; }

# share_plus — shares converted files via Android share sheet
-keep class dev.fluttercommunity.plus.share.** { *; }
