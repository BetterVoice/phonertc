import Foundation

class WebSocketDelegate : NSObject, SRWebSocketDelegate {
    // Cordova Stuff
    var plugin: PhoneRTCPlugin
    var callbackId: String
    
    override init(plugin: PhoneRTCPlugin, callbackId: String) {
        self.plugin = plugin
        self.callbackId = callbackId
    }
    
    func webSocketDidOpen(webSocket: SRWebSocket!) {
        
    }
    
    func webSocket(websocket: SRWebSocket!, didFailWithError error: NSError!) {
        
    }
    
    func webSocket(webSocket: SRWebSocket!, didCloseWithCode code: NSInteger!,
                   reason: NSString!, wasClean: Boolean!) {
            
    }
    
    func webSocket(webSocket: SRWebSocket!, didReceivePong pongPayload: NSData!) {
        
    }
    
    func webSocket(webSocket: SRWebSocket!, didReceiveMessage message: AnyObject!) {
        // All incoming messages ( socket.on() ) are received in this function. Parsed with JSON
        println("MESSAGE: \(message)")
    }
}