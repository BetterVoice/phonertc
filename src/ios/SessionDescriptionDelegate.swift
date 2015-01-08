import Foundation

class SessionDescriptionDelegate : UIResponder, RTCSessionDescriptionDelegate {
    var session: Session
    
    init(session: Session) {
        self.session = session
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!,
                        didCreateSessionDescription sdp: RTCSessionDescription!,
                        peerConnectionError: NSError!) {
        // Set the local session description and dispatch a copy to the js engine.
        if peerConnectionError == nil {
            self.session.peerConnection.setLocalDescriptionWithDelegate(self, sessionDescription: sdp)
            dispatch_async(dispatch_get_main_queue()) {
                let json: AnyObject = [
                    "type": sdp.type,
                    "sdp": sdp.description
                ]
                var error: NSError?
                let data = NSJSONSerialization.dataWithJSONObject(json,
                    options: NSJSONWritingOptions.allZeros,
                    error: &error)
                if let message = data {
                    self.session.sendMessage(data!)
                } else {
                    if let jsonError = error {
                        println("ERROR: \(jsonError.localizedDescription)")
                    }
                }
            }
        } else {
            println("ERROR: \(peerConnectionError.localizedDescription)")
        }
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!,
        didSetSessionDescriptionWithError peerConnectionError: NSError!) {
        // If we are acting as the callee then generate an answer to the offer.
        if peerConnectionError == nil {
            dispatch_async(dispatch_get_main_queue()) {
                if !self.session.config.isInitiator &&
                   self.session.peerConnection.localDescription == nil {
                    self.session.peerConnection.createAnswerWithDelegate(self, constraints: self.session.peerConnectionConstraints)
                }
            }
        } else {
            println("ERROR: \(peerConnectionError.localizedDescription)")
        }
    }
}