# ─── Flutter ──────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.**

# ─── Kotlin coroutines ────────────────────────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory { *; }
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler { *; }
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}
-dontwarn kotlinx.coroutines.**

# ─── Supabase / Ktor ──────────────────────────────────────────────────────────
-keep class io.github.jan.supabase.** { *; }
-keep class io.ktor.** { *; }
-keepattributes *Annotation*
-dontwarn io.ktor.**
-dontwarn io.github.jan.**

# ─── Hive (local storage) ─────────────────────────────────────────────────────
# Hive uses reflection for TypeAdapters — keep all annotated model classes
-keep class * extends com.google.gson.TypeAdapter
-keep @com.hivedb.hive.annotations.HiveType class * { *; }
-keepclassmembers @com.hivedb.hive.annotations.HiveType class * {
    @com.hivedb.hive.annotations.HiveField *;
}
-dontwarn com.hivedb.**

# ─── flutter_blue_plus / Bluetooth ───────────────────────────────────────────
-keep class com.boskokg.flutter_blue_plus.** { *; }
-dontwarn com.boskokg.flutter_blue_plus.**

# ─── permission_handler ───────────────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }

# ─── flutter_local_notifications ─────────────────────────────────────────────
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# ─── image_picker ─────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.imagepicker.** { *; }

# ─── printing / pdf ───────────────────────────────────────────────────────────
-keep class com.example.printing.** { *; }
-dontwarn org.apache.fop.**

# ─── General ──────────────────────────────────────────────────────────────────
# Keep line numbers for crash reports
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep enums accessible
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
