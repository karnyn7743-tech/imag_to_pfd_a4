# حماية مكتبة Google ML Kit من الحذف أو التشويه بواسطة R8
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# حماية الواجهات الخاصة بـ Flutter ومكتباتها الأساسية
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.plugin.**
