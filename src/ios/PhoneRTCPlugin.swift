import Foundation
import AVFoundation

@objc(PhoneRTCPlugin)
class PhoneRTCPlugin : CDVPlugin {
    var peerConnectionFactory: RTCPeerConnectionFactory
    var sessions: [String: Session]
    var sockets: [String: WebSocket]
    
    override init(webView: UIWebView) {
        peerConnectionFactory = RTCPeerConnectionFactory()
        RTCPeerConnectionFactory.initializeSSL()
        sessions = [:]
        sockets = [:]
        super.init(webView: webView)
    }
    
    func createSession(command: CDVInvokedUrlCommand) {
        if let sessionKey = command.argumentAtIndex(0) as? String {
            if let args: AnyObject = command.argumentAtIndex(1) {
                let config = SessionConfig(data: args)
                let session = Session(config: config, peerConnectionFactory: peerConnectionFactory,
                    plugin: self, callbackId: command.callbackId, sessionKey: sessionKey)
                sessions[sessionKey] = session
            }
        }
    }

    func destroySession(sessionKey: String) {
        self.sessions.removeValueForKey(sessionKey)
    }

    func createWebSocket(command: CDVInvokedUrlCommand) {
        if let sessionKey = command.argumentAtIndex(0) as? String {
            if let args: AnyObject = command.argumentAtIndex(1) {
                if let url = args.objectForKey("url") as? String {
                    let protocols = args.objectForKey("protocols") as? [String]
                    let socket = WebSocket(url: url, protocols: protocols,
                        plugin: self, callbackId: command.callbackId, 
                        sessionKey: sessionKey)
                    socket.open();
                    sockets[sessionKey] = socket
                }
            }
        }
    }

    func destroyWebSocket(sessionKey: String) {
        self.sockets.removeValueForKey(sessionKey)
    }

    func disconnect(command: CDVInvokedUrlCommand) {
        let args: AnyObject = command.argumentAtIndex(0)
        if let sessionKey = args.objectForKey("sessionKey") as? String {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                if (self.sessions[sessionKey] != nil) {
                    self.sessions[sessionKey]!.disconnect()
                }
            }
        }
    }
    
    func initialize(command: CDVInvokedUrlCommand) {
        let args: AnyObject = command.argumentAtIndex(0)
        if let sessionKey = args.objectForKey("sessionKey") as? String {
            dispatch_async(dispatch_get_main_queue()) {
                if let session = self.sessions[sessionKey] {
                    session.initialize()
                }
            }
        }
    }
    
    func receive(command: CDVInvokedUrlCommand) {
        let args: AnyObject = command.argumentAtIndex(0)
        if let sessionKey = args.objectForKey("sessionKey") as? String {
            if let message = args.objectForKey("message") as? String {
                if let session = self.sessions[sessionKey] {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                        session.receive(message)
                    }
                }
            }
        }
    }

    func send(callbackId: String, message: NSData) {
        let json = NSJSONSerialization.JSONObjectWithData(message,
            options: NSJSONReadingOptions.MutableLeaves,
            error: nil) as NSDictionary
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsDictionary: json)
        pluginResult.setKeepCallbackAsBool(true);
        self.commandDelegate.sendPluginResult(pluginResult, callbackId: callbackId)
    }

    func toggleMute(command: CDVInvokedUrlCommand) {
        let args: AnyObject = command.argumentAtIndex(0);
        if let sessionKey = args.objectForKey("sessionKey") as? String {
            if let mute: Bool = args.objectForKey("mute") as? Bool {
                dispatch_async(dispatch_get_main_queue()) {
                    if let session = self.sessions[sessionKey] {
                        session.toggleMute(mute)
                    }
                }
            }
        }
    }
}