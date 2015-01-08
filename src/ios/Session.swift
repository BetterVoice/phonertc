import Foundation

class Session {
    var plugin: PhoneRTCPlugin
    var config: SessionConfig
    var constraints: RTCMediaConstraints
    var peerConnection: RTCPeerConnection!
    var pcObserver: PCObserver!
    var peerConnectionFactory: RTCPeerConnectionFactory
    var callbackId: String
    var stream: RTCMediaStream?
    var sessionKey: String
    
    init(plugin: PhoneRTCPlugin,
         peerConnectionFactory: RTCPeerConnectionFactory,
         config: SessionConfig,
         callbackId: String,
         sessionKey: String) {
        self.plugin = plugin
        self.config = config
        self.peerConnectionFactory = peerConnectionFactory
        self.callbackId = callbackId
        self.sessionKey = sessionKey
        let mandatory = [
            RTCPair(key: "OfferToReceiveAudio", value: "true"),
            RTCPair(key: "OfferToReceiveVideo", value: "false")
        ]
        let optional = [
            RTCPair(key: "internalSctpDataChannels", value: "true"),
            RTCPair(key: "DtlsSrtpKeyAgreement", value: "true")
        ]
        self.constraints = RTCMediaConstraints(mandatoryConstraints: mandatory,
                                               optionalConstraints: optional)
    }
    
    func call() {
        // create a list of ICE servers
        var iceServers: [RTCICEServer] = []
        iceServers.append(RTCICEServer(
            URI: NSURL(string: "stun:stun.l.google.com:19302"),
            username: "",
            password: ""))
        iceServers.append(RTCICEServer(
            URI: NSURL(string: self.config.turn.host),
            username: self.config.turn.username,
            password: self.config.turn.password))
        // initialize a PeerConnection
        self.pcObserver = PCObserver(session: self)
        self.peerConnection =
            peerConnectionFactory.peerConnectionWithICEServers(iceServers,
                constraints: self.constraints,
                delegate: self.pcObserver)
        
        // create a media stream and add audio and/or video tracks
        createOrUpdateStream()
        
        // create offer if initiator
        if self.config.isInitiator {
            self.peerConnection.createOfferWithDelegate(SessionDescriptionDelegate(session: self),
                constraints: constraints)
        }
    }
    
    func createOrUpdateStream() {
        if self.stream != nil {
            self.peerConnection.removeStream(self.stream)
            self.stream = nil
        }
        
        self.stream = peerConnectionFactory.mediaStreamWithLabel("ARDAMS")
        
        if self.config.streams.audio {
            // init local audio track if needed
            if self.plugin.localAudioTrack == nil {
                self.plugin.initLocalAudioTrack()
            }
            
            self.stream!.addAudioTrack(self.plugin.localAudioTrack!)
        }
        
        self.peerConnection.addStream(self.stream)
    }

    func toggleMute(mute: Bool) {
        for item in self.stream!.audioTracks {
            let track = item as RTCAudioTrack
            track.setEnabled(!mute)
        }
    }
    
    func receiveMessage(message: String) {
        // Parse the incoming JSON message.
        var error : NSError?
        let data : AnyObject? = NSJSONSerialization.JSONObjectWithData(
            message.dataUsingEncoding(NSUTF8StringEncoding)!,
            options: NSJSONReadingOptions.allZeros,
            error: &error)
        if let object: AnyObject = data {
            // Log the message to console.
            println("Received Message: \(object)")
            // If the message has a type try to handle it.
            if let type = object.objectForKey("type") as? String {
                switch type {
                    case "offer", "answer":
                        if let sdpString = object.objectForKey("sdp") as? String {
                            let sdp = RTCSessionDescription(type: type, sdp: sdpString)
                            self.peerConnection.setRemoteDescriptionWithDelegate(SessionDescriptionDelegate(session: self),
                                                                                 sessionDescription: sdp)
                        }
                    case "bye":
                        self.disconnect(false)
                    default:
                        println("Invalid message \(message)")
                }
            }
        } else {
            // If there was an error parsing then print it to console.
            if let parseError = error {
                println("There was an error parsing the client message: \(parseError.localizedDescription)")
            }
            // If there is no data then exit.
            return
        }
    }

    func disconnect(sendByeMessage: Bool) {
        if self.peerConnection != nil {
            if sendByeMessage {
                let json: AnyObject = [
                    "type": "bye"
                ]
            
                let data = NSJSONSerialization.dataWithJSONObject(json,
                    options: NSJSONWritingOptions.allZeros,
                    error: nil)
            
                self.sendMessage(data!)
            }
        
            self.peerConnection.close()
            self.peerConnection = nil
        }
        
        let json: AnyObject = [
            "type": "__disconnected"
        ]
        
        let data = NSJSONSerialization.dataWithJSONObject(json,
            options: NSJSONWritingOptions.allZeros,
            error: nil)
        
        self.sendMessage(data!)
        
        self.plugin.onSessionDisconnect(self.sessionKey)
    }
    
    func sendMessage(message: NSData) {
        self.plugin.sendMessage(self.callbackId, message: message)
    }
}
