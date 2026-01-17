package com.forever.app

import android.app.Application
import android.content.Context
import com.forever.base.CoreApplication

class App : CoreApplication() {

    override fun onCreate() {
        super.onCreate()
        app = this
    }

    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
    }

    companion object {
        //noinspection StaticFieldLeak
        lateinit var app: Application
    }
}