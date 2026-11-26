import SwiftUI

private let green = Color(red: 0.18, green: 0.70, blue: 0.42)
private let greenDark = Color(red: 0.12, green: 0.54, blue: 0.31)
private let orange = Color(red: 0.95, green: 0.46, blue: 0.18)
private let ink = Color(red: 0.15, green: 0.19, blue: 0.23)
private let sub = Color(red: 0.34, green: 0.39, blue: 0.44)
private let ground = Color(red: 0.93, green: 0.95, blue: 0.97)

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color.white).shadow(color: Color(red: 0.83, green: 0.87, blue: 0.89), radius: 0, x: 0, y: 3))
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            PlaceView().tabItem { Label("Place", systemImage: "house.fill") }
            VisitorsView().tabItem { Label("Visiteurs", systemImage: "person.2.fill") }
            ProfileView().tabItem { Label("Profil", systemImage: "person.crop.circle") }
            SettingsView().tabItem { Label("Réglages", systemImage: "slider.horizontal.3") }
        }
        .tint(green)
    }
}

// MARK: - La place
struct PlaceView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var ble: BLEManager

    private var today: Int { state.encounters.filter { Calendar.current.isDateInToday($0.date) }.count }
    private var total: Int { state.encounters.reduce(0) { $0 + $1.count } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("Rencontres").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(ink)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(ble.status.hasPrefix("Recherche") ? green : orange).frame(width: 8, height: 8)
                        Text(ble.status.hasPrefix("Recherche") ? "Recherche active" : "Bluetooth ?")
                            .font(.system(size: 13, weight: .heavy)).foregroundColor(greenDark)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(Color(red: 0.89, green: 0.96, blue: 0.92)))
                }
                PlazaView(me: state.me, others: state.encounters)
                    .frame(height: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                if !ble.status.hasPrefix("Recherche") {
                    Text(ble.status).font(.system(size: 13, weight: .semibold)).foregroundColor(orange)
                }
                HStack(spacing: 10) {
                    stat("\(today)", "aujourd'hui", orange)
                    stat("\(total)", "au total", Color(red: 0.17, green: 0.56, blue: 0.84))
                    stat("\(state.encounters.count)", "personnes", greenDark)
                }
                if let last = state.encounters.first {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dernière rencontre").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(sub)
                        EncounterRow(e: last)
                    }
                }
            }
            .padding(16)
        }
        .background(ground.ignoresSafeArea())
    }

    private func stat(_ n: String, _ label: String, _ color: Color) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 2) {
                Text(n).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(color)
                Text(label).font(.system(size: 13, weight: .bold)).foregroundColor(sub)
            }
        }
    }
}

// MARK: - Visiteurs
struct EncounterRow: View {
    let e: Encounter
    @ObservedObject private var snaps = CreatureSnapshotter.shared

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let img = snaps.image(for: e.profile.recipe) {
                    Image(uiImage: img).interpolation(.none).resizable()
                } else {
                    Color(red: 0.89, green: 0.96, blue: 0.92)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text(e.profile.pseudo).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(ink)
                if !e.profile.game.isEmpty { Text(e.profile.game).font(.system(size: 14, weight: .semibold)).foregroundColor(sub).lineLimit(1) }
                if !e.profile.message.isEmpty { Text("« \(e.profile.message) »").font(.system(size: 13)).foregroundColor(sub).lineLimit(1) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(e.date, style: .relative).font(.system(size: 12, weight: .bold)).foregroundColor(sub)
                if e.count > 1 {
                    Text("×\(e.count)").font(.system(size: 12, weight: .heavy)).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(orange))
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white).shadow(color: Color(red: 0.83, green: 0.87, blue: 0.89), radius: 0, x: 0, y: 3))
    }
}

struct VisitorsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                if state.encounters.isEmpty {
                    VStack(spacing: 8) {
                        Text("Personne croisé pour l'instant").font(.system(size: 17, weight: .bold, design: .rounded)).foregroundColor(ink)
                        Text("Garde l'appli ouverte près d'un appareil qui a l'appli : vos profils s'échangent tout seuls.")
                            .font(.system(size: 14)).foregroundColor(sub).multilineTextAlignment(.center)
                    }
                    .padding(.top, 60).padding(.horizontal, 24)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(state.encounters) { EncounterRow(e: $0) }
                    }
                    .padding(16)
                }
            }
            .background(ground.ignoresSafeArea())
            .navigationTitle("Visiteurs")
        }
    }
}

// MARK: - Profil
struct ProfileView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var ble: BLEManager

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CreatureView(recipe: state.me.recipe, spin: true)
                        .frame(height: 220)
                        .listRowBackground(Color(red: 0.9, green: 0.96, blue: 1))
                }
                Section("Ce que les autres voient") {
                    field("Pseudo", text: $state.me.pseudo, max: Profile.maxPseudo)
                    field("Jeu du moment", text: $state.me.game, max: Profile.maxGame)
                    field("Message court", text: $state.me.message, max: Profile.maxMessage)
                }
                Section("Ta créature") {
                    ForEach(0..<6, id: \.self) { picker($0) }
                }
                Section("Accessoires") {
                    ForEach(6..<10, id: \.self) { picker($0) }
                }
                Section("Geste") {
                    picker(10)
                }
                Section {
                    Text("Profil envoyé : \(state.me.encoded().count) octets").font(.footnote).foregroundColor(sub)
                }
            }
            .navigationTitle("Mon profil")
            .onChange(of: state.me) { _ in ble.profileDidChange() }
        }
    }

    private func field(_ title: String, text: Binding<String>, max: Int) -> some View {
        HStack {
            TextField(title, text: Binding(
                get: { text.wrappedValue },
                set: { text.wrappedValue = String(decoding: Profile.utf8Prefix($0, max: max), as: UTF8.self) }
            ))
            Text("\(text.wrappedValue.utf8.count)/\(max)").font(.caption).foregroundColor(sub)
        }
    }

    private func picker(_ i: Int) -> some View {
        Picker(Catalog.fields[i].title, selection: Binding(
            get: { i < state.me.recipe.count ? Int(state.me.recipe[i]) : 0 },
            set: { v in
                var r = state.me.recipe
                while r.count < Catalog.recipeLength { r.append(0) }
                r[i] = UInt8(v)
                state.me.recipe = r
            }
        )) {
            ForEach(0..<Catalog.fields[i].options.count, id: \.self) { j in
                Text(Catalog.fields[i].options[j]).tag(j)
            }
        }
    }
}

// MARK: - Réglages
struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var ble: BLEManager
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Détection") {
                    Text(ble.status).font(.subheadline).foregroundColor(sub)
                    Picker("Recompter la même personne après", selection: $state.settings.cooldown) {
                        ForEach(0..<Settings.cooldownChoices.count, id: \.self) { i in
                            Text(Settings.cooldownChoices[i].label).tag(Settings.cooldownChoices[i].seconds)
                        }
                    }
                }
                Section("Alerte de rencontre") {
                    Toggle("Notification", isOn: $state.settings.notifications)
                    Toggle("Son et vibration", isOn: $state.settings.sound)
                }
                Section {
                    Button("Effacer l'historique", role: .destructive) { confirmClear = true }
                }
                Section("Journal Bluetooth") {
                    ForEach(Array(state.log.prefix(30).enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(size: 11, design: .monospaced)).foregroundColor(sub)
                    }
                }
            }
            .navigationTitle("Réglages")
            .confirmationDialog("Effacer toutes les rencontres ? C'est définitif.", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Effacer", role: .destructive) { state.clearHistory() }
            }
        }
    }
}
