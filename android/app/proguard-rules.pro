# Unity LevelPlay (docs.unity.com > LevelPlay > Flutter plug-in integration > ProGuard)
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}
-keep class com.google.android.gms.ads.** {public *;}
-keep class com.google.android.gms.appset.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.ironsource.adapters.** { *; }
-dontwarn com.ironsource.**
-keepclassmembers class com.ironsource.** { public *; }
-keep public class com.ironsource.**
-dontwarn com.iab.omid.**
-keep class com.iab.omid.** {*;}
-keepattributes JavascriptInterface
-keepclassmembers class * { @android.webkit.JavascriptInterface <methods>; }
-keep class androidx.localbroadcastmanager.content.LocalBroadcastManager { *;}
-keep class androidx.recyclerview.widget.RecyclerView { *;}
-keep class androidx.recyclerview.widget.RecyclerView$OnScrollListener { *;}
-keep class * extends android.app.Activity
