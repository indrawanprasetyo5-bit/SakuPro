-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep Firebase/MLKit ComponentRegistrars and their no-arg constructors for reflection
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    public <init>();
    *;
}

# Keep MLKit Text Recognition, Vision Common, ODML Image, and bundled native pipeline classes
-keep class com.google.mlkit.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_bundled_common.** { *; }
-keep class com.google.android.libraries.vision.visionkit.** { *; }
-keep class com.google.android.odml.image.** { *; }
-keep class id.sakupro.saku_pro.SakuNotificationListenerService { *; }
-keep class id.sakupro.saku_pro.SakuQuickAddTileService { *; }
-keep class id.sakupro.saku_pro.SakuHomeWidgetProvider { *; }
-keep class id.sakupro.saku_pro.SakuReminderReceiver { *; }
