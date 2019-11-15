const seeleOFFLINE = require('./seeleOFFLINE')
const seeleJSONRPC = require('./seeleJSONRPC')
const localTool = new seeleOFFLINE('~/.anchor')

let shardnum = 4

let ipport = [
  0,
  'http://117.50.97.136:18037',
  'http://117.50.97.136:8038',
  'http://104.218.164.77:8039',
  'http://117.50.97.136:8036',
]

function sweb(){}

function soff(){}

sweb.getNonce = function(pub){
  var shard   = soff.shardOfpub(pub)
  var client = new seeleJSONRPC(ipport[shard])
  return client.sendSync('getAccountNonce',pub,'',-1);
}
// 
sweb.getBalance = function(pub){
  var shard = soff.shardOfpub(pub)
  var client = new seeleJSONRPC(ipport[shard])
  return client.sendSync('getBalance',pub,'',-1).Balance
}

sweb.fillTx = function(txInit){
  // update nonce, limit
  var nonce   = sweb.getNonce(txInit.From)
  var limit   = sweb.getBalance(txInit.From)
  var data = {
    "Data": {
      "From":         txInit.From,
      "To":           txInit.To,
      "Amount":       0,
      "GasPrice":     1,
      "GasLimit":     limit,
      "Payload":      txInit.Payload,
      "AccountNonce": nonce
    }
  }
  
  // estimate gas
  var shard   = soff.shardOfpub(txInit.From)
  var client = new seeleJSONRPC(ipport[shard])
  var estimate = client.sendSync('estimateGas',data)
  txInit.GasPrice     = 1
  txInit.GasLimit     = estimate
  txInit.AccountNonce = nonce
  
  return txInit
}

sweb.sendTx = function(txDone){
  var shard = soff.shardOfpub(txDone.Data.From)
  if (!shard) {
    return new Error('invalid account')
  }
  var client = new seeleJSONRPC(ipport[shard])
  
  // console.log(txDone);
  try {
    return client.sendSync('addTx', txDone)
  } catch (e) {
    console.log("?");
    console.log("err",e);
  }
}

sweb.call = function(contractAddress, payload){
  var shard   = soff.shardOfpub(contractAddress)
  var client  = new seeleJSONRPC(ipport[shard])
  var result  = client.sendSync("call", contractAddress, payload, -1)
  return result
}

sweb.nodeInfo = function(shard){
  var client = new seeleJSONRPC(ipport[shard])
  var result = client.sendSync('getInfo')
  return result
}

sweb.getPayload = function(abi, method, arg, address){
  var shard  = soff.shardOfpub(address)
  var client = new seeleJSONRPC(ipport[shard])
  var result = client.sendSync('generatePayload', abi, method, arg)
  return result
}

sweb.gettxbyhash = function(hash, shard){
  var client = new seeleJSONRPC(ipport[shard])
  var result = client.sendSync('getTransactionByHash', hash)
  return result
}

sweb.getrcbyhash = function(hash, shard){
  var client = new seeleJSONRPC(ipport[shard])
  var result = client.sendSync('getReceiptByTxHash', hash, "")
  return result
}
//__________________________

// soff.shardOfpri = function(prikey){}

soff.shardOfpub = localTool.shardOfpub

soff.signTx = localTool.signTx

soff.initTx = localTool.initTx

soff.compile = localTool.compile

soff.compilepromise = localTool.compilepromise

// soff.pubOf = function(prikey){}
// 
// soff.genKey = function(shard){}
// 
// soff.crypKF = function(prikey, pass){}
// 
// soff.dcryKF = function(kfobj, pass){}

// soff.validKF = function(kfobj){}

module.exports = {
  sweb: sweb,
  soff: soff
}