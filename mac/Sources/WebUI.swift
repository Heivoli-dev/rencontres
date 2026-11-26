import SwiftUI
import WebKit
import Combine

// MARK: - Données envoyées à l'interface (shared/app/app.html)
private struct WebMe: Encodable { let pseudo: String, game: String, message: String, recipe: [Int] }
private struct WebEncounter: Encodable { let id: String, pseudo: String, game: String, message: String, recipe: [Int], date: String, count: Int }
private struct WebState: Encodable {
    let me: WebMe, settings: Settings, encounters: [WebEncounter]
    let status: String, searching: Bool, nearby: Int, log: [String]
}

/// Évite que la vue web garde le pont en mémoire pour toujours.
private final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ t: WKScriptMessageHandler) { target = t }
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) { target?.userContentController(c, didReceive: m) }
}

/// Relie l'interface commune (HTML) au Bluetooth et à la sauvegarde.
final class WebBridge: NSObject, WKScriptMessageHandler {
    private let state: AppState
    private let ble: BLEManager
    private var web: WKWebView?
    private var ready = false
    private var bag = Set<AnyCancellable>()
    private let iso = ISO8601DateFormatter()

    init(state: AppState, ble: BLEManager) {
        self.state = state
        self.ble = ble
        super.init()
        state.objectWillChange.map { _ in () }
            .merge(with: ble.objectWillChange.map { _ in () })
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] in self?.push() }
            .store(in: &bag)
    }

    func webView() -> WKWebView {
        if let w = web { return w }
        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(WeakHandler(self), name: "native")
        let w = WKWebView(frame: .zero, configuration: cfg)
        configure(w)
        if let url = Bundle.main.url(forResource: "app", withExtension: "html") {
            w.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        web = w
        return w
    }

    /// Une nouvelle rencontre : on ouvre l'écran « Nouveau visiteur ».
    func announce(_ e: Encounter) {
        guard ready, let json = encode(webEncounter(e)) else { return }
        web?.evaluateJavaScript("App.encounter(\(json))")
    }

    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "ready":
            ready = true
            push()
        case "saveProfile":
            guard let m = body["me"] as? [String: Any] else { return }
            var p = state.me
            if let s = m["pseudo"] as? String { p.pseudo = String(decoding: Profile.utf8Prefix(s, max: Profile.maxPseudo), as: UTF8.self) }
            if let s = m["game"] as? String { p.game = String(decoding: Profile.utf8Prefix(s, max: Profile.maxGame), as: UTF8.self) }
            if let s = m["message"] as? String { p.message = String(decoding: Profile.utf8Prefix(s, max: Profile.maxMessage), as: UTF8.self) }
            if let r = m["recipe"] as? [NSNumber] { p.recipe = r.prefix(Catalog.recipeLength).map { UInt8(clamping: $0.intValue) } }
            state.me = p
            ble.profileDidChange()
        case "saveSettings":
            guard let s = body["settings"] as? [String: Any] else { return }
            var st = state.settings
            if let v = s["cooldown"] as? NSNumber { st.cooldown = v.doubleValue }
            if let v = s["notifications"] as? Bool { st.notifications = v }
            if let v = s["sound"] as? Bool { st.sound = v }
            state.settings = st
        case "clearHistory":
            state.clearHistory()
        default:
            break
        }
    }

    private func webEncounter(_ e: Encounter) -> WebEncounter {
        WebEncounter(id: e.profile.deviceID.uuidString, pseudo: e.profile.pseudo, game: e.profile.game, message: e.profile.message,
                     recipe: e.profile.recipe.map { Int($0) }, date: iso.string(from: e.date), count: e.count)
    }

    private func push() {
        guard ready, let web = web else { return }
        let me = state.me
        let s = WebState(
            me: WebMe(pseudo: me.pseudo, game: me.game, message: me.message, recipe: me.recipe.map { Int($0) }),
            settings: state.settings,
            encounters: state.encounters.map(webEncounter),
            status: ble.status, searching: ble.status.hasPrefix("Recherche"), nearby: ble.nearbyCount, log: state.log)
        guard let json = encode(s) else { return }
        web.evaluateJavaScript("App.setState(\(json))")
    }

    private func encode<T: Encodable>(_ v: T) -> String? {
        guard let d = try? JSONEncoder().encode(v) else { return nil }
        return String(decoding: d, as: UTF8.self)
    }

    private func configure(_ w: WKWebView) {
        w.setValue(false, forKey: "drawsBackground")
    }
}

/// L'interface commune affichée dans la fenêtre de la barre des menus.
struct WebAppView: NSViewRepresentable {
    let bridge: WebBridge
    func makeNSView(context: Context) -> WKWebView { bridge.webView() }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
