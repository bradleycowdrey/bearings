package com.bradcowdrey.bearings.widget

import android.content.Context
import androidx.glance.appwidget.updateAll
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.concurrent.TimeUnit

/**
 * Keeps the widget current: a refresh every 30 minutes (the sun and moon move even when you don't, so
 * no network is required; the elevation lookup simply waits for the next one when offline), and a
 * redraw whenever the app saves a new fix.
 */
object WidgetUpdates {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    fun schedule(context: Context) {
        val request = PeriodicWorkRequestBuilder<RefreshWorker>(30, TimeUnit.MINUTES).build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork("widget", ExistingPeriodicWorkPolicy.KEEP, request)
    }

    fun redraw(context: Context) {
        val app = context.applicationContext
        scope.launch { runCatching { BearingsWidget().updateAll(app) } }
    }

    class RefreshWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
        override suspend fun doWork(): Result {
            runCatching { WidgetData.refresh(applicationContext) }
            BearingsWidget().updateAll(applicationContext)
            return Result.success()
        }
    }
}
