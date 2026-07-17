import Foundation
import Combine

/// State machine for RAGE-OFF LIVE: everyone plays the same seeded 60-second
/// round on their own phone. Spaceteam-style JOSH DEMANDS call out one player
/// by name on every screen, so the room does the enforcement.
final class LiveMatchController: ObservableObject {
    enum Stage: Equatable {
        case lobby, countdown, playing, podium
    }

    struct LiveDemand: Equatable {
        let id: UUID
        let kind: TargetKind
        let player: String
        let deadline: Date
    }

    @Published private(set) var stage: Stage = .lobby
    @Published private(set) var roster: [String] = []
    @Published private(set) var opponentScores: [String: Int] = [:]
    @Published private(set) var finals: [String: Int] = [:]
    @Published private(set) var activeDemand: LiveDemand?
    @Published private(set) var flash: String?
    @Published private(set) var countdown = 3
    @Published private(set) var isHost = false
    @Published private(set) var connectionStatus = "NOT CONNECTED"

    let engine = GameEngine(tuning: {
        var tuning = Tuning()
        tuning.roundDuration = 60
        return tuning
    }())

    private(set) var playerName = "PLAYER"
    private var session: MultipeerSession?
    private var peerNames: [String: String] = [:]  // peer displayName → roster name
    private var demandTimer: Timer?
    private var countdownTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    /// Kinds worth shouting across a room.
    static let demandKinds: [TargetKind] = [
        .shannon, .badDrivers, .dodTravel, .hoa, .thatSong, .redHair,
        .kids, .newDriver, .cardio,
    ]

    init() {
        engine.$score
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] score in
                guard let self, self.stage == .playing else { return }
                self.broadcast(.score(name: self.playerName, score: score))
            }
            .store(in: &cancellables)

        engine.$phase
            .removeDuplicates()
            .sink { [weak self] phase in
                guard let self, phase == .gameOver, self.stage == .playing else { return }
                self.finishRound()
            }
            .store(in: &cancellables)
    }

    // MARK: - Lobby

    func host(name: String) {
        playerName = cleaned(name)
        isHost = true
        roster = [playerName]
        connectionStatus = "HOSTING — WAITING FOR PLAYERS"
        openSession()
        session?.startHosting()
    }

    func join(name: String) {
        playerName = cleaned(name)
        isHost = false
        connectionStatus = "LOOKING FOR A HOST..."
        openSession()
        session?.startJoining()
    }

    func startMatch() {
        guard isHost, (2...4).contains(roster.count) else { return }
        let seed = UInt64.random(in: .min ... .max)
        broadcast(.start(seed: seed, delay: 3))
        applyStart(seed: seed, delay: 3)
    }

    func leave() {
        countdownTimer?.invalidate()
        demandTimer?.invalidate()
        engine.reset()
        stage = .lobby
        countdown = 3
        flash = nil
        activeDemand = nil
        opponentScores = [:]
        finals = [:]
        session?.stop()
        session = nil
    }

    // MARK: - In-round hooks (from GameView)

    func playerSmacked(kind: TargetKind, result: GameEngine.SmackResult) {
        if result.enteredRageMode {
            broadcast(.smashed(name: playerName))
        }
        guard let demand = activeDemand,
              demand.player == playerName,
              demand.kind == kind,
              Date() < demand.deadline else { return }
        engine.awardBonus(100)
        activeDemand = nil
        showFlash("+100! JOSH IS PLEASED. BRIEFLY.")
        broadcast(.demandResult(id: demand.id, player: playerName, fulfilled: true))
    }

    var ranked: [(name: String, score: Int)] {
        finals.map { (name: $0.key, score: $0.value) }.sorted { $0.score > $1.score }
    }

    // MARK: - Session plumbing

    private func openSession() {
        let session = MultipeerSession(displayName: playerName)
        session.onMessage = { [weak self] message, peer in
            self?.handle(message, fromPeer: peer.displayName)
        }
        session.onPeersChanged = { [weak self] in
            self?.peersChanged()
        }
        self.session = session
    }

    private func peersChanged() {
        guard let session else { return }
        let count = session.connectedPeers.count
        if isHost {
            // Drop names for peers that disconnected.
            let alive = Set(session.connectedPeers.map(\.displayName))
            peerNames = peerNames.filter { alive.contains($0.key) }
            rebuildRoster()
            connectionStatus = count == 0 ? "HOSTING — WAITING FOR PLAYERS"
                                          : "HOSTING — \(count + 1) PLAYERS"
        } else {
            connectionStatus = count > 0 ? "CONNECTED — WAITING FOR HOST"
                                         : "LOOKING FOR A HOST..."
            if count > 0 {
                broadcast(.hello(name: playerName))
            }
        }
    }

    private func handle(_ message: LiveMessage, fromPeer peer: String) {
        // Hub-and-spoke: the host relays everything except lobby bookkeeping.
        if isHost {
            switch message {
            case .hello, .roster, .start:
                break
            default:
                relay(message, excluding: peer)
            }
        }

        switch message {
        case .hello(let name):
            guard isHost else { return }
            peerNames[peer] = uniqueName(for: name)
            rebuildRoster()
        case .roster(let names):
            roster = names
            if !isHost { connectionStatus = "IN LOBBY — \(names.count) PLAYERS" }
        case .start(let seed, let delay):
            applyStart(seed: seed, delay: delay)
        case .score(let name, let score):
            guard name != playerName else { return }
            opponentScores[name] = score
        case .smashed(let name):
            guard name != playerName else { return }
            engine.spawnDecoys(2, at: Date().timeIntervalSinceReferenceDate)
            showFlash("\(name) IS SMASHED — INCOMING MAI TAIS!")
        case .demand(let id, let kindRaw, let player, let window):
            guard let kind = TargetKind(rawValue: kindRaw) else { return }
            applyDemand(LiveDemand(id: id, kind: kind, player: player,
                                   deadline: Date().addingTimeInterval(window)))
        case .demandResult(let id, let player, let fulfilled):
            applyDemandResult(id: id, player: player, fulfilled: fulfilled)
        case .finalScore(let name, let score):
            finals[name] = score
            checkForPodium()
        }
    }

    private func relay(_ message: LiveMessage, excluding peer: String) {
        guard let session else { return }
        let others = session.mcSession.connectedPeers.filter { $0.displayName != peer }
        session.send(message, to: others)
    }

    private func broadcast(_ message: LiveMessage) {
        session?.send(message)
    }

    private func rebuildRoster() {
        roster = [playerName] + peerNames.values.sorted()
        broadcast(.roster(names: roster))
    }

    private func uniqueName(for name: String) -> String {
        var candidate = cleaned(name)
        var suffix = 2
        while candidate == playerName || peerNames.values.contains(candidate) {
            candidate = "\(cleaned(name)) \(suffix)"
            suffix += 1
        }
        return candidate
    }

    private func cleaned(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.isEmpty ? "PLAYER" : String(trimmed.prefix(14))
    }

    // MARK: - Round lifecycle

    private func applyStart(seed: UInt64, delay: TimeInterval) {
        opponentScores = [:]
        finals = [:]
        activeDemand = nil
        flash = nil
        stage = .countdown
        countdown = Int(delay.rounded())
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.countdown -= 1
            if self.countdown <= 0 {
                timer.invalidate()
                self.beginRound(seed: seed)
            }
        }
    }

    private func beginRound(seed: UInt64) {
        stage = .playing
        engine.start(at: Date().timeIntervalSinceReferenceDate, seed: seed)
        if isHost {
            demandTimer?.invalidate()
            demandTimer = Timer.scheduledTimer(withTimeInterval: 12, repeats: true) { [weak self] _ in
                self?.issueDemand()
            }
        }
    }

    private func issueDemand() {
        guard isHost, stage == .playing, activeDemand == nil,
              let target = roster.randomElement(),
              let kind = Self.demandKinds.randomElement() else { return }
        let demand = LiveDemand(id: UUID(), kind: kind, player: target,
                                deadline: Date().addingTimeInterval(6))
        broadcast(.demand(id: demand.id, kindRaw: kind.rawValue,
                          player: target, window: 6))
        applyDemand(demand)
    }

    private func applyDemand(_ demand: LiveDemand) {
        activeDemand = demand
        // The named player's own device rules on failure.
        if demand.player == playerName {
            let id = demand.id
            DispatchQueue.main.asyncAfter(deadline: .now() + demand.deadline.timeIntervalSinceNow) { [weak self] in
                guard let self, self.activeDemand?.id == id else { return }
                self.engine.drainRage()
                self.activeDemand = nil
                self.showFlash("YOU BLEW IT. JOSH IS FURIOUS.")
                self.broadcast(.demandResult(id: id, player: self.playerName, fulfilled: false))
            }
        }
    }

    private func applyDemandResult(id: UUID, player: String, fulfilled: Bool) {
        if activeDemand?.id == id { activeDemand = nil }
        guard player != playerName else { return }
        if fulfilled {
            showFlash("\(player) DELIVERED. GODDAMNIT.")
        } else {
            engine.awardBonus(25)
            showFlash("\(player) BLEW IT. +25 FOR YOU.")
        }
    }

    private func finishRound() {
        demandTimer?.invalidate()
        activeDemand = nil
        finals[playerName] = engine.score
        broadcast(.finalScore(name: playerName, score: engine.score))
        checkForPodium()
        // Don't wait forever on a dropped peer.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            guard let self, self.stage == .playing else { return }
            self.stage = .podium
        }
    }

    private func checkForPodium() {
        guard stage == .playing || stage == .podium else { return }
        if finals.keys.count >= roster.count, finals[playerName] != nil {
            stage = .podium
        }
    }

    private func showFlash(_ text: String) {
        flash = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.flash == text { self?.flash = nil }
        }
    }
}
