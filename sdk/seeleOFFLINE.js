const createKeccakHash = require('keccak')    // for hashing
const RLP = require('rlp')                    // for serialization
const secp256k1 = require('secp256k1')        // for elliptic operations
let solc = require('solc');
let shardnum = 4


class seeleOFFLINE {
  constructor(keyfileDir) {
    this.keyfileDir = keyfileDir || '~/.anchor';
  }
  
  initTx(pubkey, to, amount, payload){
    //verify pubkey, to, amount, payload?
    return {
          "Type":         0,
          "From":         pubkey,
          "To":           to,
          "Amount":       amount,
          "AccountNonce": 0,
          "GasPrice":     1,
          "GasLimit":     0,
          "Timestamp":    0,
          "Payload":      payload
    }
  }
  
  signTx(prikey, tx){
    // check validity 
    var infolist = [
      tx.Type,
      tx.From,
      tx.To,
      tx.Amount,
      tx.AccountNonce,
      tx.GasPrice,
      tx.GasLimit,
      tx.Timestamp,
      tx.Payload
    ]
    
    this.hash = "0x"+createKeccakHash('keccak256').update(RLP.encode(infolist)).digest().toString('hex')
    var signature = secp256k1.sign(Buffer.from(this.hash.slice(2), 'hex'), Buffer.from(prikey.slice(2), 'hex'))
    this.sign = Buffer.concat([signature.signature,Buffer.from([signature.recovery])]).toString('base64')
    this.Data = tx
    this.txDone = {
      "Hash": this.hash,
      "Data": this.Data,
      "Signature": {
        "Sig": this.sign,
      }
    }
    return this.txDone
  }
  
  shardOfpub(pubkey){
    var sum = 0
    var buf = Buffer.from(pubkey.substring(2), 'hex')
    for (const pair of buf.entries()) {if (pair[0] < 18){sum += pair[1]}}
    sum += (buf.readUInt16BE(18) >> 4)
    return (sum % shardnum) + 1
  }
  
  validPub(pubkey){
    if (!(/^(0x)?[0-9a-f]{40}$/.test(pubkey) || /^(0x)?[0-9A-F]{40}$/.test(pubkey))) {
      return false;
    } 
    return true
  }
  
  compile(code, contractName, version){
    solc = solc.setupMethods(require(`./solc/${version}`))
    var input = {language: 'Solidity',sources: {'test.sol': {content: code}},settings: {outputSelection: {'*': {'*': ['*']}}}}
    var output = JSON.parse(solc.compile(JSON.stringify(input)))
    return {
      "payload": "0x"+output.contracts['test.sol'][contractName].evm.bytecode.object,
      "abi": output.contracts['test.sol'][contractName].abi,
      "version": JSON.parse(output.contracts['test.sol'][contractName].metadata).compiler.version
    }
  }
  
  compilepromise(code, version){
    return new Promise((resolve, reject)=>{
      solc = solc.setupMethods(require(`./solc/${version}`))
      var input = {language: 'Solidity',sources: {'test.sol': {content: code}},settings: {outputSelection: {'*': {'*': ['*']}}}}
      var output = JSON.parse(solc.compile(JSON.stringify(input)))
      if (output.errors) reject(output.errors)
      resolve(output)
    })
  }
  
  txValidity(tx){
    if (typeof tx.to !== 'string' || tx.to.length!=42 || tx.to.slice(0,2)!="0x"){
      throw "invalid receiver address, should be of length 42 with prefix 0x"
      return false
    }
    if (typeof tx.payload !== 'string'){
      throw "invalid payload"
      return false
    }
    if (typeof tx.nonce !== 'number' || tx.nonce < 0) {
      console.log(typeof tx.nonce)
      throw "invalid nonce" 
      return false
    }
    if (typeof tx.amount !== 'number' || tx.amount < 0) {
      console.log(typeof tx.amount)
      throw "invalid amount" 
      return false
    }
    if (typeof tx.price !== 'number' || tx.price < 0) {
      console.log(typeof tx.price)
      throw "invalid price" 
      return false
    }
    if (typeof tx.limit !== 'number' || tx.limit < 0) {
      console.log(typeof tx.limit)
      throw "invalid limit" 
      return false
    }
    return true
    
    //nonce, amount, price and limit must be positive integers
  }
  
  publicKeyOf(privateKey){
    if (privateKey.length!=66){throw "privatekey string should be of lenth 66"} 
    if (privateKey.slice(0,2)!="0x"){throw "privateKey string should start with 0x"}
    const inbuf = Buffer.from(privateKey.slice(2), 'hex');
    if (!secp256k1.privateKeyVerify(inbuf)){throw "invalid privateKey"}
    const oubuf = secp256k1.publicKeyCreate(inbuf, false).slice(1);
    var publicKey = createKeccakHash('keccak256').update(RLP.encode(oubuf)).digest().slice(12).toString('hex')
    return "0x"+publicKey.replace(/.$/i,"1")
  }
}

module.exports = seeleOFFLINE;