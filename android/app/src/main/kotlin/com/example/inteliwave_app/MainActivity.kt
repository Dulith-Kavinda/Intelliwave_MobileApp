package com.example.inteliwave_app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Ensure the window is properly sized
        window?.setBackgroundDrawableResource(android.R.color.white)
    }
}
