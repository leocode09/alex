package com.example.alex

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import java.util.TimeZone
import kotlin.math.abs
import kotlin.math.roundToInt

class TimeGuardReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val appContext = context.applicationContext ?: return
        val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (prefs.getBoolean(TAMPER_KEY, false)) {
            return
        }

        val action = intent?.action
        val nowWall = System.currentTimeMillis()
        val nowElapsed = SystemClock.elapsedRealtime()
        val tzNow = TimeZone.getDefault().getOffset(nowWall) / 60000

        if (Intent.ACTION_BOOT_COMPLETED == action) {
            recordBaseline(prefs, nowWall, nowElapsed, tzNow)
            return
        }

        val lastWall = prefs.getLong(WALL_KEY, -1L)
        val lastElapsed = prefs.getLong(ELAPSED_KEY, -1L)
        val lastTz = prefs.getInt(TZ_KEY, Int.MIN_VALUE)

        if (lastWall <= 0L || lastElapsed <= 0L) {
            recordBaseline(prefs, nowWall, nowElapsed, tzNow)
            return
        }

        val elapsedDelta = nowElapsed - lastElapsed
        if (elapsedDelta < 0) {
            recordBaseline(prefs, nowWall, nowElapsed, tzNow)
            return
        }

        var tamperReason: String? = null

        if (Intent.ACTION_TIMEZONE_CHANGED == action && lastTz != Int.MIN_VALUE && lastTz != tzNow) {
            val delta = tzNow - lastTz
            tamperReason = "Time zone changed by ${formatOffset(delta)}"
        }

        if (tamperReason == null) {
            val expectedWall = lastWall + elapsedDelta
            val drift = abs(nowWall - expectedWall)
            if (drift > DRIFT_THRESHOLD_MS) {
                tamperReason = "Clock drifted by ${formatDrift(drift)}"
            }
        }

        if (tamperReason == null && lastTz != Int.MIN_VALUE && lastTz != tzNow) {
            val delta = tzNow - lastTz
            tamperReason = "Time zone changed by ${formatOffset(delta)}"
        }

        if (tamperReason != null) {
            prefs.edit()
                .putBoolean(TAMPER_KEY, true)
                .putString(REASON_KEY, tamperReason)
                .putLong(DETECTED_KEY, nowWall)
                .apply()
            return
        }

        recordBaseline(prefs, nowWall, nowElapsed, tzNow)
    }

    private fun recordBaseline(prefs: android.content.SharedPreferences, wall: Long, elapsed: Long, tzOffsetMin: Int) {
        prefs.edit()
            .putLong(WALL_KEY, wall)
            .putLong(ELAPSED_KEY, elapsed)
            .putInt(TZ_KEY, tzOffsetMin)
            .apply()
    }

    private fun formatDrift(driftMs: Long): String {
        val totalSeconds = (driftMs / 1000.0).roundToInt()
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        return if (minutes > 0) {
            "${minutes}m ${seconds}s"
        } else {
            "${seconds}s"
        }
    }

    private fun formatOffset(minutes: Int): String {
        val sign = if (minutes >= 0) "+" else "-"
        val absMinutes = abs(minutes)
        val hours = absMinutes / 60
        val mins = absMinutes % 60
        return when {
            hours > 0 && mins > 0 -> "${sign}${hours}h ${mins}m"
            hours > 0 -> "${sign}${hours}h"
            else -> "${sign}${mins}m"
        }
    }

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val WALL_KEY = "flutter.time_guard_wall_ms"
        private const val ELAPSED_KEY = "flutter.time_guard_elapsed_ms"
        private const val TZ_KEY = "flutter.time_guard_tz_offset_min"
        private const val TAMPER_KEY = "flutter.time_guard_tampered"
        private const val REASON_KEY = "flutter.time_guard_reason"
        private const val DETECTED_KEY = "flutter.time_guard_detected_at_ms"
        private const val DRIFT_THRESHOLD_MS = 2 * 60 * 1000L
    }
}
