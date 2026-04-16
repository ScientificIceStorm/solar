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
  let matchLabel: String?
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
  let matchLabel: String?
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
  let teamName: String?
  let recordLabel: String?
  let worldRankLabel: String?
  let solarizeRankLabel: String?
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

private struct SolarWidgetShell<Content: View>: View {
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color(red: 0.05, green: 0.07, blue: 0.13), Color(red: 0.10, green: 0.16, blue: 0.31)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
    }
  }
}

private struct SolarQuickviewWidgetView: View {
  let entry: SolarCompanionEntry

  var body: some View {
    SolarWidgetShell {
      if let payload = entry.payload {
        VStack(alignment: .leading, spacing: 10) {
          headerLine(payload)
          if let upcoming = payload.upcoming {
            nextMatchBlock(upcoming)
          } else if let result = payload.recentResults.first {
            latestResultBlock(result)
          } else {
            emptyBlock(title: payload.teamNumber, body: "No published match data yet.")
          }

          Spacer(minLength: 0)

          if let result = payload.recentResults.first {
            footerPill(label: "Last", value: "\(resultTitle(result)) \(resultScoreLine(result))")
          }

          HStack(spacing: 8) {
            footerPill(label: "Skills", value: payload.worldRankLabel ?? "--")
            footerPill(label: "Solarize", value: payload.solarizeRankLabel ?? "--")
          }
        }
      } else {
        emptyBlock(title: "Solar Quickview", body: "Your team widget appears once live match data is available.")
      }
    }
  }

  @ViewBuilder
  private func headerLine(_ payload: SolarCompanionPayload) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(payload.teamNumber)
        .font(.headline.weight(.bold))
        .foregroundStyle(.white)
      if let name = payload.teamName, !name.isEmpty {
        Text(name)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white.opacity(0.74))
          .lineLimit(1)
      }
    }
  }

  @ViewBuilder
  private func nextMatchBlock(_ upcoming: SolarUpcomingPayload) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Next Match")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.72))
      Text(upcoming.matchLabel ?? upcoming.matchName)
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
      Text(allianceLine(label: "Red", teams: upcoming.redAlliance))
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.60))
        .lineLimit(2)
      Text(allianceLine(label: "Blue", teams: upcoming.blueAlliance))
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Color(red: 0.61, green: 0.74, blue: 1.0))
        .lineLimit(2)
    }
  }

  @ViewBuilder
  private func latestResultBlock(_ result: SolarRecentResultPayload) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Latest Result")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.72))
      Text("\(resultTitle(result)) \(resultScoreLine(result))")
        .font(.title3.weight(.bold))
        .foregroundStyle(.white)
      Text(result.matchLabel ?? result.matchName)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.white.opacity(0.88))
      Text(result.eventName)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.68))
        .lineLimit(2)
    }
  }

  @ViewBuilder
  private func emptyBlock(title: String, body: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.title3.weight(.bold))
        .foregroundStyle(.white)
      Text(body)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.white.opacity(0.74))
        .lineLimit(3)
    }
  }

  @ViewBuilder
  private func footerPill(label: String, value: String) -> some View {
    HStack(spacing: 6) {
      Text(label.uppercased())
        .font(.caption2.weight(.heavy))
        .foregroundStyle(.white.opacity(0.56))
      Text(value)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white)
        .lineLimit(1)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(Color.white.opacity(0.10), in: Capsule())
  }
}

private struct SolarNextMatchWidgetView: View {
  let entry: SolarCompanionEntry

  var body: some View {
    SolarWidgetShell {
      if let upcoming = entry.payload?.upcoming {
        VStack(alignment: .leading, spacing: 8) {
          Text("Next Match")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.72))
          Text(upcoming.matchLabel ?? upcoming.matchName)
            .font(.title2.weight(.bold))
            .foregroundStyle(.white)
          Text(metaLine(for: upcoming))
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white.opacity(0.74))
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
        }
      } else {
        SolarQuickviewWidgetView(entry: entry)
      }
    }
  }
}

private struct SolarLatestResultWidgetView: View {
  let entry: SolarCompanionEntry

  var body: some View {
    SolarWidgetShell {
      if let result = entry.payload?.recentResults.first {
        VStack(alignment: .leading, spacing: 8) {
          Text("Latest Result")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.72))
          Text("\(resultTitle(result)) \(resultScoreLine(result))")
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
          Text(result.matchLabel ?? result.matchName)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white.opacity(0.84))
          Text(result.eventName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.68))
            .lineLimit(2)
          Spacer(minLength: 0)
          HStack(spacing: 8) {
            footerMetric("Red", result.redAlliance)
            footerMetric("Blue", result.blueAlliance)
          }
        }
      } else {
        SolarQuickviewWidgetView(entry: entry)
      }
    }
  }

  @ViewBuilder
  private func footerMetric(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(label.uppercased())
        .font(.caption2.weight(.heavy))
        .foregroundStyle(.white.opacity(0.56))
      Text(value)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
  }
}

struct SolarCompanionWidget: Widget {
  let kind: String = "SolarCompanionWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SolarCompanionProvider()) { entry in
      SolarQuickviewWidgetView(entry: entry)
    }
    .configurationDisplayName("Solar Quickview")
    .description("Shows your next match, last result, and rank snapshot.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct SolarNextMatchWidget: Widget {
  let kind: String = "SolarNextMatchWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SolarCompanionProvider()) { entry in
      SolarNextMatchWidgetView(entry: entry)
    }
    .configurationDisplayName("Solar Next Match")
    .description("Focused view for your next published match.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct SolarLatestResultWidget: Widget {
  let kind: String = "SolarLatestResultWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SolarCompanionProvider()) { entry in
      SolarLatestResultWidgetView(entry: entry)
    }
    .configurationDisplayName("Solar Latest Result")
    .description("Shows your most recent published score.")
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

        VStack(alignment: .leading, spacing: 8) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
              Text(context.state.matchLabel)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
              Text(context.state.eventName)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(2)
            }
            Spacer()
            if context.state.scheduledAt > 0 {
              Text(Date(timeIntervalSince1970: TimeInterval(context.state.scheduledAt) / 1000), style: .time)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            }
          }

          Text(
            [context.state.divisionName, context.state.fieldName]
              .filter { !$0.isEmpty }
              .joined(separator: " • ")
          )
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white.opacity(0.65))

          HStack(spacing: 10) {
            Text(allianceLine(label: "Red", teams: context.state.redAlliance))
              .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.60))
            Spacer()
            Text(allianceLine(label: "Blue", teams: context.state.blueAlliance))
              .foregroundStyle(Color(red: 0.61, green: 0.74, blue: 1.0))
          }
          .font(.caption2.weight(.semibold))

          Divider().overlay(Color.white.opacity(0.12))

          HStack(spacing: 10) {
            compactMetric("Last", "\(context.state.recentResultTitle) \(context.state.recentResultScore)")
            compactMetric("Skills", context.state.worldRankLabel)
            compactMetric("Solarize", context.state.solarizeRankLabel)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
      }
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text(context.attributes.teamNumber)
            .font(.caption.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 4) {
            Text(context.state.matchLabel)
              .font(.headline.weight(.bold))
              .lineLimit(1)
              .minimumScaleFactor(0.72)
            Text(context.state.eventName)
              .font(.caption.weight(.semibold))
              .lineLimit(1)
              .minimumScaleFactor(0.72)
          }
          .frame(maxWidth: .infinity)
        }
        DynamicIslandExpandedRegion(.trailing) {
          if context.state.scheduledAt > 0 {
            Text(compactTimeLabel(for: context.state.scheduledAt))
              .font(.caption.weight(.bold))
              .monospacedDigit()
              .lineLimit(1)
              .minimumScaleFactor(0.72)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text(context.state.redAlliance)
                .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.60))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
              Spacer()
              Text(context.state.blueAlliance)
                .foregroundStyle(Color(red: 0.61, green: 0.74, blue: 1.0))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            }
            .font(.caption2.weight(.semibold))

            HStack {
              Text("\(context.state.recentResultTitle) \(context.state.recentResultScore)")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
              Spacer()
              Text("Skills \(context.state.worldRankLabel)")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
              Text("Solarize \(context.state.solarizeRankLabel)")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.80))
          }
        }
      } compactLeading: {
        Text(shortMatchLabel(context.state.matchLabel))
          .font(.caption.weight(.bold))
          .lineLimit(1)
          .minimumScaleFactor(0.75)
      } compactTrailing: {
        if context.state.scheduledAt > 0 {
          Text(compactTimeLabel(for: context.state.scheduledAt))
            .font(.caption2.weight(.bold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        } else {
          Text("Live")
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        }
      } minimal: {
        Text(shortMatchLabel(context.state.matchLabel))
          .font(.caption2.weight(.bold))
          .lineLimit(1)
          .minimumScaleFactor(0.72)
      }
    }
  }

  @ViewBuilder
  private func compactMetric(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label.uppercased())
        .font(.caption2.weight(.heavy))
        .foregroundStyle(.white.opacity(0.56))
      Text(value)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

@main
struct SolarCompanionWidgetBundle: WidgetBundle {
  var body: some Widget {
    SolarCompanionWidget()
    SolarNextMatchWidget()
    SolarLatestResultWidget()
    if #available(iOSApplicationExtension 16.1, *) {
      SolarCompanionLiveActivity()
    }
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
    return (result.matchLabel ?? result.matchName) + " tied"
  }
  if result.allianceScore > result.opponentScore {
    return (result.matchLabel ?? result.matchName) + " won"
  }
  return (result.matchLabel ?? result.matchName) + " lost"
}

private func resultScoreLine(_ result: SolarRecentResultPayload) -> String {
  "\(result.allianceScore)-\(result.opponentScore)"
}

private func shortMatchLabel(_ value: String) -> String {
  let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
  let uppercase = trimmed.uppercased()
  let digits = trimmed.filter { $0.isNumber }

  if uppercase.hasPrefix("QUALIFICATION") {
    return digits.isEmpty ? "Q" : "Q\(digits)"
  }
  if uppercase.hasPrefix("QUARTERFINAL") {
    return digits.isEmpty ? "QF" : "QF\(digits)"
  }
  if uppercase.hasPrefix("SEMIFINAL") {
    return digits.isEmpty ? "SF" : "SF\(digits)"
  }
  if uppercase.hasPrefix("FINAL") {
    return digits.isEmpty ? "F" : "F\(digits)"
  }

  let compact = trimmed.replacingOccurrences(of: " ", with: "")
  if compact.count <= 5 {
    return compact
  }
  return String(compact.prefix(5))
}

private func compactTimeLabel(for timestampMillis: Int64) -> String {
  guard timestampMillis > 0 else {
    return "Live"
  }

  let date = Date(timeIntervalSince1970: TimeInterval(timestampMillis) / 1000)
  return date.formatted(date: .omitted, time: .shortened)
}
