import ActivityKit
import SwiftUI
import WidgetKit

private let appGroupIdentifier = "group.dev.minzhang.solarV6.shared"
private let payloadKey = "solar_companion_payload"
private let nextMatchDeepLinkURL = URL(string: "dev.minzhang.solarV6://companion/next-match")
private let recentResultDeepLinkURL = URL(string: "dev.minzhang.solarV6://companion/recent-result")

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
  let rankingSummary: String?
  let predictedScoreLine: String?
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
  let horizontalPadding: CGFloat
  let verticalPadding: CGFloat

  init(
    horizontalPadding: CGFloat = 18,
    verticalPadding: CGFloat = 20,
    @ViewBuilder content: () -> Content
  ) {
    self.horizontalPadding = horizontalPadding
    self.verticalPadding = verticalPadding
    self.content = content()
  }

  var body: some View {
    content
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(.horizontal, horizontalPadding)
      .padding(.vertical, verticalPadding)
      .solarWidgetBackground()
  }
}

private extension View {
  @ViewBuilder
  func solarWidgetBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(for: .widget) {
        solarWidgetGradient
      }
    } else {
      background(solarWidgetGradient)
    }
  }

  private var solarWidgetGradient: some View {
    LinearGradient(
      colors: [Color(red: 0.05, green: 0.07, blue: 0.13), Color(red: 0.10, green: 0.16, blue: 0.31)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}

private struct SolarQuickviewWidgetView: View {
  let entry: SolarCompanionEntry

  var body: some View {
    SolarWidgetShell(horizontalPadding: 18, verticalPadding: 22) {
      if let payload = entry.payload {
        VStack(alignment: .leading, spacing: 12) {
          headerLine(payload)
          if let upcoming = payload.upcoming {
            nextMatchBlock(upcoming, predictedScoreLine: payload.predictedScoreLine)
          } else if let result = payload.recentResults.first {
            latestResultBlock(result)
          } else {
            emptyBlock(title: payload.teamNumber, body: "No published match data yet.")
          }

          Spacer(minLength: 0)

          if let result = payload.recentResults.first {
            footerPill(label: "Last", value: "\(resultTitle(result)) \(resultScoreLine(result))")
          }

          if let rankingSummary = payload.rankingSummary,
             !rankingSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            footerPill(label: "Rank", value: rankingSummary)
          }

          HStack(spacing: 8) {
            footerPill(label: "Skills", value: payload.worldRankLabel ?? "--")
            footerPill(label: "Solarize", value: payload.solarizeRankLabel ?? "--")
          }
        }
      } else {
        emptyBlock(
          title: "Solar Quickview",
          body: "No companion payload yet. Open the app and use Settings > Developer tools > Test live activity + widgets (or enable test scrimmage)."
        )
      }
    }
  }

  @ViewBuilder
  private func headerLine(_ payload: SolarCompanionPayload) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(payload.teamNumber)
        .font(solarRounded(24, weight: .bold))
        .foregroundStyle(.white)
      if let name = payload.teamName, !name.isEmpty {
        Text(name)
          .font(solarRounded(12, weight: .semibold))
          .foregroundStyle(.white.opacity(0.74))
          .lineLimit(1)
      }
    }
  }

  @ViewBuilder
  private func nextMatchBlock(
    _ upcoming: SolarUpcomingPayload,
    predictedScoreLine: String?
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Next Match")
        .font(solarRounded(12, weight: .semibold))
        .foregroundStyle(.white.opacity(0.72))
      Text(upcoming.matchLabel ?? upcoming.matchName)
        .font(solarRounded(24, weight: .bold))
        .foregroundStyle(.white)
      Text(upcoming.eventName)
        .font(solarRounded(14, weight: .semibold))
        .foregroundStyle(.white.opacity(0.88))
        .lineLimit(2)
      Text(metaLine(for: upcoming))
        .font(solarRounded(11, weight: .semibold))
        .foregroundStyle(.white.opacity(0.68))
        .lineLimit(2)
      if let predictedScoreLine, !predictedScoreLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Text("Predicted: \(predictedScoreLine)")
          .font(solarRounded(11, weight: .semibold))
          .foregroundStyle(.white.opacity(0.84))
          .lineLimit(1)
      }
      Text(allianceLine(label: "Red", teams: upcoming.redAlliance))
        .font(solarRounded(11, weight: .semibold))
        .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.60))
        .lineLimit(2)
      Text(allianceLine(label: "Blue", teams: upcoming.blueAlliance))
        .font(solarRounded(11, weight: .semibold))
        .foregroundStyle(Color(red: 0.61, green: 0.74, blue: 1.0))
        .lineLimit(2)
    }
  }

  @ViewBuilder
  private func latestResultBlock(_ result: SolarRecentResultPayload) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Latest Result")
        .font(solarRounded(12, weight: .semibold))
        .foregroundStyle(.white.opacity(0.72))
      Text("\(resultTitle(result)) \(resultScoreLine(result))")
        .font(solarRounded(24, weight: .bold))
        .foregroundStyle(.white)
      Text(result.matchLabel ?? result.matchName)
        .font(solarRounded(14, weight: .semibold))
        .foregroundStyle(.white.opacity(0.88))
      Text(result.eventName)
        .font(solarRounded(12, weight: .semibold))
        .foregroundStyle(.white.opacity(0.68))
        .lineLimit(2)
    }
  }

  @ViewBuilder
  private func emptyBlock(title: String, body: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(solarRounded(22, weight: .bold))
        .foregroundStyle(.white)
      Text(body)
        .font(solarRounded(14, weight: .semibold))
        .foregroundStyle(.white.opacity(0.74))
        .lineLimit(3)
    }
  }

  @ViewBuilder
  private func footerPill(label: String, value: String) -> some View {
    HStack(spacing: 6) {
      Text(label.uppercased())
        .font(solarRounded(10, weight: .heavy))
        .foregroundStyle(.white.opacity(0.56))
      Text(value)
        .font(solarRounded(11, weight: .semibold))
        .foregroundStyle(.white)
        .lineLimit(1)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(Color.white.opacity(0.10), in: Capsule())
  }
}

private struct SolarNextMatchWidgetView: View {
  @Environment(\.widgetFamily) private var widgetFamily

  let entry: SolarCompanionEntry

  var body: some View {
    SolarWidgetShell(verticalPadding: widgetFamily == .systemSmall ? 20 : 18) {
      if let upcoming = entry.payload?.upcoming {
        if widgetFamily == .systemSmall {
          smallNextMatchLayout(upcoming)
        } else {
          mediumNextMatchLayout(upcoming)
        }
      } else {
        SolarQuickviewWidgetView(entry: entry)
      }
    }
  }

  @ViewBuilder
  private func smallNextMatchLayout(_ upcoming: SolarUpcomingPayload) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("Next")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white.opacity(0.72))

      Text(upcoming.matchLabel ?? upcoming.matchName)
        .font(.title3.weight(.bold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.72)

      Text(metaLine(for: upcoming))
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white.opacity(0.74))
        .lineLimit(1)
        .minimumScaleFactor(0.74)

      if let predicted = entry.payload?.predictedScoreLine,
         !predicted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Text("Pred \(predicted)")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.white.opacity(0.86))
          .lineLimit(1)
          .minimumScaleFactor(0.74)
      }

      Spacer(minLength: 4)

      Text(allianceLine(label: "Red", teams: upcoming.redAlliance))
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.60))
        .lineLimit(1)
        .minimumScaleFactor(0.66)
      Text(allianceLine(label: "Blue", teams: upcoming.blueAlliance))
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Color(red: 0.61, green: 0.74, blue: 1.0))
        .lineLimit(1)
        .minimumScaleFactor(0.66)
    }
  }

  @ViewBuilder
  private func mediumNextMatchLayout(_ upcoming: SolarUpcomingPayload) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Next Match")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.72))
      Text(upcoming.matchLabel ?? upcoming.matchName)
        .font(.title2.weight(.bold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
      Text(metaLine(for: upcoming))
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.white.opacity(0.74))
        .lineLimit(2)
      if let predicted = entry.payload?.predictedScoreLine,
         !predicted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Text("Predicted \(predicted)")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white.opacity(0.84))
          .lineLimit(1)
      }
      Spacer(minLength: 4)
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
}

private struct SolarLatestResultWidgetView: View {
  @Environment(\.widgetFamily) private var widgetFamily

  let entry: SolarCompanionEntry

  var body: some View {
    SolarWidgetShell(verticalPadding: 20) {
      if let result = entry.payload?.recentResults.first {
        if widgetFamily == .systemSmall {
          smallResultLayout(result)
        } else {
          mediumResultLayout(result)
        }
      } else {
        SolarQuickviewWidgetView(entry: entry)
      }
    }
  }

  @ViewBuilder
  private func smallResultLayout(_ result: SolarRecentResultPayload) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Latest")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white.opacity(0.72))

      Text(resultScoreLine(result))
        .font(.title2.weight(.heavy))
        .foregroundStyle(.white)
        .minimumScaleFactor(0.7)
        .lineLimit(1)

      Text(result.matchLabel ?? result.matchName)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.88))
        .lineLimit(1)
        .minimumScaleFactor(0.8)

      Text(result.eventName)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white.opacity(0.7))
        .lineLimit(2)
        .minimumScaleFactor(0.8)

      Spacer(minLength: 2)

      Text(allianceLine(label: "Red", teams: result.redAlliance))
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.60))
        .lineLimit(1)
        .minimumScaleFactor(0.68)
      Text(allianceLine(label: "Blue", teams: result.blueAlliance))
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Color(red: 0.61, green: 0.74, blue: 1.0))
        .lineLimit(1)
        .minimumScaleFactor(0.68)
    }
  }

  @ViewBuilder
  private func mediumResultLayout(_ result: SolarRecentResultPayload) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Latest Result")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.72))

      Text("\(resultTitle(result)) \(resultScoreLine(result))")
        .font(.title3.weight(.bold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.72)

      Text(result.matchLabel ?? result.matchName)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.white.opacity(0.86))
        .lineLimit(1)

      Text(result.eventName)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.68))
        .lineLimit(2)

      Spacer(minLength: 4)

      VStack(alignment: .leading, spacing: 5) {
        Text(allianceLine(label: "Red", teams: result.redAlliance))
          .font(.caption2.weight(.bold))
          .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.60))
          .lineLimit(1)
          .minimumScaleFactor(0.72)
        Text(allianceLine(label: "Blue", teams: result.blueAlliance))
          .font(.caption2.weight(.bold))
          .foregroundStyle(Color(red: 0.61, green: 0.74, blue: 1.0))
          .lineLimit(1)
          .minimumScaleFactor(0.72)
      }
    }
  }
}

struct SolarNextMatchWidget: Widget {
  let kind: String = "SolarNextMatchWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SolarCompanionProvider()) { entry in
      SolarNextMatchWidgetView(entry: entry)
        .widgetURL(nextMatchDeepLinkURL)
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
        .widgetURL(recentResultDeepLinkURL)
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

        VStack(alignment: .leading, spacing: 12) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
              Text(context.state.mode == "recent" ? "Latest Result" : context.state.matchLabel)
                .font(solarRounded(context.state.mode == "recent" ? 14 : 22, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
              Text(context.state.eventName)
                .font(solarRounded(14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(2)
            }
            Spacer()
            if context.state.mode == "recent" {
              Text(context.state.recentResultScore)
                .font(solarRounded(22, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
            } else if context.state.scheduledAt > 0 {
              Text(Date(timeIntervalSince1970: TimeInterval(context.state.scheduledAt) / 1000), style: .time)
                .font(solarRounded(18, weight: .bold))
                .foregroundStyle(.white)
            }
          }

          Text(
            [context.state.divisionName, context.state.fieldName]
              .filter { !$0.isEmpty }
              .joined(separator: " • ")
          )
          .font(solarRounded(12, weight: .semibold))
          .foregroundStyle(.white.opacity(0.65))

          HStack(spacing: 10) {
            Text(allianceLine(label: "Red", teams: context.state.redAlliance))
              .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.60))
            Spacer()
            Text(allianceLine(label: "Blue", teams: context.state.blueAlliance))
              .foregroundStyle(Color(red: 0.61, green: 0.74, blue: 1.0))
          }
          .font(solarRounded(12, weight: .semibold))

          if let countdownDate = countdownTargetDate(for: context.state.scheduledAt),
             countdownDate > Date() {
            HStack(spacing: 6) {
              Text("Starts in")
                .foregroundStyle(.white.opacity(0.64))
              Text(countdownDate, style: .timer)
                .foregroundStyle(.white)
                .monospacedDigit()
              Spacer(minLength: 0)
            }
            .font(solarRounded(12, weight: .semibold))
          }

          Divider().overlay(Color.white.opacity(0.12))

          HStack(spacing: 10) {
            compactMetric("Last", "\(context.state.recentResultTitle) \(context.state.recentResultScore)")
            compactMetric("Rank", context.state.rankingSummary)
            compactMetric("Skills", context.state.worldRankLabel)
            compactMetric("Solarize", context.state.solarizeRankLabel)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
      }
      .widgetURL(context.state.mode == "recent" ? recentResultDeepLinkURL : nextMatchDeepLinkURL)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text(context.attributes.teamNumber)
            .font(solarRounded(12, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 4) {
            Text(context.state.matchLabel)
              .font(solarRounded(18, weight: .bold))
              .lineLimit(1)
              .minimumScaleFactor(0.72)
            Text(context.state.eventName)
              .font(solarRounded(12, weight: .semibold))
              .lineLimit(1)
              .minimumScaleFactor(0.72)
          }
          .frame(maxWidth: .infinity)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(
            context.state.mode == "recent"
                ? context.state.recentResultScore
                : compactTimeLabel(for: context.state.scheduledAt)
          )
          .font(solarRounded(12, weight: .bold))
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.72)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 7) {
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
            .font(solarRounded(12, weight: .semibold))

            HStack {
              Text("\(context.state.recentResultTitle) \(context.state.recentResultScore)")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
              Spacer()
              Text(
                context.state.mode == "recent"
                    ? context.state.rankingSummary
                    : "Pred \(context.state.predictedScoreLine)"
              )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .font(solarRounded(12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.82))

            HStack {
              Text("Skills \(context.state.worldRankLabel)")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
              Spacer()
              Text("Solarize \(context.state.solarizeRankLabel)")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .font(solarRounded(12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.80))
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.top, 4)
          .padding(.bottom, 8)
        }
      } compactLeading: {
        Text(context.state.mode == "recent" ? shortResultLabel(context.state.recentResultTitle) : shortMatchLabel(context.state.matchLabel))
          .font(solarRounded(12, weight: .bold))
          .lineLimit(1)
          .minimumScaleFactor(0.75)
      } compactTrailing: {
        Text(
          context.state.mode == "recent"
              ? context.state.recentResultScore
              : compactTimeLabel(for: context.state.scheduledAt)
        )
        .font(solarRounded(11, weight: .bold))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.72)
      } minimal: {
        Text(context.state.mode == "recent" ? shortResultLabel(context.state.recentResultTitle) : shortMatchLabel(context.state.matchLabel))
          .font(solarRounded(11, weight: .bold))
          .lineLimit(1)
          .minimumScaleFactor(0.72)
      }
      .widgetURL(context.state.mode == "recent" ? recentResultDeepLinkURL : nextMatchDeepLinkURL)
    }
  }

  @ViewBuilder
  private func compactMetric(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label.uppercased())
        .font(solarRounded(10, weight: .heavy))
        .foregroundStyle(.white.opacity(0.56))
      Text(value)
        .font(solarRounded(11, weight: .semibold))
        .foregroundStyle(.white)
        .lineLimit(2)
        .minimumScaleFactor(0.78)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

@main
struct SolarCompanionWidgetBundle: WidgetBundle {
  var body: some Widget {
    SolarNextMatchWidget()
    SolarLatestResultWidget()
    if #available(iOSApplicationExtension 16.1, *) {
      SolarCompanionLiveActivity()
    }
  }
}

private func solarRounded(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
  .system(size: size, weight: weight, design: .rounded)
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

private func shortResultLabel(_ value: String) -> String {
  let lowered = value.lowercased()
  if lowered.contains("won") {
    return "W"
  }
  if lowered.contains("lost") {
    return "L"
  }
  if lowered.contains("tied") {
    return "T"
  }
  return "RES"
}

private func compactTimeLabel(for timestampMillis: Int64) -> String {
  guard timestampMillis > 0 else {
    return "Live"
  }

  let date = Date(timeIntervalSince1970: TimeInterval(timestampMillis) / 1000)
  return date.formatted(date: .omitted, time: .shortened)
}

private func countdownTargetDate(for timestampMillis: Int64) -> Date? {
  guard timestampMillis > 0 else {
    return nil
  }
  return Date(timeIntervalSince1970: TimeInterval(timestampMillis) / 1000)
}
