# ==============================================================================
# ATOMUS Flutter App - Proguard Rules for Release Builds
# ==============================================================================

# ------------------------------------------------------------------------------
# Flutter Engine & Wrapper Rules
# ------------------------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class runtime.Union* { *; }
-dontwarn io.flutter.embedding.**

# Keep Flutter methods referenced via JNI/Reflection
-keepclasseswithmembers class * {
    native <methods>;
}
-keepattributes SourceFile,LineNumberTable,Deprecated,Signature,InnerClasses,EnclosingMethod,*Annotation*

# ------------------------------------------------------------------------------
# AndroidX & Multidex Rules
# ------------------------------------------------------------------------------
-keep class androidx.multidex.** { *; }
-dontwarn androidx.multidex.**

# ------------------------------------------------------------------------------
# Firebase Rules
# ------------------------------------------------------------------------------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.internal.firebase-perf.** { *; }
-dontwarn com.google.firebase.**

# ------------------------------------------------------------------------------
# Supabase & Networking Rules (OkHttp, Okio, WebSockets)
# ------------------------------------------------------------------------------
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-keepattributes Signature,*Annotation*,EnclosingMethod,InnerClasses
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# ------------------------------------------------------------------------------
# Hive Database Rules
# ------------------------------------------------------------------------------
-keep class com.hivedb.** { *; }
-keep class io.hive.** { *; }
-dontwarn com.hivedb.**
-dontwarn io.hive.**

# ------------------------------------------------------------------------------
# Printing / PDF Rules
# ------------------------------------------------------------------------------
-keep class com.sun.pdfview.** { *; }
-dontwarn com.sun.pdfview.**
