import Foundation

class SessionDescriptionDelegate : UIResponder, RTCSessionDescriptionDelegate {
    var session: Session
    
    init(session: Session) {
        self.session = session
    }

    func patchSessionDescription(sdp: String) -> String {
        var patched = ""
        let lines = sdp.componentsSeparatedByString("\r\n")
        for line in lines {
            if line.hasPrefix("c=IN IP4") {
                patched += replace(line, original: "0.0.0.0", other: "IP Address") + "\r\n"
            } else if line.hasPrefix("a=rtcp:") {
                patched += replace(line, original: "0.0.0.0", other: "IP Address") + "\r\n"
            } else if line.hasPrefix("m=audio") {
                patched += replace(line, original: "RTP/SAVPF", other: "UDP/TLS/RTP/SAVPF") + "\r\n"
            } else if line == "a=sendrecv" {
                // Don't add this attribute it's not necessary.
            } else {
                patched += line + "\r\n"
            }
        }
        return sdp
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

    func replace(text: String, original: String, other: String) -> String {
        return text
    }
}