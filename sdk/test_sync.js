const { soff, sweb } = require('./index')
const RLP = require('rlp')
var Web3 = require('web3');
var web3 = new Web3(Web3.givenProvider || "ws://localhost:8545");

let test = {}
test.shardOfpub = 0
test.showObj    = 0
test.getinfo    = 0
test.getBalance = 0

test.compile    = 0
test.getPayload = 1

test.sendtx     = 0
test.call       = 0
test.status     = 0

test.decode     = 0

let prikey  = "0x67004d6fa8c80292640925109071320acd541409fb1948a91e82e460d7d5ad0e"

if (test.decode){
  var data = "0x1073657474696e672073746f726167657e"
  // var data = "0x6e21f6b5efb13424c26f701c7bf47a68981c3e41"
  var dbuf = Buffer.from(data.slice(2),'hex')
  // console.log(dbuf.toString().length);
  // console.log(dbuf.toString())
  
  var result = web3.eth.abi.decodeParameters([ { "indexed": false, "name": "sender", "type": "address" }, { "indexed": false, "name": "message", "type": "string" } ], '0x0000000000000000000000006e21f6b5efb13424c26f701c7bf47a68981c3e410000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000001073657474696e672073746f726167657e00000000000000000000000000000000');
  console.log(result);
  // var decoded = RLP.decode(dbuf, 'hex')
  // console.log(decoded.remainder.toString('hex'));
  
}

if (test.shardOfpub){
  var account = "0xf1e46fc70b30521cd7d45604762f9d927cd00032"
  console.log(soff.shardOfpub(account))
}

if (test.showObj){
  console.log(soff);
  console.log(sweb);
}

if (test.getinfo){
  sweb.nodeInfo(1)
  sweb.nodeInfo(2)
  sweb.nodeInfo(3)
  sweb.nodeInfo(4)
}

if (test.getBalance){
  var account = "0x6e21f6b5efb13424c26f701c7bf47a68981c3e41"
  // var account = "0x8b652a4e0c064e0830aa892e224077108fee6371"
  // var account = "0x03bcaf796fe8cffd90ddbe0baeb21ab83a3a43e1"
  var balance = (sweb.getBalance(account)/100000000).toFixed(8)
  console.log(`balance: ${balance}`);
}

if (test.sendtx) {
  var payload = "0x60fe47b10000000000000000000000000000000000000000000000000000000000000002"
  var from    = "0x6e21f6b5efb13424c26f701c7bf47a68981c3e41"
  var to      = "0xffea804fb3f6e5e9de238d81ccbcbf7cc3700002"
  var amount  = 0
  var dontsend= 0
  var result  = send(from, to, amount, payload, dontsend)
  console.log(result);
} 

if (test.compile){
  var fs = require("fs")
  let file 
  fs.readFile('./sampleContract/erc.sol', (err, data) => {
    if (err) {
      console.error(err)
      return
    }
    file = data
    console.log(data.toString());
  })
  console.log(file);
  var code = `
  pragma solidity ^0.4.24;

  contract SimpleStorage {
      uint storedData;

      function set(uint x) public {
          storedData = x;
      }

      function get() public view returns (uint) {
          return storedData;
      }
  }
  `
  var result  = soff.compile(code, 'SimpleStorage', '0.4.24')
  var payload = result.payload
  var abi     = result.abi
  console.log(result);
  console.log(JSON.stringify(result.abi));
}

if (test.getPayload){
  
  var ssemitset = {
    "address" : "0x94b5398f8a06d35fad964e15d5170b3eef0e0012",
    "abi"     : `[{"constant":false,"inputs":[{"name":"_x","type":"uint256"}],"name":"set","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"get","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"anonymous":false,"inputs":[{"indexed":false,"name":"x","type":"uint256"}],"name":"setTo","type":"event"}]`,
    "method"  : "set",
    "args"    : ["1"]
  }
  
  var ssemitget = {
    "address" : "0x94b5398f8a06d35fad964e15d5170b3eef0e0012",
    "abi"     : `[{"constant":false,"inputs":[{"name":"_x","type":"uint256"}],"name":"set","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"get","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"anonymous":false,"inputs":[{"indexed":false,"name":"x","type":"uint256"}],"name":"setTo","type":"event"}]`,
    "method"  : "get",
    "args"    : []
  }
  
  var ssset = {
    "address" : "0x18d97e9baa446ac33ae5575d2d2d5a3c592c0032",
    "abi"     : `[{"constant":false,"inputs":[{"name":"_x","type":"uint256"}],"name":"set","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"get","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"}]`,
    "method"  : "set",
    "args"    : ["1"]
  }
  
  var ssset = {
    "address" : "0x18d97e9baa446ac33ae5575d2d2d5a3c592c0032",
    "abi"     : `[{"constant":false,"inputs":[{"name":"_x","type":"uint256"}],"name":"set","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"get","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"}]`,
    "method"  : "get",
    "args"    : []
  }
  
  var eventerget = {
    "address" : "0x7d16e8921846c19cfb7a5dcde92d472d498a0002",
    "abi"     : `[ { "constant": false, "inputs": [ { "name": "_x", "type": "uint256" } ], "name": "set", "outputs": [], "payable": false, "stateMutability": "nonpayable", "type": "function" }, { "anonymous": false, "inputs": [ { "indexed": false, "name": "addr", "type": "address" }, { "indexed": false, "name": "message", "type": "string" } ], "name": "event0", "type": "event" }, { "anonymous": false, "inputs": [ { "indexed": false, "name": "x", "type": "uint256" } ], "name": "event1", "type": "event" }, { "constant": true, "inputs": [], "name": "get", "outputs": [ { "name": "", "type": "uint256" } ], "payable": false, "stateMutability": "view", "type": "function" } ]`,
    "method"  : "set",
    "args"    : ['1']
  }
  
  var xin = {
    "address" : "0x64ae863f7fdd2081e2dac40ef38a9a8f028d9ad1",
    "abi"     : `[{"constant":false,"inputs":[{"name":"_blkNum","type":"uint256"}],"name":"reverseBlock","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"getExitsLen","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_index","type":"uint256"}],"name":"getBalanceBackup","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getFeeBackup","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_blockNum","type":"uint256"}],"name":"getChildBlockSubmitter","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getCurDepositBlockNum","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getTotalBalance","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_operator","type":"address"},{"name":"_refundAccount","type":"address"}],"name":"addOperatorRequest","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":true,"inputs":[{"name":"_id","type":"uint192"}],"name":"getChallengeTarget","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_user","type":"address"},{"name":"_refundAccount","type":"address"}],"name":"userDepositRequest","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":true,"inputs":[{"name":"_index","type":"uint256"}],"name":"getChallengeId","outputs":[{"name":"","type":"uint192"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_user","type":"address"}],"name":"getUserBalance","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_index","type":"uint256"}],"name":"getStaticNodes","outputs":[{"name":"","type":"bytes32"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_account","type":"address"}],"name":"getDepositBlockNum","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getOpsLen","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_operator","type":"address"}],"name":"execOperatorExit","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"getDepositsLen","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_operator","type":"address"}],"name":"isOperatorExisted","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_challengeIndex","type":"uint256"},{"name":"_recentTxs","type":"bytes"},{"name":"_signatures","type":"bytes"},{"name":"_indices","type":"bytes"},{"name":"_preState","type":"bytes"},{"name":"_inclusionProofs","type":"bytes"}],"name":"responseToBlockChallenge","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"getCreatorDeposit","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_account","type":"address"}],"name":"getExitType","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getCurExitBlockNum","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_account","type":"address"}],"name":"removeExitRequest","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"getContractBalance","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getTotalFee","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getTotalDepositBackup","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_user","type":"address"},{"name":"_amount","type":"uint256"}],"name":"userExitRequest","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":false,"inputs":[{"name":"_account","type":"address"}],"name":"removeDepositRequest","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"_user","type":"address"}],"name":"isUserExisted","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getOwner","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_blkNum","type":"uint256"},{"name":"_balanceTreeRoot","type":"bytes32"},{"name":"_txTreeRoot","type":"bytes32"},{"name":"_accounts","type":"address[]"},{"name":"_updatedBalances","type":"uint256[]"},{"name":"_fee","type":"uint256"}],"name":"submitBlock","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":true,"inputs":[{"name":"_blockNum","type":"uint256"}],"name":"getChildBlockBalanceRootHash","outputs":[{"name":"","type":"bytes32"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getLastChildBlockNum","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_user","type":"address"}],"name":"execUserExit","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"getChallengeLen","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_account","type":"address"}],"name":"getDepositType","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getNextChildBlockNum","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_account","type":"address"}],"name":"getDepositAmount","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getTotalDeposit","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_blockNum","type":"uint256"}],"name":"getChildBlockTxRootHash","outputs":[{"name":"","type":"bytes32"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_account","type":"address"}],"name":"getExitBlockNum","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_operator","type":"address"},{"name":"_amount","type":"uint256"}],"name":"feeExit","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"_account","type":"address"}],"name":"getExitAmount","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_account","type":"address"}],"name":"getExitStatus","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_operator","type":"address"}],"name":"getOperatorFee","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_challengeTarget","type":"address"},{"name":"_inspecBlock","type":"bytes"},{"name":"_inspecBlockSignature","type":"bytes"},{"name":"_inspecTxHash","type":"bytes32"},{"name":"_inspecState","type":"bytes"},{"name":"_indices","type":"bytes"},{"name":"_inclusionProofs","type":"bytes"}],"name":"challengeSubmittedBlock","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":true,"inputs":[],"name":"getChildChainName","outputs":[{"name":"","type":"bytes32"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_operator","type":"address"}],"name":"operatorExitRequest","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":true,"inputs":[{"name":"_operator","type":"address"}],"name":"getOperatorBalance","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_index","type":"uint256"}],"name":"getAccountBackup","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"inputs":[{"name":"_subchainName","type":"bytes32"},{"name":"_genesisInfo","type":"bytes32[]"},{"name":"_staticNodes","type":"bytes32[]"},{"name":"_creatorDeposit","type":"uint256"},{"name":"_ops","type":"address[]"},{"name":"_opsDeposits","type":"uint256[]"},{"name":"_refundAccounts","type":"address[]"}],"payable":true,"stateMutability":"payable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":false,"name":"account","type":"address"},{"indexed":false,"name":"depositBlockNum","type":"uint256"},{"indexed":false,"name":"amount","type":"uint256"}],"name":"AddOperatorRequest","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"account","type":"address"},{"indexed":false,"name":"depositBlockNum","type":"uint256"},{"indexed":false,"name":"amount","type":"uint256"}],"name":"UserDepositRequest","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"account","type":"address"},{"indexed":false,"name":"exitBlockNum","type":"uint256"},{"indexed":false,"name":"amount","type":"uint256"}],"name":"OperatorExitRequest","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"account","type":"address"},{"indexed":false,"name":"exitBlockNum","type":"uint256"},{"indexed":false,"name":"amount","type":"uint256"}],"name":"UserExitRequest","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"blkNum","type":"uint256"},{"indexed":false,"name":"timestamp","type":"uint256"}],"name":"BlockSubmitted","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"blkNum","type":"uint256"}],"name":"BlockReversed","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"challengeTarget","type":"address"},{"indexed":false,"name":"blkNum","type":"uint256"}],"name":"BlockChallenge","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"challengeIndex","type":"uint256"}],"name":"RemoveBlockChallenge","type":"event"}]`,
    "method"  : "submitBlock",
    "args"    : ["1000", "0x4f2df4a21621b18c71619239c398657a23f198a40a8deff701e340e6e34d0823", "0x4f2df4a21621b18c71619239c398657a23f198a40a8deff701e340e6e34d0823", ["0x2E361D2057aEdeA19243489DE9fbC517b8fa2CE8", "0xca35b7d915458ef540ade6068dfe2f44e8fa733c", "0x627306090abab3a6e1400e9345bc60c78a8bef57"], ["100", "90", "105"], "1"],
  }
  
  var action = eventerget
  var result  = sweb.getPayload(action.abi, action.method, action.args, action.address)
  console.log(result);
}

if (test.call){
  var contractAddress = "0xffea804fb3f6e5e9de238d81ccbcbf7cc3700002"
  var payload         = "0x6d4ce63c"
  var result          = sweb.call(contractAddress, payload)
  console.log(result);
}

if (test.status){
  var hash    = "0x6f70695bf8a844b2dbbfbec1c69642a04d75356e3308b315ce72d4b633dd6533"
  var shard   = 1
  txStatusTX(hash, shard)
  txStatusRC(hash, shard)
}

function send(from, to, amount, payload, dontsend) {
  // var shard   = soff.shardOfpub(from)
  // console.log(sweb.nodeInfo(shard))
  var txInit  = soff.initTx(from, to, amount, payload)
  // console.log(txInit);
  var txFill  = sweb.fillTx(txInit)
  // console.log(txFill);
  var txDone  = soff.signTx(prikey, txFill)
  // console.log(txDone);
  if (dontsend) { return txDone }
  
  var result  = sweb.sendTx(txDone) 
  return { 
    "result": result,
    "hash": txDone.Hash
  }
}

function txStatusTX(hash, shard){
  var status = 'pool'
  var result = null
  while (status != 'block') {
    result = sweb.gettxbyhash(hash, shard)
    status = result.status 
    console.log(status);
  }
  console.log("Done!:", result);
}

function txStatusRC(hash, shard){
  var result = sweb.getrcbyhash(hash, shard)
  var status = result.failed.toString() 
  console.log("Done!:", result);
}
// if (test.)

/*
0x60fe47b10000000000000000000000000000000000000000000000000000000000000001
0xffea804fb3f6e5e9de238d81ccbcbf7cc3700002


curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"txpool_getReceiptByTxHash","params":["0x5ef85b3c359c2dddaa9c725b157cbf2baf4a9ec13ed21142617be589ac029108",""],"id":1}' 117.50.97.136:18037

curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"seele_estimateGas","params":[{"Data": {"From": "0x6e21f6b5efb13424c26f701c7bf47a68981c3e41","To": "0x6e21f6b5efb13424c26f701c7bf47a68981c3e41","Amount": 1, "AccountNonce": 276, "GasPrice": 1,"GasLimit": 1294687695,"Payload": ""}}],"id":1}' 117.50.97.136:18037





*/