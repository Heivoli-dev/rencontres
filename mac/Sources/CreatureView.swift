import SwiftUI
import WebKit

/// Affiche la créature 3D (shared/creature/creature.html, le même rendu que sur iPhone et Android).
struct CreatureView: NSViewRepresentable {
    var recipe: [UInt8]
    var spin = false

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let web = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        web.setValue(false, forKey: "drawsBackground")
        web.navigationDelegate = context.coordinator
        context.coordinator.web = web
        if let url = Bundle.main.url(forResource: "creature", withExtension: "html") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }

    func updateNSView(_ web: WKWebView, context: Context) {
        context.coordinator.push(recipe: recipe, spin: spin)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var web: WKWebView?
        private var loaded = false
        private var pending: (recipe: [UInt8], spin: Bool)?

        func push(recipe: [UInt8], spin: Bool) {
            pending = (recipe, spin)
            guard loaded else { return }
            let list = recipe.map(String.init).joined(separator: ",")
            web?.evaluateJavaScript("setCreature([\(list)], {spin: \(spin), yaw: -0.4})")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loaded = true
            if let p = pending { push(recipe: p.recipe, spin: p.spin) }
        }
    }
}

/// Fabrique de petites vignettes de créatures (pour la liste des rencontres), avec une seule vue web cachée.
final class CreatureSnapshotter: NSObject, ObservableObject, WKNavigationDelegate {
    static let shared = CreatureSnapshotter()
    @Published private(set) var images: [String: NSImage] = [:]
    private let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 64, height: 64))
    private var loaded = false
    private var queue: [[UInt8]] = []
    private var running = false

    override init() {
        super.init()
        web.navigationDelegate = self
        if let url = Bundle.main.url(forResource: "creature", withExtension: "html") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    static func key(_ recipe: [UInt8]) -> String { recipe.map(String.init).joined(separator: "-") }

    func image(for recipe: [UInt8]) -> NSImage? {
        let k = CreatureSnapshotter.key(recipe)
        if let img = images[k] { return img }
        if !queue.contains(recipe) { queue.append(recipe) }
        DispatchQueue.main.async { self.next() }
        return nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
        next()
    }

    private func next() {
        guard loaded, !running, let recipe = queue.first else { return }
        running = true
        let list = recipe.map(String.init).joined(separator: ",")
        web.evaluateJavaScript("snap([\(list)], 64)") { [weak self] result, _ in
            guard let self = self else { return }
            self.queue.removeFirst()
            self.running = false
            if let s = result as? String, let comma = s.firstIndex(of: ","),
               let data = Data(base64Encoded: String(s[s.index(after: comma)...])), let img = NSImage(data: data) {
                self.images[CreatureSnapshotter.key(recipe)] = img
            }
            self.next()
        }
    }
}
