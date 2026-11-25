import Foundation
import CoreBluetooth

/// Identifiants Bluetooth de l'appli (identiques sur Mac, iPhone et Android). Voir docs/PROTOCOLE.md.
enum BLEIDs {
    static let service = CBUUID(string: "29AA63FB-0552-4A4B-8CD2-4042B4BA69E5")
    static let profile = CBUUID(string: "E9868EB7-D7E8-4D4F-9368-BE0BBFBE99F6")
    static let inbox = CBUUID(string: "65148279-FF49-4B8B-BF3B-411B1F0EC7B9")
}

/// Les choix possibles pour chaque octet de la recette (même ordre que docs/PROTOCOLE.md).
enum Catalog {
    static let fields: [(title: String, options: [String])] = [
        ("Couleur du corps", ["Nuit", "Ardoise", "Prune", "Forêt", "Ciel", "Pêche"]),
        ("Couleur des branchies", ["Lavande", "Bleu", "Rose", "Menthe", "Soleil"]),
        ("Branchies", ["Pétales", "Longues", "Courtes", "Aucune"]),
        ("Queue", ["Nageoire", "Pompon", "Fine", "Aucune"]),
        ("Yeux", ["Brillants", "Points", "Endormis"]),
        ("Marque", ["Losange", "Aucune", "Taches", "Rayures"]),
        ("Chapeau", ["Aucun", "Casquette", "Bonnet", "Haut-de-forme", "Couronne", "Sorcier", "Casque audio", "Nœud", "Fleur"]),
        ("Lunettes", ["Aucunes", "Rondes", "Soleil", "Roses"]),
        ("Cou", ["Rien", "Écharpe", "Nœud pap", "Clochette", "Bandana"]),
        ("Fierté", ["Aucun", "Arc-en-ciel", "Trans", "Bi", "Lesbien", "Pan", "Non-binaire", "Asexuel"]),
        ("Geste", ["Calme", "Salut", "Joie", "Danse", "Curieux", "Timide"]),
    ]
    static let recipeLength = 11
}

/// Profil échangé entre deux appareils.
struct Profile: Codable, Equatable {
    static let formatVersion: UInt8 = 1
    static let maxPseudo = 32, maxGame = 48, maxMessage = 120

    var deviceID: UUID
    var recipe: [UInt8]
    var pseudo: String
    var game: String
    var message: String

    /// Encode au format binaire v1.
    func encoded() -> Data {
        var d = Data([Profile.formatVersion])
        withUnsafeBytes(of: deviceID.uuid) { d.append(contentsOf: $0) }
        var r = Array(recipe.prefix(Catalog.recipeLength))
        while r.count < Catalog.recipeLength { r.append(0) }
        d.append(contentsOf: r)
        for (text, max) in [(pseudo, Profile.maxPseudo), (game, Profile.maxGame), (message, Profile.maxMessage)] {
            let bytes = Profile.utf8Prefix(text, max: max)
            d.append(UInt8(bytes.count))
            d.append(contentsOf: bytes)
        }
        return d
    }

    /// Décode un profil reçu. Renvoie nil si les données sont invalides.
    static func decode(_ data: Data) -> Profile? {
        let b = [UInt8](data)
        guard b.count >= 28, b[0] >= 1 else { return nil }
        var u: uuid_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        withUnsafeMutableBytes(of: &u) { raw in for i in 0..<16 { raw[i] = b[1 + i] } }
        let recipe = Array(b[17..<28])
        var i = 28
        func readString() -> String? {
            guard i < b.count else { return nil }
            let len = Int(b[i]); i += 1
            guard i + len <= b.count else { return nil }
            let s = String(decoding: b[i..<(i + len)], as: UTF8.self); i += len
            return s
        }
        guard let pseudo = readString(), let game = readString(), let message = readString() else { return nil }
        return Profile(deviceID: UUID(uuid: u), recipe: recipe, pseudo: pseudo, game: game, message: message)
    }

    /// Coupe un texte à `max` octets UTF-8 sans couper un caractère.
    static func utf8Prefix(_ s: String, max: Int) -> [UInt8] {
        var out: [UInt8] = []
        for ch in s {
            let bytes = Array(String(ch).utf8)
            if out.count + bytes.count > max { break }
            out += bytes
        }
        return out
    }
}

/// Une rencontre enregistrée dans l'historique.
struct Encounter: Codable, Identifiable, Equatable {
    var id = UUID()
    var profile: Profile
    var date: Date
    var count: Int
}
