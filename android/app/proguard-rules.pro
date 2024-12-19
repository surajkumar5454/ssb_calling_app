# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep your application classes
-keep class com.example.caller_app.** { *; }

# Keep notification related classes
-keep class android.app.Notification { *; }
-keep class android.app.NotificationManager { *; }
-keep class android.app.NotificationChannel { *; }
-keep class androidx.core.app.NotificationCompat { *; }

# Keep service and receiver
-keep class * extends android.content.BroadcastReceiver
-keep class * extends android.app.Service

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Window Extensions classes
-dontwarn androidx.window.extensions.**
-keep class androidx.window.extensions.** { *; }
-dontwarn androidx.window.sidecar.**
-keep class androidx.window.sidecar.** { *; }

# Keep Window Layout classes
-keep class androidx.window.layout.** { *; }

# Keep Window Core classes
-keep class androidx.window.core.** { *; }

# Keep Window Area classes
-keep class androidx.window.area.** { *; }

# Keep source file names and line numbers
-keepattributes SourceFile,LineNumberTable

# Keep Kotlin Metadata
-keepattributes *Annotation*
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeInvisibleAnnotations
-keepattributes RuntimeVisibleParameterAnnotations
-keepattributes RuntimeInvisibleParameterAnnotations

# Keep Kotlin Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# Keep Kotlin Serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Keep R8 rules
-keepattributes LineNumberTable,SourceFile
-renamesourcefileattribute SourceFile

# Keep database related classes
-keep class android.database.** { *; }
-keep class android.database.sqlite.** { *; }

# Keep phone state related classes
-keep class android.telephony.** { *; }

# Keep content provider related classes
-keep class android.content.ContentProvider { *; }
-keep class android.content.ContentValues { *; }
-keep class android.content.ContentResolver { *; }

# Keep permission related classes
-keep class android.permission.** { *; }

# Keep all model classes
-keep class com.example.caller_app.models.** { *; }

# Keep all database helper classes
-keep class com.example.caller_app.helpers.** { *; }

# Keep all service classes
-keep class com.example.caller_app.services.** { *; }

# Additional security rules
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify

# Keep important Android classes
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends android.app.backup.BackupAgentHelper
-keep public class * extends android.preference.Preference
