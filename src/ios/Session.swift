import Foundation

class Session {
    // Cordova Stuff
    var plugin: PhoneRTCPlugin
    var callbackId: String
    // State Stuff
    var config: SessionConfig
    var sessionKey: String
    // WebRTC Stuff.
    var peerConnectionFactory: RTCPeerConnectionFactory
    var peerConnectionConstraints: RTCMediaConstraints
    var peerConnection: RTCPeerConnection!
    var stream: RTCMediaStream?
    var track: RTCAudioTrack?
    
    init(plugin: PhoneRTCPlugin,
         peerConnectionFactory: RTCPeerConnectionFactory,
         config: SessionConfig,
         callbackId: String,
         sessionKey: String) {
        self.plugin = plugin
        self.callbackId = callbackId
        self.config = config
        self.sessionKey = sessionKey
        self.peerConnectionFactory = peerConnectionFactory
        // Define the peer connection constraints.
        let mandatory = [
            RTCPair(key: "OfferToReceiveAudio", value: "true"),
            RTCPair(key: "OfferToReceiveVideo", value: "false")
        ]
        let optional = [
            RTCPair(key: "internalSctpDataChannels", value: "true"),
            RTCPair(key: "DtlsSrtpKeyAgreement", value: "true")
        ]
        self.peerConnectionConstraints = RTCMediaConstraints(mandatoryConstraints: mandatory,
                                                             optionalConstraints: optional)
    }
    
    func call() {
        // Define ICE servers.
        let url = NSURL(string: "stun:stun.l.google.com:19302")
        let user = ""
        let pw = ""
        let iceServers = [RTCICEServer(URI: url, username: user, password: pw)]
        // Initialize the peer connection.
        self.peerConnection = peerConnectionFactory.peerConnectionWithICEServers(iceServers,
                constraints: self.peerConnectionConstraints,
                delegate: PCObserver(session: self))
        // Add the audio track.
        self.stream = peerConnectionFactory.mediaStreamWithLabel("ARDAMS")
        self.track = peerConnectionFactory.audioTrackWithID("ARDAMSa0")
        self.stream!.addAudioTrack(self.track!)
        self.peerConnection.addStream(self.stream)
        // If we are acting as the caller then generate an offer.
        if self.config.isInitiator {
            self.peerConnection.createOfferWithDelegate(SessionDescriptionDelegate(session: self),
                                                        constraints: self.peerConnectionConstraints)
        }
    }

    func toggleMute(mute: Bool) {
        for item in self.stream!.audioTracks {
            let track = item as RTCAudioTrack
            track.setEnabled(!mute)
        }
    }
    
    func receiveMessage(message: String) {
        // Parse the incoming message.
        var error : NSError?
        let data : AnyObject? = NSJSONSerialization.JSONObjectWithData(
            message.dataUsingEncoding(NSUTF8StringEncoding)!,
            options: NSJSONReadingOptions.allZeros,
            error: &error)
        if let object: AnyObject = data {
            println("INFO: \(object)")
            // If the message has a type of answer or offer try to handle it.
            if let type = object.objectForKey("type") as? String {
                switch type {
                    case "offer", "answer":
                        if let sdpString = object.objectForKey("sdp") as? String {
                            let sdp = RTCSessionDescription(type: type, sdp: sdpString)
                            self.peerConnection.setRemoteDescriptionWithDelegate(SessionDescriptionDelegate(session: self),
                                                                                 sessionDescription: sdp)
                        }
                    default:
                        println("ERROR: Invalid message \(message)")
                }
            }
        } else {
            if let parseError = error {
                println("ERROR: \(parseError.localizedDescription)")
            }
            return
        }
    }

    func disconnect() {
        if self.peerConnection != nil {
            self.peerConnection.close()
        }
        self.plugin.destroySession(self.sessionKey)
    }
    
    func sendMessage(message: NSData) {
        self.plugin.sendMessage(self.callbackId, message: message)
    }
}
