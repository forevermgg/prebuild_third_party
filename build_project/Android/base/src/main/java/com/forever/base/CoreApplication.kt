package com.forever.base

import android.app.Application
import com.jakewharton.processphoenix.ProcessPhoenix
import jonathanfinerty.once.Once

open class CoreApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        if (ProcessPhoenix.isPhoenixProcess(this)) {
            return
        }
        Once.initialise(this)
    }

    override fun onLowMemory() {
        super.onLowMemory()
    }
}
