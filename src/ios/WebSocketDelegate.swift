import Foundation

class WebSocketDelegate : NSObject, SRWebSocketDelegate {
    // Cordova Stuff
    var plugin: PhoneRTCPlugin
    var callbackId: String
    
    init(plugin: PhoneRTCPlugin, callbackId: String) {
        self.plugin = plugin
        self.callbackId = callbackId
    }
    
    func webSocketDidOpen(webSocket: SRWebSocket!) {
        println("INFO: A Web Socket has been opened.")
    }
    
    func webSocket(websocket: SRWebSocket!, didFailWithError error: NSError!) {
        println("INFO: A Web Socket has failed with a fatal error.")
    }
    
    func webSocket(webSocket: SRWebSocket!, didCloseWithCode code: NSInteger!,
                   reason: NSString!, wasClean: Boolean!) {
        println("INFO: A Web Socket has been closed with code \"\(code)\" and reason \"\(reason)\".")
    }
    
    func webSocket(webSocket: SRWebSocket!, didReceivePong pongPayload: NSData!) {
        println("INFO: Received a Pong message.")
    }
    
    func webSocket(webSocket: SRWebSocket!, didReceiveMessage message: AnyObject!) {
        println("INFO: Received a message: \(message)")
        // self.plugin.send(self.callbackId, message: message)
    }
}