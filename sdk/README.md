*nice*
- lint and test 
- handle all cases
- index only imports offline and jsonrpc
*must*
**TODO**
- deploy, employ and call a simple storage
- deploy:
  1. compile
  2. 
*done*




```js
const {
  soff,
  sweb,
  seelejs
} = requre('seele.js')
//understand synchronous and asynchronous actions in javascripts to make it comfortable to use!
//understand runtime initialization (for https connections or contract initializations) to make it fast to use!

//__________________________ offline actions 
soff.shardOf(pubkey) //return number 
soff.qrcodeOf(pubkey) //
soff.initTx(from, to, amount, pay) //return {Data: ...}
soff.validPub(pubkey) //return bool

soff.pubOf(prikey) //return 0x1adfqwer1adfqwer1adfqwer1adfqwer1adfqwer
soff.signTx(prikey, tx) // return {}
soff.validPri(prikey) //return bool
soff.genKey(shard)

soff.crypKF(prikey, pass) // return {version:...}
soff.dcryKF(kfobj, pass) //return 0x1adfqwer1adfqwer1adfqwer1adfqwer1adfqwer1adfqwer1adfqwer1adfqwer
soff.validKF(kfobj) //return bool

soff.bipOf(prikey) //return [ ... ]
soff.bipAutoFill(word) //return guess word
soff.priOf(words) //


//__________________________ online actions ??? how to set the address?
sweb.getNonce(pub)
sweb.getBalance(pub)
sweb.addTx(tx)
sweb.simpNodeInfo() // ipport(shard), height(age), version(p1, p2, p3, p4)
sweb.moreNodeInfo() // 
//


//__________________________ usecases

//1. sending a transcation
var txInit = soff.initTx(from, to, amount, payload) //return editable/printable object (edit price if you want)
var txFill = sweb.fillTx(txInit) //fill limit, nonce, check balance enough (check the limit)
var txDone = soff.signTx(soff.dcryKF(kfobj, pass), txFill) //return signed printable object (keep the hash), 
var result = sweb.sendTx(txDone) //broadcasted or not

//2. monitor your node
var result = sweb.simpNodeInfo()

//3. Create KF by shard, privatekey, phrase
var kf1 = soff.crypKF(soff.genKey(1).prikey, pass)
var kf2 = soff.crypKF(prikey, pass)
var kf3 = soff.crypKF(soff.priOf(words), pass)
var pri = soff.dcryKF(kfobj, pass)

//4. deploy, employ, call contract
var employpayload = sweb.getpayload(abi, method, args)
var txInit = soff.initTx(from, to, amount, payload) //return editable/printable object (edit price if you want)
var txFill = sweb.filltx(txInit) //fill limit, nonce, check balance enough (check the limit)
var txDone = soff.signTx(soff.dcryKF(kfobj, pass), txFill) //return signed printable object (keep the hash)
var result = sweb.sendTx(txDone) //broadcasted or not

var callpayload = sweb.getpayload(abi, method, args)
var result = sweb.call(callpayload)

```



- myContract = web3js.eth.Contract(myABI, myContractAddress);
- cryptoZombies.events.NewZombie().on("data", function(event) {
  let zombie = event.returnValues;
  console.log("A new zombie was born!", zombie.zombieId, zombie.name, zombie.dna);
}).on("error", console.error);