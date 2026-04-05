import ActivityKit
import SwiftUI
import WidgetKit

private let appGroupIdentifier = "group.dev.minzhang.solarV6.shared"
private let payloadKey = "solar_companion_payload"

private struct SolarUpcomingPayload: Codable {
  let id: Int
  let eventName: String
  let divisionName: String
  let matchName: String
  let fieldName: String
  let scheduledAt: Int64?
  let redAlliance: String
  let blueAlliance: String
}

private struct SolarRecentResultPayload: Codable {
  let id: Int
  let eventName: String
  let divisionName: String
  let matchName: String
  let fieldName: String
  let completedAt: Int64?
  let allianceColor: String
  let allianceScore: Int
  let opponentScore: Int
  let redAlliance: String
  let blueAlliance: String
}

private struct SolarCompanionPayload: Codable {
  let teamNumber: String
  let upcoming: SolarUpcomingPayload?
  let recentResults: [SolarRecentResultPayload]
  let updatedAt: Int64?
}

private struct SolarCompanionEntry: TimelineEntry {
  let date: Date
  let payload: SolarCompanionPayload?
}

private struct SolarCompanionProvider: TimelineProvider {
  func placeholder(in context: Context) -> SolarCompanionEntry {
    SolarCompanionEntry(date: Date(), payload: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (SolarCompanionEntry) -> Void) {
    completion(SolarCompanionEntry(date: Date(), payload: loadPayload()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SolarCompanionEntry>) -> Void) {
    let entry = SolarCompanionEntry(date: Date(), payload: loadPayload())
    let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
    completion(Timeline(entries: [entry], policy: .after(refreshDate)))
  }

  private func loadPayload() -> SolarCompanionPayload? {
    guard
      let defaults = UserDefaults(suiteName: appGroupIdentifier),
      let data = defaults.data(forKey: payloadKey)
    else {
      return nil
    }

    return try? JSONDecoder().decode(SolarCompanionPayload.self, from: data)
  }
}

private struct SolarCompanionWidgetView: View {
  let entry: SolarCompanionEntry

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color(red: 0.05, green: 0.07, blue: 0.13), Color(red: 0.12, green: 0.18, blue: 0.32)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      VStack(alignment: .leading, spacing: 10) {
        if let upcoming = entry.payload?.upcoming {
          Text("Next Match")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.72))
          Text(upcoming.matchName)
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
          Text(upcoming.eventName)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white.opacity(0.88))
            .lineLimit(2)
          Text(metaLine(for: upcoming))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.68))
            .lineLimit(2)
          Spacer(minLength: 0)
          Text(allianceLine(label: "Red", teams: upcoming.redAlliance))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.60))
            .lineLimit(2)
          Text(allianceLine(label: "Blue", teams: upcoming.blueAlliance))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color(red: 0.61, green: 0.74, blue: 1.0))
            .lineLimit(2)
        } else if let result = entry.payload?.recentResults.first {
          Text("Latest Result")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.72))
          Text(resultTitle(result))
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
          Text(result.matchName)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white.opacity(0.88))
          Text(result.eventName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.68))
            .lineLimit(2)
        } else {
          Text("Solar")
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
          Text("Your next match widget will appear here once published.")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white.opacity(0.74))
            .lineLimit(3)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(16)
    }
  }

  private func metaLine(for upcoming: SolarUpcomingPayload) -> String {
    let time = upcoming.scheduledAt.map {
      Date(timeIntervalSince1970: TimeInterval($0) / 1000)
        .formatted(date: .omitted, time: .shortened)
    } ?? "Time pending"
    return [upcoming.divisionName, upcoming.fieldName, time]
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .joined(separator: " • ")
  }

  private func allianceLine(label: String, teams: String) -> String {
    guard !teams.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return label
    }
    return "\(label): \(teams)"
  }

  private func resultTitle(_ result: SolarRecentResultPayload) -> String {
    if result.allianceScore == result.opponentScore {
      return "Tied \(result.allianceScore)-\(result.opponentScore)"
    }
    if result.allianceScore > result.opponentScore {
      return "Won \(result.allianceScore)-\(result.opponentScore)"
    }
    return "Lost \(result.allianceScore)-\(result.opponentScore)"
  }
}

struct SolarCompanionWidget: Widget {
  let kind: String = "SolarCompanionWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SolarCompanionProvider()) { entry in
      SolarCompanionWidgetView(entry: entry)
    }
    .configurationDisplayName("Solar Quickview")
    .description("Shows your next published match and latest result.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@available(iOSApplicationExtension 16.1, *)
struct SolarCompanionLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: SolarMatchActivityAttributes.self) { context in
      ZStack {
        LinearGradient(
          colors: [Color.black, Color(red: 0.08, green: 0.11, blue: 0.22)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )

        VStack(alignment: .leading, spacing: 6) {
          Text(context.state.matchName)
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
          Text(context.state.eventName)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white.opacity(0.82))
            .lineLimit(2)
          Text(
            [context.state.divisionName, context.state.fieldName]
              .filter { !$0.isEmpty }
              .joined(separator: " • ")
          )
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
      }
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text(context.attributes.teamNumber)
            .font(.caption.weight(.bold))
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 4) {
            Text(context.state.matchName)
              .font(.headline.weight(.bold))
              .lineLimit(1)
            Text(context.state.eventName)
              .font(.caption.weight(.semibold))
              .lineLimit(1)
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(
            Date(timeIntervalSince1970: TimeInterval(context.state.scheduledAt) / 1000),
            style: .time
          )
          .font(.caption.weight(.bold))
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            Text(context.state.redAlliance)
              .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.60))
            Spacer()
            Text(context.state.blueAlliance)
              .foregroundStyle(Color(red: 0.61, green: 0.74, blue: 1.0))
          }
          .font(.caption2.weight(.semibold))
        }
      } compactLeading: {
        Text("Q")
          .font(.caption.weight(.bold))
      } compactTrailing: {
        Text(
          Date(timeIntervalSince1970: TimeInterval(context.state.scheduledAt) / 1000),
          style: .time
        )
        .font(.caption2.weight(.bold))
      } minimal: {
        Text("S")
          .font(.caption2.weight(.bold))
      }
    }
  }
}

@main
struct SolarCompanionWidgetBundle: WidgetBundle {
  var body: some Widget {
    SolarCompanionWidget()
    if #available(iOSApplicationExtension 16.1, *) {
      SolarCompanionLiveActivity()
    }
  }
}
