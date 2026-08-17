# ML Kit 文本识别：仅使用中文脚本。
# 其余脚本（梵文/日/韩）由 flutter 插件引用但未随包引入，忽略缺失以免 R8 报错。
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit 运行时用类名反射查找组件，禁止混淆/裁剪，否则 OCR 空指针
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.mlkit_vision_text_common.**
-dontwarn com.google.android.gms.internal.mlkit_vision_common.**
