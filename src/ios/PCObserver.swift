import Foundation

class PCObserver : NSObject, RTCPeerConnectionDelegate {
    var session: Session
    
    init(session: Session) {
        self.session = session
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!,
        addedStream stream: RTCMediaStream!) {
        println("PCO onAddStream.")
        self.session.sendMessage(
            "{\"type\": \"__answered\"}".dataUsingEncoding(NSUTF8StringEncoding)!)
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!,
        removedStream stream: RTCMediaStream!) {
        println("PCO onRemoveStream.")
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!,
        iceGatheringChanged newState: RTCICEGatheringState) {
        println("PCO onIceGatheringChange. \(newState)")
        
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!,
        iceConnectionChanged newState: RTCICEConnectionState) {
        println("PCO onIceConnectionChange. \(newState)")
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!,
        gotICECandidate candidate: RTCICECandidate!) {
        println("PCO onICECandidate.\n  Mid[\(candidate.sdpMid)] Index[\(candidate.sdpMLineIndex)] Sdp[\(candidate.sdp)]")
            
        var jsonError: NSError?

        let json: AnyObject = [
            "type": "candidate",
            "label": candidate.sdpMLineIndex,
            "id": candidate.sdpMid,
            "candidate": candidate.sdp
        ]
            
        let data = NSJSONSerialization.dataWithJSONObject(json,
            options: NSJSONWritingOptions.allZeros,
            error: &jsonError)
            
        self.session.sendMessage(data!)
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!,
        signalingStateChanged stateChanged: RTCSignalingState) {
        println("PCO onSignalingStateChange: \(stateChanged)")
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!,
        didOpenDataChannel dataChannel: RTCDataChannel!) {
        println("PCO didOpenDataChannel.")
    }
    
    func peerConnectionOnError(peerConnection: RTCPeerConnection!) {
        println("PCO onError.")
    }
    
    func peerConnectionOnRenegotiationNeeded(peerConnection: RTCPeerConnection!) {
        println("PCO onRenegotiationNeeded.")
    }
}