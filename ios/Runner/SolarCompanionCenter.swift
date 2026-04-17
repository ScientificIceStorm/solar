import ActivityKit
import Flutter
import UIKit
import UserNotifications
import WidgetKit

final class SolarCompanionCenter: NSObject {
  static let shared = SolarCompanionCenter()

  private var channel: FlutterMethodChannel?
  private let center = UNUserNotificationCenter.current()
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private var pendingCompanionRoute: String?
  private var liveActivityUpdateTask: Task<Void, Never>?

  func configure(with messenger: FlutterBinaryMessenger) {
    guard channel == nil else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "solar/ios_companion",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
    self.channel = channel

    if let route = pendingCompanionRoute {
      pendingCompanionRoute = nil
      channel.invokeMethod("openCompanionRoute", arguments: ["route": route])
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "syncCompanion":
      guard
        let arguments = call.arguments as? [String: Any],
        let payload = payload(from: arguments)
      else {
        result(
          FlutterError(
            code: "invalid_payload",
            message: "The companion payload was missing required fields.",
            details: nil
          )
        )
        return
      }

      persist(payload: payload)
      requestAuthorizationIfNeeded { [weak self] authorized in
        self?.scheduleNotifications(for: payload, authorized: authorized)
        self?.updateBadgeCount(for: payload)
        self?.reloadWidgets()
        self?.updateLiveActivity(for: payload)
        result(nil)
      }
    case "clearCompanion":
      clearAll()
      result(nil)
    case "consumePendingCompanionRoute":
      let route = pendingCompanionRoute
      pendingCompanionRoute = nil
      result(route)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func handleIncomingCompanionURL(_ url: URL) {
    guard let route = companionRoute(from: url) else {
      return
    }

    pendingCompanionRoute = route
    channel?.invokeMethod("openCompanionRoute", arguments: ["route": route])
  }

  private func payload(from arguments: [String: Any]) -> SolarCompanionPayload? {
    guard JSONSerialization.isValidJSONObject(arguments) else {
      return nil
    }

    do {
      let data = try JSONSerialization.data(withJSONObject: arguments, options: [])
      return try decoder.decode(SolarCompanionPayload.self, from: data)
    } catch {
      return nil
    }
  }

  private func persist(payload: SolarCompanionPayload) {
    let defaults = SolarCompanionStore.sharedDefaults()
    if let data = try? encoder.encode(payload) {
      defaults.set(data, forKey: SolarCompanionStore.payloadKey)
    }
  }

  private func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
    center.getNotificationSettings { [weak self] settings in
      let status = settings.authorizationStatus
      if status == .authorized || status == .provisional {
        completion(true)
      } else if #available(iOS 14.0, *), status == .ephemeral {
        completion(true)
      } else if status == .notDetermined {
        self?.center.requestAuthorization(options: [.alert, .badge, .sound]) {
          granted,
          _
          in
          completion(granted)
        }
      } else {
        completion(false)
      }
    }
  }

  private func scheduleNotifications(
    for payload: SolarCompanionPayload,
    authorized: Bool
  ) {
    guard authorized else {
      return
    }

    center.removeAllPendingNotificationRequests()

    if let upcoming = payload.upcoming {
      scheduleUpcomingNotifications(for: upcoming)
    }

    scheduleResultNotifications(for: payload.recentResults)
  }

  private func scheduleUpcomingNotifications(for upcoming: SolarUpcomingPayload) {
    guard let scheduledAt = upcoming.scheduledAt else {
      return
    }

    let eventDate = Date(timeIntervalSince1970: TimeInterval(scheduledAt) / 1000)
    let offsets = [10, 5]
    for offset in offsets {
      let triggerDate = eventDate.addingTimeInterval(TimeInterval(-offset * 60))
      guard triggerDate > Date() else {
        continue
      }

      let content = UNMutableNotificationContent()
      content.title = "\(upcoming.matchLabel ?? upcoming.matchName) in \(offset)m"
      content.body =
        "\(upcoming.eventName) • \(upcoming.divisionName)\(upcoming.fieldName.isEmpty ? "" : " • \(upcoming.fieldName)")"
      content.sound = .default

      let components = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute, .second],
        from: triggerDate
      )
      let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
      let request = UNNotificationRequest(
        identifier: "solar.upcoming.\(upcoming.id).\(offset)",
        content: content,
        trigger: trigger
      )
      center.add(request)
    }
  }

  private func scheduleResultNotifications(for results: [SolarRecentResultPayload]) {
    let defaults = SolarCompanionStore.sharedDefaults()
    let announced = Set(defaults.stringArray(forKey: SolarCompanionStore.announcedResultsKey) ?? [])
    var updatedAnnounced = announced
    let now = Date()

    for result in results {
      let identifier = "solar.result.\(result.id)"
      guard !updatedAnnounced.contains(identifier) else {
        continue
      }

      if let completedAt = result.completedAt {
        let completedDate = Date(timeIntervalSince1970: TimeInterval(completedAt) / 1000)
        guard now.timeIntervalSince(completedDate) <= 60 * 45 else {
          continue
        }
      }

      let content = UNMutableNotificationContent()
      let didWin = result.allianceScore > result.opponentScore
      let didTie = result.allianceScore == result.opponentScore
      content.title = didTie
        ? "\(result.matchLabel ?? result.matchName) ended in a tie"
        : didWin
        ? "You won \(result.matchLabel ?? result.matchName)"
        : "You lost \(result.matchLabel ?? result.matchName)"
      content.body =
        "\(result.eventName) • \(result.allianceScore)-\(result.opponentScore)"
      content.sound = .default

      let request = UNNotificationRequest(
        identifier: identifier,
        content: content,
        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
      )
      center.add(request)
      updatedAnnounced.insert(identifier)
    }

    defaults.set(Array(updatedAnnounced), forKey: SolarCompanionStore.announcedResultsKey)
  }

  private func updateBadgeCount(for payload: SolarCompanionPayload) {
    let count = (payload.upcoming == nil ? 0 : 1) + payload.recentResults.count
    DispatchQueue.main.async {
      UIApplication.shared.applicationIconBadgeNumber = count
    }
  }

  private func reloadWidgets() {
    guard #available(iOS 14.0, *) else {
      return
    }
    WidgetCenter.shared.reloadAllTimelines()
  }

  private func updateLiveActivity(for payload: SolarCompanionPayload) {
    guard #available(iOS 16.1, *) else {
      return
    }

    liveActivityUpdateTask?.cancel()
    liveActivityUpdateTask = Task {
      let existingActivities = Activity<SolarMatchActivityAttributes>.activities
      let normalizedTeamNumber = payload.teamNumber
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .uppercased()

      let matchingActivities = existingActivities.filter { activity in
        activity.attributes.teamNumber
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .uppercased() == normalizedTeamNumber
      }

      let nonMatchingActivities = existingActivities.filter { activity in
        activity.attributes.teamNumber
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .uppercased() != normalizedTeamNumber
      }

      for activity in nonMatchingActivities {
        await activity.end(using: activity.contentState, dismissalPolicy: .immediate)
      }

      guard let upcoming = payload.upcoming else {
        for activity in matchingActivities {
          await activity.end(using: activity.contentState, dismissalPolicy: .immediate)
        }
        return
      }

      let state = SolarMatchActivityAttributes.ContentState(
        eventName: upcoming.eventName,
        matchName: upcoming.matchName,
        matchLabel: upcoming.matchLabel ?? upcoming.matchName,
        divisionName: upcoming.divisionName,
        fieldName: upcoming.fieldName,
        scheduledAt: upcoming.scheduledAt ?? 0,
        redAlliance: upcoming.redAlliance,
        blueAlliance: upcoming.blueAlliance,
        recentResultTitle: payload.recentResults.first.map(resultTitle) ?? "Awaiting result",
        recentResultScore: payload.recentResults.first.map(resultScoreLine) ?? "No recent score",
        predictedScoreLine: payload.predictedScoreLine ?? "--",
        worldRankLabel: payload.worldRankLabel ?? "--",
        solarizeRankLabel: payload.solarizeRankLabel ?? "--",
        recordLabel: payload.recordLabel ?? "--"
      )

      if let activity = matchingActivities.first {
        await activity.update(using: state)
        if matchingActivities.count > 1 {
          for duplicate in matchingActivities.dropFirst() {
            await duplicate.end(using: duplicate.contentState, dismissalPolicy: .immediate)
          }
        }
      } else {
        let attributes = SolarMatchActivityAttributes(teamNumber: payload.teamNumber)
        do {
          _ = try Activity<SolarMatchActivityAttributes>.request(
            attributes: attributes,
            contentState: state,
            pushType: nil
          )
        } catch {
          // Ignore ActivityKit start failures.
        }
      }
    }
  }

  func clearAll() {
    liveActivityUpdateTask?.cancel()
    liveActivityUpdateTask = nil
    center.removeAllPendingNotificationRequests()
    center.removeAllDeliveredNotifications()
    let defaults = SolarCompanionStore.sharedDefaults()
    defaults.removeObject(forKey: SolarCompanionStore.payloadKey)
    defaults.removeObject(forKey: SolarCompanionStore.announcedResultsKey)
    DispatchQueue.main.async {
      UIApplication.shared.applicationIconBadgeNumber = 0
    }
    reloadWidgets()

    guard #available(iOS 16.1, *) else {
      return
    }

    Task {
      for activity in Activity<SolarMatchActivityAttributes>.activities {
        await activity.end(using: activity.contentState, dismissalPolicy: .immediate)
      }
    }
  }

  private func resultTitle(_ result: SolarRecentResultPayload) -> String {
    if result.allianceScore == result.opponentScore {
      return "\(result.matchLabel ?? result.matchName) tied"
    }
    if result.allianceScore > result.opponentScore {
      return "\(result.matchLabel ?? result.matchName) won"
    }
    return "\(result.matchLabel ?? result.matchName) lost"
  }

  private func resultScoreLine(_ result: SolarRecentResultPayload) -> String {
    return "\(result.allianceScore)-\(result.opponentScore)"
  }

  private func companionRoute(from url: URL) -> String? {
    guard
      let scheme = url.scheme?.lowercased(),
      scheme == "dev.minzhang.solarv6"
    else {
      return nil
    }

    let host = url.host?.lowercased() ?? ""
    let path = url.path.lowercased()
    if host == "companion" || path.contains("companion") {
      if path.contains("recent") {
        return "recent_result"
      }
      return "next_match"
    }

    if path.contains("recent") {
      return "recent_result"
    }
    if path.contains("next") || path.contains("match") {
      return "next_match"
    }
    return nil
  }
}
