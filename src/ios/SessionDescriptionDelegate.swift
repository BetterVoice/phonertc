import Foundation

class SessionDescriptionDelegate : UIResponder, RTCSessionDescriptionDelegate {
    var session: Session
    
    init(session: Session) {
        self.session = session
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!,
        didCreateSessionDescription sdp: RTCSessionDescription!, error: NSError!) {
        // Set the local session description and dispatch a copy to the js engine.
        if error == nil {
            self.session.peerConnection.setLocalDescriptionWithDelegate(self, sessionDescription: sdp)
            dispatch_async(dispatch_get_main_queue()) {
                let json: AnyObject = [
                    "type": sdp.type,
                    "sdp": sdp.description
                ]
                var jsonError: NSError?
                let data = NSJSONSerialization.dataWithJSONObject(json,
                    options: NSJSONWritingOptions.allZeros,
                    error: &jsonError)
                if let message = data {
                    self.session.send(data!)
                } else {
                    if let serializationError = jsonError {
                        println("ERROR: \(serializationError.localizedDescription)")
                    }
                }
            }
        } else {
            println("ERROR: \(error.localizedDescription)")
        }
    }
    
    func peerConnection(peerConnection: RTCPeerConnection!,
        didSetSessionDescriptionWithError error: NSError!) {
        // If we are acting as the callee then generate an answer to the offer.
        if error == nil {
            dispatch_async(dispatch_get_main_queue()) {
                if !self.session.config.isInitiator &&
                   self.session.peerConnection.localDescription == nil {
                    self.session.peerConnection.createAnswerWithDelegate(self, constraints: self.session.peerConnectionConstraints)
                }
            }
        } else {
            println("ERROR: \(error.localizedDescription)")
        }
    }
}