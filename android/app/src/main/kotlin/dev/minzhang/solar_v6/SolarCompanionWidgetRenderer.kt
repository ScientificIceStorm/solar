package dev.minzhang.solar_v6

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

enum class SolarWidgetMode {
    QUICKVIEW,
    NEXT_MATCH,
    LATEST_RESULT,
}

object SolarCompanionWidgetRenderer {
    fun updateAll(context: Context) {
        updateProvider(context, SolarQuickviewWidgetProvider::class.java, SolarWidgetMode.QUICKVIEW)
        updateProvider(context, SolarNextMatchWidgetProvider::class.java, SolarWidgetMode.NEXT_MATCH)
        updateProvider(
            context,
            SolarLatestResultWidgetProvider::class.java,
            SolarWidgetMode.LATEST_RESULT,
        )
    }

    fun updateMode(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        mode: SolarWidgetMode,
    ) {
        val snapshot = SolarCompanionWidgetStore.load(context)
        for (appWidgetId in appWidgetIds) {
            val remoteViews = RemoteViews(context.packageName, R.layout.solar_companion_widget)
            bindSnapshot(context, remoteViews, snapshot, mode)
            appWidgetManager.updateAppWidget(appWidgetId, remoteViews)
        }
    }

    private fun updateProvider(
        context: Context,
        providerClass: Class<*>,
        mode: SolarWidgetMode,
    ) {
        val manager = AppWidgetManager.getInstance(context)
        val component = ComponentName(context, providerClass)
        val ids = manager.getAppWidgetIds(component)
        if (ids.isEmpty()) {
            return
        }
        updateMode(context, manager, ids, mode)
    }

    private fun bindSnapshot(
        context: Context,
        views: RemoteViews,
        snapshot: SolarWidgetSnapshot,
        mode: SolarWidgetMode,
    ) {
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            val pendingIntent = PendingIntent.getActivity(
                context,
                mode.ordinal,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
        }

        when (mode) {
            SolarWidgetMode.QUICKVIEW -> bindQuickview(views, snapshot)
            SolarWidgetMode.NEXT_MATCH -> bindNextMatch(views, snapshot)
            SolarWidgetMode.LATEST_RESULT -> bindLatestResult(views, snapshot)
        }
    }

    private fun bindQuickview(views: RemoteViews, snapshot: SolarWidgetSnapshot) {
        val upcoming = snapshot.upcoming
        if (upcoming != null) {
            bindMatchCard(
                views = views,
                kicker = "SOLAR QUICKVIEW",
                title = upcoming.matchLabel.ifBlank { upcoming.matchName },
                subtitle = upcoming.eventName,
                meta = buildList {
                    add(formatTime(upcoming.scheduledAt))
                    if (upcoming.divisionName.isNotBlank()) {
                        add(upcoming.divisionName)
                    }
                    if (upcoming.fieldName.isNotBlank()) {
                        add(upcoming.fieldName)
                    }
                }.joinToString("  |  "),
                redAlliance = upcoming.redAlliance,
                blueAlliance = upcoming.blueAlliance,
                footerLeft = "Skills ${snapshot.worldRankLabel.ifBlank { "--" }}",
                footerRight = "Solarize ${snapshot.solarizeRankLabel.ifBlank { "--" }}",
            )
            return
        }

        val result = snapshot.latestResult
        if (result != null) {
            bindMatchCard(
                views = views,
                kicker = "LATEST RESULT",
                title = resultTitle(result),
                subtitle = result.matchLabel.ifBlank { result.matchName },
                meta = result.eventName,
                redAlliance = result.redAlliance,
                blueAlliance = result.blueAlliance,
                footerLeft = snapshot.recordLabel.ifBlank { snapshot.teamNumber.ifBlank { "Solar" } },
                footerRight = "${result.allianceScore}-${result.opponentScore}",
            )
            return
        }

        bindEmpty(
            views = views,
            kicker = "SOLAR QUICKVIEW",
            title = snapshot.teamNumber.ifBlank { "Solar" },
            message = "Open the app once to sync your next match and latest result.",
        )
    }

    private fun bindNextMatch(views: RemoteViews, snapshot: SolarWidgetSnapshot) {
        val upcoming = snapshot.upcoming
        if (upcoming == null) {
            bindEmpty(
                views = views,
                kicker = "NEXT MATCH",
                title = snapshot.teamNumber.ifBlank { "No match yet" },
                message = "Your next published qualification match will appear here.",
            )
            return
        }

        bindMatchCard(
            views = views,
            kicker = "NEXT MATCH",
            title = upcoming.matchLabel.ifBlank { upcoming.matchName },
            subtitle = upcoming.eventName,
            meta = buildList {
                add(formatTime(upcoming.scheduledAt))
                if (upcoming.divisionName.isNotBlank()) {
                    add(upcoming.divisionName)
                }
                if (upcoming.fieldName.isNotBlank()) {
                    add(upcoming.fieldName)
                }
            }.joinToString("  |  "),
            redAlliance = upcoming.redAlliance,
            blueAlliance = upcoming.blueAlliance,
            footerLeft = snapshot.teamNumber,
            footerRight = snapshot.recordLabel.ifBlank { "Record --" },
        )
    }

    private fun bindLatestResult(views: RemoteViews, snapshot: SolarWidgetSnapshot) {
        val result = snapshot.latestResult
        if (result == null) {
            bindEmpty(
                views = views,
                kicker = "LATEST RESULT",
                title = snapshot.teamNumber.ifBlank { "No result yet" },
                message = "Your most recent published score will appear here.",
            )
            return
        }

        bindMatchCard(
            views = views,
            kicker = "LATEST RESULT",
            title = resultTitle(result),
            subtitle = result.matchLabel.ifBlank { result.matchName },
            meta = buildList {
                if (result.eventName.isNotBlank()) {
                    add(result.eventName)
                }
                val completed = formatTime(result.completedAt)
                if (completed.isNotBlank()) {
                    add(completed)
                }
            }.joinToString("  |  "),
            redAlliance = result.redAlliance,
            blueAlliance = result.blueAlliance,
            footerLeft = "Skills ${snapshot.worldRankLabel.ifBlank { "--" }}",
            footerRight = "Solarize ${snapshot.solarizeRankLabel.ifBlank { "--" }}",
        )
    }

    private fun bindMatchCard(
        views: RemoteViews,
        kicker: String,
        title: String,
        subtitle: String,
        meta: String,
        redAlliance: String,
        blueAlliance: String,
        footerLeft: String,
        footerRight: String,
    ) {
        views.setTextViewText(R.id.widget_kicker, kicker)
        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_subtitle, subtitle)
        views.setTextViewText(R.id.widget_meta, meta)
        views.setTextViewText(R.id.widget_red, if (redAlliance.isBlank()) "" else "Red  $redAlliance")
        views.setTextViewText(R.id.widget_blue, if (blueAlliance.isBlank()) "" else "Blue  $blueAlliance")
        views.setTextViewText(R.id.widget_footer_left, footerLeft)
        views.setTextViewText(R.id.widget_footer_right, footerRight)

        views.setViewVisibility(R.id.widget_subtitle, visibilityFor(subtitle))
        views.setViewVisibility(R.id.widget_meta, visibilityFor(meta))
        views.setViewVisibility(R.id.widget_red, visibilityFor(redAlliance))
        views.setViewVisibility(R.id.widget_blue, visibilityFor(blueAlliance))
        views.setViewVisibility(R.id.widget_footer_row, visibilityFor("$footerLeft$footerRight"))
    }

    private fun bindEmpty(
        views: RemoteViews,
        kicker: String,
        title: String,
        message: String,
    ) {
        views.setTextViewText(R.id.widget_kicker, kicker)
        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_subtitle, message)
        views.setTextViewText(R.id.widget_meta, "")
        views.setTextViewText(R.id.widget_red, "")
        views.setTextViewText(R.id.widget_blue, "")
        views.setTextViewText(R.id.widget_footer_left, "")
        views.setTextViewText(R.id.widget_footer_right, "")

        views.setViewVisibility(R.id.widget_subtitle, visibilityFor(message))
        views.setViewVisibility(R.id.widget_meta, View.GONE)
        views.setViewVisibility(R.id.widget_red, View.GONE)
        views.setViewVisibility(R.id.widget_blue, View.GONE)
        views.setViewVisibility(R.id.widget_footer_row, View.GONE)
    }

    private fun visibilityFor(value: String): Int {
        return if (value.isBlank()) View.GONE else View.VISIBLE
    }

    private fun formatTime(value: Long?): String {
        if (value == null || value <= 0L) {
            return ""
        }
        return SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(value))
    }

    private fun resultTitle(result: SolarWidgetRecentResult): String {
        return when {
            result.allianceScore == result.opponentScore ->
                "${result.matchLabel.ifBlank { result.matchName }} tied ${result.allianceScore}-${result.opponentScore}"

            result.allianceScore > result.opponentScore ->
                "${result.matchLabel.ifBlank { result.matchName }} won ${result.allianceScore}-${result.opponentScore}"

            else ->
                "${result.matchLabel.ifBlank { result.matchName }} lost ${result.allianceScore}-${result.opponentScore}"
        }
    }
}
