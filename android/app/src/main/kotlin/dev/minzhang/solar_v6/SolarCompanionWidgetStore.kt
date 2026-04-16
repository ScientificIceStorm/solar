package dev.minzhang.solar_v6

import android.content.Context

data class SolarWidgetUpcoming(
    val id: Int,
    val eventName: String,
    val divisionName: String,
    val matchName: String,
    val matchLabel: String,
    val fieldName: String,
    val scheduledAt: Long?,
    val redAlliance: String,
    val blueAlliance: String,
)

data class SolarWidgetRecentResult(
    val id: Int,
    val eventName: String,
    val divisionName: String,
    val matchName: String,
    val matchLabel: String,
    val fieldName: String,
    val completedAt: Long?,
    val allianceColor: String,
    val allianceScore: Int,
    val opponentScore: Int,
    val redAlliance: String,
    val blueAlliance: String,
)

data class SolarWidgetSnapshot(
    val teamNumber: String,
    val teamName: String,
    val recordLabel: String,
    val worldRankLabel: String,
    val solarizeRankLabel: String,
    val updatedAt: Long?,
    val upcoming: SolarWidgetUpcoming?,
    val latestResult: SolarWidgetRecentResult?,
) {
    val hasContent: Boolean
        get() = upcoming != null || latestResult != null || teamNumber.isNotBlank()
}

object SolarCompanionWidgetStore {
    private const val prefsName = "solar_companion_widget"

    private const val keyTeamNumber = "teamNumber"
    private const val keyTeamName = "teamName"
    private const val keyRecordLabel = "recordLabel"
    private const val keyWorldRankLabel = "worldRankLabel"
    private const val keySolarizeRankLabel = "solarizeRankLabel"
    private const val keyUpdatedAt = "updatedAt"

    private const val keyUpcomingId = "upcoming.id"
    private const val keyUpcomingEventName = "upcoming.eventName"
    private const val keyUpcomingDivisionName = "upcoming.divisionName"
    private const val keyUpcomingMatchName = "upcoming.matchName"
    private const val keyUpcomingMatchLabel = "upcoming.matchLabel"
    private const val keyUpcomingFieldName = "upcoming.fieldName"
    private const val keyUpcomingScheduledAt = "upcoming.scheduledAt"
    private const val keyUpcomingRedAlliance = "upcoming.redAlliance"
    private const val keyUpcomingBlueAlliance = "upcoming.blueAlliance"

    private const val keyResultId = "result.id"
    private const val keyResultEventName = "result.eventName"
    private const val keyResultDivisionName = "result.divisionName"
    private const val keyResultMatchName = "result.matchName"
    private const val keyResultMatchLabel = "result.matchLabel"
    private const val keyResultFieldName = "result.fieldName"
    private const val keyResultCompletedAt = "result.completedAt"
    private const val keyResultAllianceColor = "result.allianceColor"
    private const val keyResultAllianceScore = "result.allianceScore"
    private const val keyResultOpponentScore = "result.opponentScore"
    private const val keyResultRedAlliance = "result.redAlliance"
    private const val keyResultBlueAlliance = "result.blueAlliance"

    fun save(context: Context, payload: Map<*, *>) {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        editor.clear()

        editor.putString(keyTeamNumber, payload.stringValue("teamNumber").orEmpty())
        editor.putString(keyTeamName, payload.stringValue("teamName").orEmpty())
        editor.putString(keyRecordLabel, payload.stringValue("recordLabel").orEmpty())
        editor.putString(keyWorldRankLabel, payload.stringValue("worldRankLabel").orEmpty())
        editor.putString(
            keySolarizeRankLabel,
            payload.stringValue("solarizeRankLabel").orEmpty(),
        )
        payload.longValue("updatedAt")?.let { editor.putLong(keyUpdatedAt, it) }

        payload.mapValue("upcoming")?.let { upcoming ->
            editor.putInt(keyUpcomingId, upcoming.intValue("id") ?: 0)
            editor.putString(keyUpcomingEventName, upcoming.stringValue("eventName").orEmpty())
            editor.putString(
                keyUpcomingDivisionName,
                upcoming.stringValue("divisionName").orEmpty(),
            )
            editor.putString(keyUpcomingMatchName, upcoming.stringValue("matchName").orEmpty())
            editor.putString(
                keyUpcomingMatchLabel,
                upcoming.stringValue("matchLabel").orEmpty(),
            )
            editor.putString(keyUpcomingFieldName, upcoming.stringValue("fieldName").orEmpty())
            upcoming.longValue("scheduledAt")?.let {
                editor.putLong(keyUpcomingScheduledAt, it)
            }
            editor.putString(
                keyUpcomingRedAlliance,
                upcoming.stringValue("redAlliance").orEmpty(),
            )
            editor.putString(
                keyUpcomingBlueAlliance,
                upcoming.stringValue("blueAlliance").orEmpty(),
            )
        }

        payload.listValue("recentResults")
            .firstNotNullOfOrNull { item -> item as? Map<*, *> }
            ?.let { result ->
                editor.putInt(keyResultId, result.intValue("id") ?: 0)
                editor.putString(keyResultEventName, result.stringValue("eventName").orEmpty())
                editor.putString(
                    keyResultDivisionName,
                    result.stringValue("divisionName").orEmpty(),
                )
                editor.putString(keyResultMatchName, result.stringValue("matchName").orEmpty())
                editor.putString(
                    keyResultMatchLabel,
                    result.stringValue("matchLabel").orEmpty(),
                )
                editor.putString(keyResultFieldName, result.stringValue("fieldName").orEmpty())
                result.longValue("completedAt")?.let {
                    editor.putLong(keyResultCompletedAt, it)
                }
                editor.putString(
                    keyResultAllianceColor,
                    result.stringValue("allianceColor").orEmpty(),
                )
                editor.putInt(keyResultAllianceScore, result.intValue("allianceScore") ?: 0)
                editor.putInt(keyResultOpponentScore, result.intValue("opponentScore") ?: 0)
                editor.putString(
                    keyResultRedAlliance,
                    result.stringValue("redAlliance").orEmpty(),
                )
                editor.putString(
                    keyResultBlueAlliance,
                    result.stringValue("blueAlliance").orEmpty(),
                )
            }

        editor.apply()
    }

    fun load(context: Context): SolarWidgetSnapshot {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val upcoming = if (prefs.contains(keyUpcomingId)) {
            SolarWidgetUpcoming(
                id = prefs.getInt(keyUpcomingId, 0),
                eventName = prefs.getString(keyUpcomingEventName, "").orEmpty(),
                divisionName = prefs.getString(keyUpcomingDivisionName, "").orEmpty(),
                matchName = prefs.getString(keyUpcomingMatchName, "").orEmpty(),
                matchLabel = prefs.getString(keyUpcomingMatchLabel, "").orEmpty(),
                fieldName = prefs.getString(keyUpcomingFieldName, "").orEmpty(),
                scheduledAt = if (prefs.contains(keyUpcomingScheduledAt)) {
                    prefs.getLong(keyUpcomingScheduledAt, 0L)
                } else {
                    null
                },
                redAlliance = prefs.getString(keyUpcomingRedAlliance, "").orEmpty(),
                blueAlliance = prefs.getString(keyUpcomingBlueAlliance, "").orEmpty(),
            )
        } else {
            null
        }

        val latestResult = if (prefs.contains(keyResultId)) {
            SolarWidgetRecentResult(
                id = prefs.getInt(keyResultId, 0),
                eventName = prefs.getString(keyResultEventName, "").orEmpty(),
                divisionName = prefs.getString(keyResultDivisionName, "").orEmpty(),
                matchName = prefs.getString(keyResultMatchName, "").orEmpty(),
                matchLabel = prefs.getString(keyResultMatchLabel, "").orEmpty(),
                fieldName = prefs.getString(keyResultFieldName, "").orEmpty(),
                completedAt = if (prefs.contains(keyResultCompletedAt)) {
                    prefs.getLong(keyResultCompletedAt, 0L)
                } else {
                    null
                },
                allianceColor = prefs.getString(keyResultAllianceColor, "").orEmpty(),
                allianceScore = prefs.getInt(keyResultAllianceScore, 0),
                opponentScore = prefs.getInt(keyResultOpponentScore, 0),
                redAlliance = prefs.getString(keyResultRedAlliance, "").orEmpty(),
                blueAlliance = prefs.getString(keyResultBlueAlliance, "").orEmpty(),
            )
        } else {
            null
        }

        return SolarWidgetSnapshot(
            teamNumber = prefs.getString(keyTeamNumber, "").orEmpty(),
            teamName = prefs.getString(keyTeamName, "").orEmpty(),
            recordLabel = prefs.getString(keyRecordLabel, "").orEmpty(),
            worldRankLabel = prefs.getString(keyWorldRankLabel, "").orEmpty(),
            solarizeRankLabel = prefs.getString(keySolarizeRankLabel, "").orEmpty(),
            updatedAt = if (prefs.contains(keyUpdatedAt)) prefs.getLong(keyUpdatedAt, 0L) else null,
            upcoming = upcoming,
            latestResult = latestResult,
        )
    }

    fun clear(context: Context) {
        context.getSharedPreferences(prefsName, Context.MODE_PRIVATE).edit().clear().apply()
    }
}

private fun Map<*, *>.stringValue(key: String): String? {
    return this[key] as? String
}

private fun Map<*, *>.intValue(key: String): Int? {
    val raw = this[key] ?: return null
    return when (raw) {
        is Int -> raw
        is Long -> raw.toInt()
        is Double -> raw.toInt()
        is Float -> raw.toInt()
        else -> null
    }
}

private fun Map<*, *>.longValue(key: String): Long? {
    val raw = this[key] ?: return null
    return when (raw) {
        is Long -> raw
        is Int -> raw.toLong()
        is Double -> raw.toLong()
        is Float -> raw.toLong()
        else -> null
    }
}

private fun Map<*, *>.mapValue(key: String): Map<*, *>? {
    return this[key] as? Map<*, *>
}

@Suppress("UNCHECKED_CAST")
private fun Map<*, *>.listValue(key: String): List<Any?> {
    return this[key] as? List<Any?> ?: emptyList()
}
