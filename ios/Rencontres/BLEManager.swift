import Foundation
import CoreBluetooth

/// Gère le Bluetooth : l'appareil s'annonce (périphérique) ET cherche les autres (central) en même temps.
/// Échange : le chercheur lit le PROFIL de l'autre, puis écrit le sien dans sa BOÎTE. Voir docs/PROTOCOLE.md.
final class BLEManager: NSObject, ObservableObject {
    @Published private(set) var status = "Démarrage…"
    @Published private(set) var nearbyCount = 0

    /// Appelé quand une nouvelle rencontre compte (pour l'alerte).
    var onEncounter: ((Encounter) -> Void)?

    private let state: AppState
    private var central: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var profileChar: CBMutableCharacteristic?
    private var inboxChar: CBMutableCharacteristic?
    private var serviceAdded = false

    /// Appareils en cours d'échange (on garde une référence forte, sinon CoreBluetooth les libère).
    private var busy: [UUID: CBPeripheral] = [:]
    /// Dernier échange réussi par appareil Bluetooth, pour ne pas se reconnecter en boucle.
    private var lastExchange: [UUID: Date] = [:]
    /// Données reçues en morceaux dans la BOÎTE, par appareil central.
    private var inboxBuffers: [UUID: Data] = [:]
    private var seen: [UUID: Date] = [:]

    init(state: AppState) {
        self.state = state
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
        peripheralManager = CBPeripheralManager(delegate: self, queue: .main)
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refreshNearby() }
    }

    /// À appeler quand mon profil change.
    func profileDidChange() {
        state.addLog("Profil mis à jour (\(state.me.encoded().count) octets)")
    }

    private func refreshNearby() {
        let now = Date()
        seen = seen.filter { now.timeIntervalSince($0.value) < 30 }
        nearbyCount = seen.count
    }

    private func updateStatus() {
        let c = central.state, p = peripheralManager.state
        if c == .unauthorized || p == .unauthorized {
            status = "Bluetooth refusé : autorise l'appli dans les Réglages (Confidentialité › Bluetooth)"
        } else if c == .poweredOff || p == .poweredOff {
            status = "Bluetooth éteint"
        } else if c == .poweredOn && p == .poweredOn {
            status = peripheralManager.isAdvertising ? "Recherche active" : "Recherche active (annonce en cours…)"
        } else {
            status = "Bluetooth indisponible"
        }
    }
}

// MARK: - Rôle « chercheur » (central)
extension BLEManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        updateStatus()
        guard central.state == .poweredOn else { return }
        central.scanForPeripherals(withServices: [BLEIDs.service], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        state.addLog("Recherche des appareils lancée")
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let id = peripheral.identifier
        seen[id] = Date()
        guard busy[id] == nil else { return }
        if let last = lastExchange[id], Date().timeIntervalSince(last) < min(state.settings.cooldown, 600) { return }
        busy[id] = peripheral
        peripheral.delegate = self
        state.addLog("Appareil trouvé (\(RSSI) dBm), connexion…")
        central.connect(peripheral, options: nil)
        // Si l'échange traîne, on abandonne au bout de 12 s.
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            guard let self = self, self.busy[id] != nil else { return }
            self.state.addLog("Échange trop long, abandon")
            self.finish(peripheral, success: false)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([BLEIDs.service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        state.addLog("Connexion ratée : \(error?.localizedDescription ?? "?")")
        busy[peripheral.identifier] = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        busy[peripheral.identifier] = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let s = peripheral.services?.first(where: { $0.uuid == BLEIDs.service }) else { return finish(peripheral, success: false) }
        peripheral.discoverCharacteristics([BLEIDs.profile, BLEIDs.inbox], for: s)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let c = service.characteristics?.first(where: { $0.uuid == BLEIDs.profile }) else { return finish(peripheral, success: false) }
        peripheral.readValue(for: c)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == BLEIDs.profile else { return }
        if let data = characteristic.value, let p = Profile.decode(data) {
            handleReceived(p, via: "lecture")
        } else {
            state.addLog("Profil illisible reçu")
        }
        // Puis on donne le nôtre.
        if let inbox = characteristic.service?.characteristics?.first(where: { $0.uuid == BLEIDs.inbox }) {
            peripheral.writeValue(state.me.encoded(), for: inbox, type: .withResponse)
        } else {
            finish(peripheral, success: true)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error { state.addLog("Envoi de mon profil raté : \(error.localizedDescription)") }
        finish(peripheral, success: error == nil)
    }

    private func finish(_ peripheral: CBPeripheral, success: Bool) {
        if success { lastExchange[peripheral.identifier] = Date() }
        central.cancelPeripheralConnection(peripheral)
        busy[peripheral.identifier] = nil
    }
}

// MARK: - Rôle « annonceur » (périphérique)
extension BLEManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        updateStatus()
        guard peripheral.state == .poweredOn, !serviceAdded else { return }
        let profile = CBMutableCharacteristic(type: BLEIDs.profile, properties: [.read], value: nil, permissions: [.readable])
        let inbox = CBMutableCharacteristic(type: BLEIDs.inbox, properties: [.write], value: nil, permissions: [.writeable])
        let service = CBMutableService(type: BLEIDs.service, primary: true)
        service.characteristics = [profile, inbox]
        profileChar = profile
        inboxChar = inbox
        serviceAdded = true
        peripheral.add(service)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error { return state.addLog("Service refusé : \(error.localizedDescription)") }
        peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [BLEIDs.service]])
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error { state.addLog("Annonce impossible : \(error.localizedDescription)") }
        else { state.addLog("Annonce lancée : visible par les autres appareils") }
        updateStatus()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard request.characteristic.uuid == BLEIDs.profile else { return peripheral.respond(to: request, withResult: .attributeNotFound) }
        let data = state.me.encoded()
        guard request.offset <= data.count else { return peripheral.respond(to: request, withResult: .invalidOffset) }
        request.value = data.subdata(in: request.offset..<data.count)
        peripheral.respond(to: request, withResult: .success)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard let first = requests.first else { return }
        for r in requests where r.characteristic.uuid == BLEIDs.inbox {
            let key = r.central.identifier
            var buf = r.offset == 0 ? Data() : (inboxBuffers[key] ?? Data())
            if buf.count < r.offset { buf.append(Data(count: r.offset - buf.count)) }
            buf.replaceSubrange(r.offset..<min(buf.count, r.offset + (r.value?.count ?? 0)), with: r.value ?? Data())
            inboxBuffers[key] = buf
        }
        peripheral.respond(to: first, withResult: .success)
        for key in Set(requests.map { $0.central.identifier }) {
            if let data = inboxBuffers[key], let p = Profile.decode(data) {
                inboxBuffers[key] = nil
                handleReceived(p, via: "boîte")
            }
        }
    }
}

// MARK: - Commun
private extension BLEManager {
    func handleReceived(_ p: Profile, via: String) {
        state.addLog("Profil reçu (\(via)) : \(p.pseudo)")
        if let e = state.record(p) { onEncounter?(e) }
    }
}
