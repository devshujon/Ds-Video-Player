-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }

-dontwarn kotlin.**
-keep class kotlin.Metadata { *; }

-keep class androidx.media3.** { *; }

-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }

-keep class io.flutter.plugins.localauth.** { *; }
-keep class androidx.biometric.** { *; }

-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }

-keep class com.android.vending.billing.** { *; }
-keep class com.android.billingclient.** { *; }

-keep class com.fluttercandies.photo_manager.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }

-keep class com.alexmercerind.** { *; }
-dontwarn com.google.android.play.core.**

-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
