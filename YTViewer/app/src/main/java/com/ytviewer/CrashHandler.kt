package com.ytviewer

import android.app.Application
import android.content.Intent
import android.os.Bundle
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            val intent = Intent(this, CrashActivity::class.java).apply {
                putExtra("error", throwable.stackTraceToString())
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            }
            startActivity(intent)
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }
}

class CrashActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val error = intent.getStringExtra("error") ?: "Unknown error"
        val scroll = ScrollView(this)
        val tv = TextView(this).apply {
            text = error
            textSize = 11f
            setPadding(24, 24, 24, 24)
            setTextColor(0xFFFF4444.toInt())
            setBackgroundColor(0xFF000000.toInt())
        }
        scroll.addView(tv)
        setContentView(scroll)
    }
}
