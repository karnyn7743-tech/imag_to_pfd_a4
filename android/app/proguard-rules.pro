-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

-keep class com.baseflow.permissionhandler.** { *; }
-keep class com.dexterous.** { *; }
-keep class com.tekartik.sqflite.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }

-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
