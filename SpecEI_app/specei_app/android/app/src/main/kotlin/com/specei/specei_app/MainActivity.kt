package com.specei.specei_app

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

/**
 * MainActivity for SpecEI Flutter App
 * 
 * This implementation requests the highest available display refresh rate
 * (e.g., 90Hz, 120Hz) on supported Android devices for smoother animations.
 * 
 * How it works:
 * - On Android 6.0+ (API 23+): Queries available display modes
 * - Selects the mode with the highest refresh rate that matches current resolution
 * - Sets preferredDisplayModeId to request that refresh rate
 * - Falls back gracefully on unsupported devices
 * 
 * Note: Flutter rendering will automatically sync to the device vsync,
 * so no Flutter-side changes are needed.
 */
class MainActivity : FlutterActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)


        // Request highest refresh rate after activity is created
        requestHighRefreshRate()
    }
    
    /**
     * Request the highest available display refresh rate.
     * 
     * This is safe to call on all Android versions:
     * - API 23+: Full support for display mode selection
     * - API < 23: No-op, uses default refresh rate
     * 
     * The method selects a display mode with:
     * 1. Same physical resolution as current mode (to avoid resolution changes)
     * 2. Highest available refresh rate
     */
    private fun requestHighRefreshRate() {
        // Display.Mode API requires Android 6.0 (API 23)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return
        }
        
        try {
            val window = window ?: return
            val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay
            }
            
            if (display == null) return
            
            val currentMode = display.mode
            val supportedModes = display.supportedModes
            
            if (supportedModes.isNullOrEmpty()) return
            
            // Find the mode with highest refresh rate matching current resolution
            // We keep same resolution to avoid visual glitches
            var bestMode = currentMode
            var highestRefreshRate = currentMode.refreshRate
            
            for (mode in supportedModes) {
                // Match resolution to avoid display scaling issues
                if (mode.physicalWidth == currentMode.physicalWidth &&
                    mode.physicalHeight == currentMode.physicalHeight &&
                    mode.refreshRate > highestRefreshRate) {
                    bestMode = mode
                    highestRefreshRate = mode.refreshRate
                }
            }
            
            // Only update if we found a higher refresh rate
            if (bestMode.modeId != currentMode.modeId) {
                val params = window.attributes
                params.preferredDisplayModeId = bestMode.modeId
                window.attributes = params
            }
        } catch (e: Exception) {
            // Silently fail - device will use default refresh rate
            // This catches any edge cases on unusual devices
        }
    }
}
