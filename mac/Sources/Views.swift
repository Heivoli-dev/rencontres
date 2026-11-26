import SwiftUI
import AppKit

private let green = Color(red: 0.18, green: 0.70, blue: 0.42)
private let ink = Color(red: 0.15, green: 0.19, blue: 0.23)
private let sub = Color(red: 0.34, green: 0.39, blue: 0.44)

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var ble: BLEManager
    @State private var tab = 3

    var body: some View {
        VStack(spacing: 10) {
            header
            Picker("", selection: $tab) {
                Text("Place").tag(3)
                Text("Rencontres").tag(0)
                Text("Profil").tag(1)
                Text("Réglages").tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Group {
                switch tab {
                case 3: PlazaView(me: state.me, others: state.encounters)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                case 0: EncountersList()
                case 1: ProfileEditor()
                default: SettingsPane()
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(14)
        .frame(width: 380, height: 600)
        .background(Color(red: 0.95, green: 0.97, blue: 0.98))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            CreatureView(recipe: state.me.recipe)
                .frame(width: 120, height: 120)
                .background(LinearGradient(colors: [Color(red: 0.66, green: 0.87, blue: 0.98), Color(red: 0.9, green: 0.96, blue: 1)], startPoint: .top, endPoint: .bottom))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            VStack(alignment: .leading, spacing: 6) {
                Text(state.me.pseudo.isEmpty ? "Pseudo" : state.me.pseudo)
                    .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(ink)
                if !state.me.game.isEmpty {
                    Text("Joue à \(state.me.game)").font(.system(size: 13, weight: .semibold)).foregroundColor(sub)
                }
                HStack(spacing: 6) {
                    Circle().fill(ble.status.hasPrefix("Recherche") ? green : .orange).frame(width: 8, height: 8)
                    Text(ble.status).font(.system(size: 12, weight: .semibold)).foregroundColor(sub).lineLimit(3)
                }
                Text("\(ble.nearbyCount) appareil(s) à proximité").font(.system(size: 12)).foregroundColor(sub)
            }
            Spacer(minLength: 0)
        }
    }
}

struct EncountersList: View {
    @EnvironmentObject var state: AppState
    @ObservedObject private var snaps = CreatureSnapshotter.shared

    var body: some View {
        if state.encounters.isEmpty {
            VStack(spacing: 8) {
                Text("Personne croisé pour l'instant").font(.system(size: 15, weight: .bold)).foregroundColor(ink)
                Text("Garde l'appli ouverte : dès qu'un appareil avec l'appli passe à côté, vous échangez vos profils.")
                    .font(.system(size: 13)).foregroundColor(sub).multilineTextAlignment(.center)
            }
            .padding(.top, 30)
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(state.encounters) { e in row(e) }
                }
            }
        }
    }

    private func row(_ e: Encounter) -> some View {
        HStack(spacing: 10) {
            Group {
                if let img = snaps.image(for: e.profile.recipe) {
                    Image(nsImage: img).interpolation(.none).resizable()
                } else {
                    Color(red: 0.89, green: 0.96, blue: 0.92)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(e.profile.pseudo).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(ink)
                if !e.profile.game.isEmpty { Text(e.profile.game).font(.system(size: 12, weight: .semibold)).foregroundColor(sub) }
                if !e.profile.message.isEmpty { Text("« \(e.profile.message) »").font(.system(size: 12)).foregroundColor(sub).lineLimit(1) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(e.date, style: .relative).font(.system(size: 11, weight: .semibold)).foregroundColor(sub)
                if e.count > 1 {
                    Text("×\(e.count)").font(.system(size: 11, weight: .heavy)).foregroundColor(.white)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(Color(red: 0.95, green: 0.46, blue: 0.18)))
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
    }
}

struct ProfileEditor: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var ble: BLEManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                field("Pseudo", text: $state.me.pseudo, max: Profile.maxPseudo)
                field("Jeu du moment", text: $state.me.game, max: Profile.maxGame)
                field("Message court", text: $state.me.message, max: Profile.maxMessage)
                Text("Ta créature").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(ink).padding(.top, 4)
                ForEach(0..<Catalog.fields.count, id: \.self) { i in
                    Picker(Catalog.fields[i].title, selection: recipeBinding(i)) {
                        ForEach(0..<Catalog.fields[i].options.count, id: \.self) { j in
                            Text(Catalog.fields[i].options[j]).tag(j)
                        }
                    }
                }
                Text("Taille du profil envoyé : \(state.me.encoded().count) octets")
                    .font(.system(size: 11)).foregroundColor(sub)
            }
            .padding(.trailing, 6)
        }
        .onChange(of: state.me) { _ in ble.profileDidChange() }
    }

    private func field(_ title: String, text: Binding<String>, max: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.system(size: 12, weight: .bold)).foregroundColor(sub)
                Spacer()
                Text("\(text.wrappedValue.utf8.count)/\(max)").font(.system(size: 11)).foregroundColor(sub)
            }
            TextField(title, text: Binding(
                get: { text.wrappedValue },
                set: { text.wrappedValue = String(decoding: Profile.utf8Prefix($0, max: max), as: UTF8.self) }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

    private func recipeBinding(_ i: Int) -> Binding<Int> {
        Binding(
            get: { i < state.me.recipe.count ? Int(state.me.recipe[i]) : 0 },
            set: { v in
                var r = state.me.recipe
                while r.count < Catalog.recipeLength { r.append(0) }
                r[i] = UInt8(v)
                state.me.recipe = r
            }
        )
    }
}

struct SettingsPane: View {
    @EnvironmentObject var state: AppState
    @State private var confirmClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Recompter la même personne après", selection: $state.settings.cooldown) {
                ForEach(0..<Settings.cooldownChoices.count, id: \.self) { i in
                    Text(Settings.cooldownChoices[i].label).tag(Settings.cooldownChoices[i].seconds)
                }
            }
            Toggle("Notification à chaque rencontre", isOn: $state.settings.notifications)
            Toggle("Son", isOn: $state.settings.sound)
            HStack {
                Button("Effacer l'historique") { confirmClear = true }
                Spacer()
                Button("Quitter") { NSApp.terminate(nil) }
            }
            .confirmationDialog("Effacer toutes les rencontres ? C'est définitif.", isPresented: $confirmClear) {
                Button("Effacer", role: .destructive) { state.clearHistory() }
            }
            Text("Journal Bluetooth").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(ink).padding(.top, 6)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(state.log.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(size: 11, design: .monospaced)).foregroundColor(sub).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        }
    }
}
