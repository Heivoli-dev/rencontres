import Foundation
import Combine

/// Réglages de l'appli.
struct Settings: Codable, Equatable {
    /// Délai avant de recompter la même personne (en secondes).
    var cooldown: TimeInterval = 2 * 3600
    var notifications = true
    var sound = true

    static let cooldownChoices: [(label: String, seconds: TimeInterval)] = [
        ("1 min (test)", 60), ("30 min", 1800), ("2 h", 7200), ("6 h", 21600), ("24 h", 86400),
    ]
}

/// L'état de l'appli : mon profil, mes réglages et l'historique des rencontres. Tout est sauvegardé sur le disque.
final class AppState: ObservableObject {
    @Published var me: Profile { didSet { save() } }
    @Published var settings: Settings { didSet { save() } }
    @Published private(set) var encounters: [Encounter] = []
    @Published var log: [String] = []

    private let folder: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        folder = base.appendingPathComponent("Rencontres", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        me = AppState.load(Profile.self, from: folder.appendingPathComponent("profil.json"))
            ?? Profile(deviceID: UUID(), recipe: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1], pseudo: AppState.defaultPseudo, game: "", message: "Salut !")
        settings = AppState.load(Settings.self, from: folder.appendingPathComponent("reglages.json")) ?? Settings()
        encounters = AppState.load([Encounter].self, from: folder.appendingPathComponent("rencontres.json")) ?? []
        save()
    }

    static var defaultPseudo: String {
        #if os(macOS)
        return NSUserName()
        #else
        return "Moi"
        #endif
    }

    /// Enregistre une rencontre. Renvoie la rencontre si elle compte (pas déjà vue pendant le délai), sinon nil.
    @discardableResult
    func record(_ p: Profile) -> Encounter? {
        guard p.deviceID != me.deviceID else { return nil }
        let now = Date()
        if let i = encounters.firstIndex(where: { $0.profile.deviceID == p.deviceID }) {
            var e = encounters[i]
            e.profile = p
            guard now.timeIntervalSince(e.date) >= settings.cooldown else {
                encounters[i] = e   // on met à jour son profil sans recompter
                save()
                addLog("Déjà croisé récemment : \(p.pseudo)")
                return nil
            }
            e.date = now
            e.count += 1
            encounters.remove(at: i)
            encounters.insert(e, at: 0)
            save()
            return e
        }
        let e = Encounter(profile: p, date: now, count: 1)
        encounters.insert(e, at: 0)
        save()
        return e
    }

    func clearHistory() {
        encounters = []
        save()
    }

    func addLog(_ s: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        let line = "\(f.string(from: Date()))  \(s)"
        DispatchQueue.main.async {
            self.log.insert(line, at: 0)
            if self.log.count > 60 { self.log.removeLast(self.log.count - 60) }
        }
        print(line)
    }

    private func save() {
        AppState.store(me, to: folder.appendingPathComponent("profil.json"))
        AppState.store(settings, to: folder.appendingPathComponent("reglages.json"))
        AppState.store(encounters, to: folder.appendingPathComponent("rencontres.json"))
    }

    private static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let d = try? Data(contentsOf: url) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(T.self, from: d)
    }

    private static func store<T: Encodable>(_ value: T, to url: URL) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted]
        if let d = try? enc.encode(value) { try? d.write(to: url, options: .atomic) }
    }
}
