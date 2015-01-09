import Foundation

class Session {
    // Cordova Stuff
    var plugin: PhoneRTCPlugin
    var callbackId: String
    // State Stuff
    var sessionKey: String
    // Web Socket Stuff.
    var socket: SRSocket
    var url: NSURL
    var protocols: [String]
    
    init(plugin: PhoneRTCPlugin,
         sessionKey: String,
         url: String,
         protocols: [String]) {
        self.url = NSURL(url)
        self.protocols = protocols
        self.plugin = plugin
        self.callbackId = callbackId
        self.sessionKey = sessionKey
    }

    func open() {
        
    }
}