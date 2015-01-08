var exec = require('cordova/exec');

function createUUID() {
  // http://www.ietf.org/rfc/rfc4122.txt
  var s = [];
  var hexDigits = "0123456789abcdef";
  for (var i = 0; i < 36; i++) {
      s[i] = hexDigits.substr(Math.floor(Math.random() * 0x10), 1);
  }
  s[14] = "4";  // bits 12-15 of the time_hi_and_version field to 0010
  s[19] = hexDigits.substr((s[19] & 0x3) | 0x8, 1);  // bits 6-7 of the clock_seq_hi_and_reserved to 01
  s[8] = s[13] = s[18] = s[23] = "-";

  var uuid = s.join("");
  return uuid;
}

function Session(config) {
  if (typeof config !== 'object') {
    throw {
      name: 'PhoneRTC Error',
      message: 'The first argument must be an object.'
    };
  }

  if (typeof config.isInitiator === 'undefined' ||
      typeof config.turn === 'undefined' ||
      typeof config.streams === 'undefined') {
    throw {
      name: 'PhoneRTC Error',
      message: 'isInitiator, turn and streams are required parameters.'
    };
  }

  var self = this;
  self.events = {};
  self.config = config;
  self.sessionKey = createUUID();

  // make all config properties accessible from this object
  Object.keys(config).forEach(function (prop) {
    Object.defineProperty(self, prop, {
      get: function () { return self.config[prop]; },
      set: function (value) { self.config[prop] = value; }
    });
  });

  function callEvent(eventName) {
    if (!self.events[eventName]) {
      return;
    }

    var args = Array.prototype.slice.call(arguments, 1);
    self.events[eventName].forEach(function (callback) {
      callback.apply(self, args);
    });
  }

  function onSendMessage(data) {
    callEvent('sendMessage', data);
  }

  exec(onSendMessage, null, 'PhoneRTCPlugin', 'createSession', [self.sessionKey, config]);
};

Session.prototype.on = function (eventName, fn) {
  // make sure that the second argument is a function
  if (typeof fn !== 'function') {
    throw {
      name: 'PhoneRTC Error',
      message: 'The second argument must be a function.'
    };
  }

  // create the event if it doesn't exist
  if (!this.events[eventName]) {
    this.events[eventName] = [];
  } else {
    // make sure that this callback doesn't exist already
    for (var i = 0, len = this.events[eventName].length; i < len; i++) {
      if (this.events[eventName][i] === fn) {
        throw {
          name: 'PhoneRTC Error',
          message: 'This callback function was already added.'
        };
      }
    }
  }

  // add the event
  this.events[eventName].push(fn);
};

Session.prototype.off = function (eventName, fn) {
  // make sure that the second argument is a function
  if (typeof fn !== 'function') {
    throw {
      name: 'PhoneRTC Error',
      message: 'The second argument must be a function.'
    };
  }

  if (!this.events[eventName]) {
    return;
  }

  var indexesToRemove = [];
  for (var i = 0, len = this.events[eventName].length; i < len; i++) {
    if (this.events[eventName][i] === fn) {
      indexesToRemove.push(i);
    }
  }

  indexesToRemove.forEach(function (index) {
    this.events.splice(index, 1);
  })
};

Session.prototype.call = function () {
  exec(null, null, 'PhoneRTCPlugin', 'call', [{
    sessionKey: this.sessionKey
  }]);
};

Session.prototype.receiveMessage = function (data) {
  exec(null, null, 'PhoneRTCPlugin', 'receiveMessage', [{
    sessionKey: this.sessionKey,
    message: JSON.stringify(data)
  }]);
};

Session.prototype.mute = function () {
  exec(null, null, 'PhoneRTCPlugin', 'toggleMute', [{
    sessionKey: this.sessionKey,
    mute: true
  }]);
};

Session.prototype.unmute = function () {
  exec(null, null, 'PhoneRTCPlugin', 'toggleMute', [{
    sessionKey: this.sessionKey,
    mute: false
  }]);
};

Session.prototype.close = function () {
  exec(null, null, 'PhoneRTCPlugin', 'disconnect', [{ 
    sessionKey: this.sessionKey
  }]);
};

exports.Session = Session;