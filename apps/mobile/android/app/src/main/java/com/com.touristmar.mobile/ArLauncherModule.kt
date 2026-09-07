package com.touristmar.mobile

import android.content.Intent
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.unity3d.player.UnityPlayerGameActivity

class ArLauncherModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
    override fun getName() = "ArLauncher"

    @ReactMethod
    fun open() {
        val activity = reactApplicationContext.currentActivity ?: return
        val intent = Intent(activity, UnityPlayerGameActivity::class.java)
        activity.startActivity(intent)
    }
}
