package dev.minzhang.solar_v6

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context

class SolarLatestResultWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        SolarCompanionWidgetRenderer.updateMode(
            context = context,
            appWidgetManager = appWidgetManager,
            appWidgetIds = appWidgetIds,
            mode = SolarWidgetMode.LATEST_RESULT,
        )
    }
}
