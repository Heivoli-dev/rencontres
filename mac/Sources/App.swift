import SwiftUI
import UserNotifications
import AppKit

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
        MenuBarExtra {
            ContentView()
                .environmentObject(state)
                .environmentObject(ble)
        } label: {
            Image(systemName: ble.nearbyCount > 0 ? "sparkles" : "sparkle")
        }
        .menuBarExtraStyle(.window)
    }
}

/// Alerte de rencontre : notification + son (le Mac ne vibre pas).
/// Sur l'AYN Thor, c'est ici qu'on branchera plus tard le module des LED des joysticks.
final class Alerts: NSObject, UNUserNotificationCenterDelegate {
    func requestPermission() {
        let c = UNUserNotificationCenter.current()
        c.delegate = self
        c.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func announce(_ e: Encounter, settings: Settings) {
        if settings.sound { NSSound(named: "Glass")?.play() }
        guard settings.notifications else { return }
        let content = UNMutableNotificationContent()
        content.title = e.count > 1 ? "Tu recroises \(e.profile.pseudo) !" : "Nouvelle rencontre !"
        var lines = [e.profile.pseudo]
        if !e.profile.game.isEmpty { lines.append("joue à \(e.profile.game)") }
        content.body = lines.joined(separator: " · ") + (e.profile.message.isEmpty ? "" : "\n« \(e.profile.message) »")
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: e.id.uuidString + "\(e.count)", content: content, trigger: nil))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
