import SwiftUI
import UserNotifications
import UIKit

@main
struct RencontresApp: App {
    @StateObject private var state: AppState
    @StateObject private var ble: BLEManager
    private let alerts = Alerts()

    init() {
        let s = AppState()
        let b = BLEManager(state: s)
        _state = StateObject(wrappedValue: s)
        _ble = StateObject(wrappedValue: b)
        let alerts = self.alerts
        alerts.requestPermission()
        b.onEncounter = { e in alerts.announce(e, settings: s.settings) }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(ble)
        }
    }
}

/// Alerte de rencontre : notification + vibration.
final class Alerts: NSObject, UNUserNotificationCenterDelegate {
    func requestPermission() {
        let c = UNUserNotificationCenter.current()
        c.delegate = self
        c.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func announce(_ e: Encounter, settings: Settings) {
        DispatchQueue.main.async {
            if settings.sound { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        }
        guard settings.notifications else { return }
        let content = UNMutableNotificationContent()
        content.title = e.count > 1 ? "Tu recroises \(e.profile.pseudo) !" : "Nouvelle rencontre !"
        var lines = [e.profile.pseudo]
        if !e.profile.game.isEmpty { lines.append("joue à \(e.profile.game)") }
        content.body = lines.joined(separator: " · ") + (e.profile.message.isEmpty ? "" : "\n« \(e.profile.message) »")
        if settings.sound { content.sound = .default }
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: e.id.uuidString + "\(e.count)", content: content, trigger: nil))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
