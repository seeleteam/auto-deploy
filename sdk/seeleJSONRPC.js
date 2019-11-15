const {
  commands,
  isCommand,
  getNamespace
} = require('./rpccommands')

if (typeof window !== 'undefined' && window.XMLHttpRequest) {
  XMLHttpRequest = window.XMLHttpRequest; // jshint ignore: line
} else {
  XMLHttpRequest = require('xmlhttprequest').XMLHttpRequest; // jshint ignore: line
  // XMLHttpRequest = new XMLHttpRequest();
}

class seeleJSONRPC {
  constructor(host, timeout) {
    this.host = host || 'http://localhost:8037';
    this.timeout = timeout || 30000;
  }

  /**
  * Should be called to prepare a new ClientRequest
  * @method prepareRequest
  * @param {Boolean} true if request should be async
  * @return {ClientRequest} object
  */
  prepareRequest(async) {
    var request = new XMLHttpRequest();
    request.withCredentials = false;
    request.open('POST', this.host, async);
    request.setRequestHeader('Content-Type', 'application/json');
    return request;
  }

  /**
  * Should be called to make async request
  * @method send
  * @param {String} command
  * @return {Object} request
  * @todo Using namespace
  */
  send(command) {
    var currHost = this.host;
    return new Promise((resolve, reject) => {
      if(!isCommand(command)){
        this.invalid(command)
        reject(new Error(`command ${command} does not exist`))
      }
      var args = Array.prototype.slice.call(arguments, 1)
      if (typeof args[args.length - 1] === 'function') {
        resolve = args[args.length - 1].bind(this);
        reject = args.pop().bind(this);
      }

      var request = this.prepareRequest(true)
      var rpcData = JSON.stringify({
        id: new Date().getTime(),
        method: getNamespace(command).concat("_").concat(command),
        params: args
      });

      request.onload = function () {
        if (request.readyState === 4 && request.timeout !== 1) {
          var result = request.responseText
          try {
            result = JSON.parse(result);
            if (result.error) {
              reject(args,new Error(JSON.stringify(result)));
              return;
            }

            resolve(result.result);
          } catch (exception) {
            reject(args,new Error(exception + ' : ' + JSON.stringify(result)));
          }
        }
      };

      request.ontimeout = function () {
        reject(args,new Error('CONNECTION TIMEOUT: timeout of ' + currHost + ' ms achieved'));
      };

      request.onerror = function () {
        if(request.status == 0){
          reject(args,new Error('CONNECTION ERROR: Couldn\'t connect to node '+currHost +'.'));
        }else{
          reject(args,request.statusText);
        }
      };

      try {
        request.send(rpcData);
      } catch (error) {
        reject(args,new Error('CONNECTION ERROR: Couldn\'t connect to node '+ currHost +'.'));
      }
      return request;
    })
  }

  /**
  * Should be called to make sync request
  * @method send
  * @param {String} command
  * @return {Object} result
  * @todo Using namespace
  */
  sendSync(command) {
    if(!isCommand(command)){
      this.invalid(command)
      reject(new Error(`command ${command} does not exist`))
    }
    var args    = Array.prototype.slice.call(arguments, 1)

    var request = this.prepareRequest(false)
    var rpcData = JSON.stringify({
      id: new Date().getTime(),
      method: getNamespace(command).concat("_").concat(command),
      params: args
    });

    request.onerror = function () {
      throw request.statusText
    };

    try {
      request.send(rpcData);
    } catch (error) {
      console.log(error)
      throw new Error('CONNECTION ERROR: Couldn\'t connect to node '+ this.host +'.');
    }

    var result = request.responseText;

    try {
      result = JSON.parse(result);
      if (result.error) {
        throw new Error(JSON.stringify(result));
      }

      return result.result
    } catch (exception) {
      throw new Error(exception + ' : ' + JSON.stringify(result));
    }
  }

  /**
   * If an invalid command is called, it is processed
   * @param {string} command
   */
  invalid(command) {
    return console.log(new Error('No such command "' + command + '"'));
  }

}

for (const namespace in commands) {
  commands[namespace].forEach(command => {
    var cp = seeleJSONRPC.prototype
    cp[command] = function() {
      return this.send(command, ...arguments);
    }
  })
}

module.exports = seeleJSONRPC;
