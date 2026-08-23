-keep class com.stripe.android.pushProvisioning.** { *; }
-keep class com.stripe.android.** { *; }
-keep class com.reactnativestripesdk.** { *; }

-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.stripe.android.**
-dontwarn com.reactnativestripesdk.**

-keep class * extends java.util.ListResourceBundle {
    protected Object[][] getContents();
}

-keep public class com.google.android.gms.common.internal.safeparcel.SafeParcelable {
    public static final *** NULL;
}

-keepnames @com.google.android.gms.common.annotation.KeepName class *
-keepclassmembernames class * {
    @com.google.android.gms.common.annotation.KeepName *;
}

-keepnames class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
