import Foundation
import MultipeerConnectivity

/// Thin transport for MULTIPLAYER. Host advertises, joiners browse and
/// invite themselves; topology is hub-and-spoke with the host relaying.
final class MultipeerSession: NSObject, ObservableObject {
    static let serviceType = "nonono-rage"

    let myPeerID: MCPeerID
    private(set) var mcSession: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    @Published private(set) var connectedPeers: [MCPeerID] = []

    /// Delivered on the main queue.
    var onMessage: ((LiveMessage, MCPeerID) -> Void)?
    var onPeersChanged: (() -> Void)?

    init(displayName: String) {
        let safeName = String(displayName.prefix(40))
        myPeerID = MCPeerID(displayName: safeName.isEmpty ? "PLAYER" : safeName)
        mcSession = MCSession(peer: myPeerID, securityIdentity: nil,
                              encryptionPreference: .required)
        super.init()
        mcSession.delegate = self
    }

    func startHosting() {
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil,
                                               serviceType: Self.serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    func startJoining() {
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        mcSession.disconnect()
    }

    func send(_ message: LiveMessage, to peers: [MCPeerID]? = nil) {
        let targets = peers ?? mcSession.connectedPeers
        guard !targets.isEmpty, let data = message.encoded() else { return }
        try? mcSession.send(data, toPeers: targets, with: .reliable)
    }
}

extension MultipeerSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID,
                 didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.connectedPeers = session.connectedPeers
            self.onPeersChanged?()
        }
    }

    func session(_ session: MCSession, didReceive data: Data,
                 fromPeer peerID: MCPeerID) {
        guard let message = LiveMessage.decode(data) else { return }
        DispatchQueue.main.async {
            self.onMessage?(message, peerID)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MultipeerSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, mcSession)
    }
}

extension MultipeerSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        browser.invitePeer(peerID, to: mcSession, withContext: nil, timeout: 15)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
