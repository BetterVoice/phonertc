package com.dooble.phonertc;

import java.util.LinkedList;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.PluginResult;
import org.json.JSONException;
import org.json.JSONObject;
import org.webrtc.AudioTrack;
import org.webrtc.DataChannel;
import org.webrtc.IceCandidate;
import org.webrtc.MediaConstraints;
import org.webrtc.MediaStream;
import org.webrtc.PeerConnection;
import org.webrtc.PeerConnectionFactory;
import org.webrtc.SdpObserver;
import org.webrtc.SessionDescription;
import org.webrtc.VideoRenderer;
import org.webrtc.PeerConnection.IceConnectionState;
import org.webrtc.PeerConnection.IceGatheringState;
import org.webrtc.VideoRenderer.I420Frame;
import org.webrtc.VideoRendererGui;
import org.webrtc.VideoTrack;

import android.app.Activity;
import android.util.Log;
import android.webkit.WebView;

public class Session {
	PhoneRTCPlugin _plugin;
	SessionConfig _config;
	
	MediaConstraints _sdpMediaConstraints;
	PeerConnection _peerConnection;
	
	private LinkedList<IceCandidate> _queuedRemoteCandidates;
	private Object _queuedRemoteCandidatesLocker = new Object();
	
	private MediaStream _localStream;
	private MediaStream _remoteStream;
	
	// Synchronize on quit[0] to avoid teardown-related crashes.
	private final Boolean[] _quit = new Boolean[] { false };
	
	private final SDPObserver _sdpObserver = new SDPObserver();
	private final PCObserver _pcObserver = new PCObserver();

	VideoRenderer.Callbacks _videoRenderer;
	
	public Session(PhoneRTCPlugin plugin, SessionConfig config) {
		_plugin = plugin;
		_config = config;
	}
	
	public void initialize() {
		_queuedRemoteCandidates = new LinkedList<IceCandidate>();
		_quit[0] = false;

		// Initialize ICE server list
		final LinkedList<PeerConnection.IceServer> iceServers = new LinkedList<PeerConnection.IceServer>();
		iceServers.add(new PeerConnection.IceServer("stun:stun.l.google.com:19302"));
		iceServers.add(new PeerConnection.IceServer(_config.getTurnServerHost(),
													_config.getTurnServerUsername(), 
													_config.getTurnServerPassword()));
		
		// Initialize SDP media constraints
		_sdpMediaConstraints = new MediaConstraints();
		_sdpMediaConstraints.mandatory.add(new MediaConstraints.KeyValuePair(
				"OfferToReceiveAudio", "true"));
		_sdpMediaConstraints.mandatory.add(new MediaConstraints.KeyValuePair(
				"OfferToReceiveVideo", _plugin.getLocalVideoTrack() != null ? "true" : "false"));
		
		// Initialize PeerConnection
		MediaConstraints pcMediaConstraints = new MediaConstraints();
		pcMediaConstraints.optional.add(new MediaConstraints.KeyValuePair(
			"DtlsSrtpKeyAgreement", "true"));
		
		_peerConnection = _plugin.getPeerConnectionFactory()
				.createPeerConnection(iceServers, pcMediaConstraints, _pcObserver);
		
		// Initialize local stream
		_localStream = _plugin.getPeerConnectionFactory().createLocalMediaStream("ARDAMS");
		_localStream.addTrack(_plugin.getLocalAudioTrack());
		 
		if (_plugin.getLocalVideoTrack() != null) {
			_localStream.addTrack(_plugin.getLocalVideoTrack());
		}
		
		_peerConnection.addStream(_localStream, new MediaConstraints());
	
		/*
		try {
			_videoRenderer = VideoRendererGui.create(0, 0, 100, 100);
		} catch (Exception e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}*/
		
		// Create offer if initiator
		if (_config.isInitiator()) {
			_peerConnection.createOffer(_sdpObserver, _sdpMediaConstraints);
		}
	}
	
	public void receiveMessage(String message) {
		try {
			JSONObject json = new JSONObject(message);
			String type = (String) json.get("type");
			if (type.equals("candidate")) {
				final IceCandidate candidate = new IceCandidate(
						(String) json.get("id"), json.getInt("label"),
						(String) json.get("candidate"));
				
				synchronized (_queuedRemoteCandidatesLocker) {
					if (_queuedRemoteCandidates != null) {
						_queuedRemoteCandidates.add(candidate);
					} else {
						_plugin.getActivity().runOnUiThread(new Runnable() {
							public void run() {
								if (_peerConnection != null) {
									_peerConnection.addIceCandidate(candidate);
								}
							}
						});	
					}
				}

			} else if (type.equals("answer") || type.equals("offer")) {
				final SessionDescription sdp = new SessionDescription(
						SessionDescription.Type.fromCanonicalForm(type),
						preferISAC((String) json.get("sdp")));
				_plugin.getActivity().runOnUiThread(new Runnable() {
					public void run() {
						_peerConnection.setRemoteDescription(_sdpObserver, sdp);
					}
				});
			} else if (type.equals("bye")) {
				Log.d("com.dooble.phonertc", "Remote end hung up; dropping PeerConnection");

				_plugin.getActivity().runOnUiThread(new Runnable() {
					public void run() {
						disconnect();
					}
				});
			} else {
				// throw new RuntimeException("Unexpected message: " + message);
			}
		} catch (JSONException e) {
			throw new RuntimeException(e);
		}
	}
	
	void sendMessage(JSONObject data) {
		
	}

	String preferISAC(String sdpDescription) {
		String[] lines = sdpDescription.split("\r?\n");
		int mLineIndex = -1;
		String isac16kRtpMap = null;
		Pattern isac16kPattern = Pattern
				.compile("^a=rtpmap:(\\d+) ISAC/16000[\r]?$");
		for (int i = 0; (i < lines.length)
				&& (mLineIndex == -1 || isac16kRtpMap == null); ++i) {
			if (lines[i].startsWith("m=audio ")) {
				mLineIndex = i;
				continue;
			}
			Matcher isac16kMatcher = isac16kPattern.matcher(lines[i]);
			if (isac16kMatcher.matches()) {
				isac16kRtpMap = isac16kMatcher.group(1);
				continue;
			}
		}
		if (mLineIndex == -1) {
			Log.d("com.dooble.phonertc",
					"No m=audio line, so can't prefer iSAC");
			return sdpDescription;
		}
		if (isac16kRtpMap == null) {
			Log.d("com.dooble.phonertc",
					"No ISAC/16000 line, so can't prefer iSAC");
			return sdpDescription;
		}
		String[] origMLineParts = lines[mLineIndex].split(" ");
		StringBuilder newMLine = new StringBuilder();
		int origPartIndex = 0;
		// Format is: m=<media> <port> <proto> <fmt> ...
		newMLine.append(origMLineParts[origPartIndex++]).append(" ");
		newMLine.append(origMLineParts[origPartIndex++]).append(" ");
		newMLine.append(origMLineParts[origPartIndex++]).append(" ");
		newMLine.append(isac16kRtpMap).append(" ");
		for (; origPartIndex < origMLineParts.length; ++origPartIndex) {
			if (!origMLineParts[origPartIndex].equals(isac16kRtpMap)) {
				newMLine.append(origMLineParts[origPartIndex]).append(" ");
			}
		}
		lines[mLineIndex] = newMLine.toString();
		StringBuilder newSdpDescription = new StringBuilder();
		for (String line : lines) {
			newSdpDescription.append(line).append("\r\n");
		}
		return newSdpDescription.toString();
	}

	public void disconnect() {
		synchronized (_quit[0]) {
			if (_quit[0]) {
				return;
			}
			
			_quit[0] = true;
			
			if (_peerConnection != null) {
				_peerConnection.dispose();
				_peerConnection = null;
			}

			try {
				JSONObject json = new JSONObject();
				json.put("type", "bye");
				sendMessage(json);
			} catch (JSONException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
			
			// TODO: cleanup video

		}

		try {
			JSONObject data = new JSONObject();
			data.put("type", "__disconnected");
			sendMessage(data);
		} catch (JSONException e) {

		}
	}

	private class PCObserver implements PeerConnection.Observer {

		@Override
		public void onIceCandidate(final IceCandidate iceCandidate) {
			_plugin.getActivity().runOnUiThread(new Runnable() {
				public void run() {
					try {
						JSONObject json = new JSONObject();
						json.put("type", "candidate");
						json.put("label", iceCandidate.sdpMLineIndex);
						json.put("id", iceCandidate.sdpMid);
						json.put("candidate", iceCandidate.sdp);
						sendMessage(json);
					} catch (JSONException e) {
						// TODO Auto-generated catch bloc
						e.printStackTrace();
					}
				}
			});
		}

		@Override
		public void onAddStream(final MediaStream stream) {
			_remoteStream = stream;
			
			_plugin.getActivity().runOnUiThread(new Runnable() {
				public void run() {
					/*
					VideoTrack videoTrack = stream.videoTracks.get(0);
					
					if (videoTrack != null) {
						videoTrack.addRenderer(new VideoRenderer(_videoRenderer));
					}*/

					try {
						JSONObject data = new JSONObject();
						data.put("type", "__answered");
						sendMessage(data);
					} catch (JSONException e) {

					}
				}
			});
		}

		@Override
		public void onDataChannel(DataChannel stream) {
			// TODO Auto-generated method stub

		}

		@Override
		public void onError() {
			// TODO Auto-generated method stub

		}

		@Override
		public void onIceConnectionChange(IceConnectionState arg0) {
			// TODO Auto-generated method stub

		}

		@Override
		public void onIceGatheringChange(IceGatheringState arg0) {
			try {
				JSONObject json = new JSONObject();
				json.put("type", "IceGatheringChange");
				json.put("state", arg0.name());
				sendMessage(json);
			} catch (JSONException e) {
				e.printStackTrace();
			}
		}

		@Override
		public void onRemoveStream(MediaStream arg0) {
			// TODO Auto-generated method stub

		}

		@Override
		public void onRenegotiationNeeded() {
			// TODO Auto-generated method stub

		}

		@Override
		public void onSignalingChange(
				PeerConnection.SignalingState signalingState) {

		}

	}

	private class SDPObserver implements SdpObserver {
		@Override
		public void onCreateSuccess(final SessionDescription origSdp) {
			_plugin.getActivity().runOnUiThread(new Runnable() {
				public void run() {
					SessionDescription sdp = new SessionDescription(
							origSdp.type, preferISAC(origSdp.description));
					try {
						JSONObject json = new JSONObject();
						json.put("type", sdp.type.canonicalForm());
						json.put("sdp", sdp.description);
						sendMessage(json);
						_peerConnection.setLocalDescription(_sdpObserver, sdp);
					} catch (JSONException e) {
						// TODO Auto-generated catch block
						e.printStackTrace();
					}
				}
			});
		}

		@Override
		public void onSetSuccess() {
			_plugin.getActivity().runOnUiThread(new Runnable() {
				public void run() {
					if (_config.isInitiator()) {
						if (_peerConnection.getRemoteDescription() != null) {
							// We've set our local offer and received & set the
							// remote
							// answer, so drain candidates.
							drainRemoteCandidates();
						}
					} else {
						if (_peerConnection.getLocalDescription() == null) {
							// We just set the remote offer, time to create our
							// answer.
							_peerConnection.createAnswer(SDPObserver.this,
									_sdpMediaConstraints);
						} else {
							// Sent our answer and set it as local description;
							// drain
							// candidates.
							drainRemoteCandidates();
						}
					}
				}
			});
		}

		@Override
		public void onCreateFailure(final String error) {
			_plugin.getActivity().runOnUiThread(new Runnable() {
				public void run() {
					throw new RuntimeException("createSDP error: " + error);
				}
			});
		}
		
		@Override
		public void onSetFailure(final String error) {
			_plugin.getActivity().runOnUiThread(new Runnable() {
				public void run() {
					//throw new RuntimeException("setSDP error: " + error);
				}
			});
		}

		private void drainRemoteCandidates() {
			synchronized (_queuedRemoteCandidatesLocker) {
				if (_queuedRemoteCandidates == null)
					return;
				
				for (IceCandidate candidate : _queuedRemoteCandidates) {
					_peerConnection.addIceCandidate(candidate);
				}
				
				_queuedRemoteCandidates = null;
			}
		}
	}
}