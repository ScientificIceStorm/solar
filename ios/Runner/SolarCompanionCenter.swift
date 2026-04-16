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
    default:
      result(FlutterMethodNotImplemented)
    }
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

    Task {
      let existingActivities = Activity<SolarMatchActivityAttributes>.activities
      guard let upcoming = payload.upcoming else {
        for activity in existingActivities {
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
        worldRankLabel: payload.worldRankLabel ?? "--",
        solarizeRankLabel: payload.solarizeRankLabel ?? "--",
        recordLabel: payload.recordLabel ?? "--"
      )

      if let activity = existingActivities.first {
        await activity.update(using: state)
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
}
