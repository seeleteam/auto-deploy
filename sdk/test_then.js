const { soff, sweb } = require('./index')
const fs = require('fs')
const util = require('util')

const readfile = util.promisify(fs.readFile)
var test = {}
test.compile = 0
//__________________________ path > contract abi, 

if (test.compile){
  var path = './contract/ss.sol' 
  readfile(path)
    .then(code =>{
      // compile
      // console.log(data.toString())
      return new Promise((resolve, reject)=>{
        soff.compilepromise(code.toString(), '0.4.24')
          .then(output => {
            // console.log(output);
            resolve(output)
          })
          .catch(err => {
            reject(err)
          });
      })
    })
    .then(output =>{
      // parse the contracts, abis, and bytecode
      for ( contractName in output.contracts['test.sol']){
        var abstract = {
          "payload": "0x"+output.contracts['test.sol'][contractName].evm.bytecode.object,
          "abi": JSON.stringify(output.contracts['test.sol'][contractName].abi),
          "version": JSON.parse(output.contracts['test.sol'][contractName].metadata).compiler.version
        }
        console.log(abstract);
      }
      // console.log(output.contracts['test.sol']);
    })
    .catch(err => console.error(err));
}  

function compiler (path) {
  readfile(path)
    .then(code =>{
      // compile
      // console.log(data.toString())
      return new Promise((resolve, reject)=>{
        soff.compilepromise(code.toString(), '0.4.24')
          .then(output => {
            // console.log(output);
            resolve(output)
          })
          .catch(err => {
            reject({"path" : path , "error": err})
          });
      })
    })
    .then(output =>{
      // parse the contracts, abis, and bytecode
      for ( contractName in output.contracts['test.sol']){
        var abstract = {
          "file"    : path,
          "payload" : "0x"+output.contracts['test.sol'][contractName].evm.bytecode.object,
          "abi"     : JSON.stringify(output.contracts['test.sol'][contractName].abi),
          "version" : JSON.parse(output.contracts['test.sol'][contractName].metadata).compiler.version
        }
        console.log(abstract);
      }
      // console.log(output.contracts['test.sol']);
    })
    .catch(err => console.error(err));
}
// compiler('./contract/contracts/PriorityQueue.sol' )
compiler('./contract/contracts/temp.sol' )
// compiler('./contract/contracts/SafeMath.sol' )
var path = './contract/contracts/'
// fs.readdir(path, function(err, items) {
//     console.log(items);
//     for (var i=0; i<items.length; i++) {
//         var file = path + items[i]
//         // console.log(path + items[i]);
// 
//         // compiler(file)
//     }
// });


var ssemitabi = `[{"constant":false,"inputs":[{"name":"_x","type":"uint256"}],"name":"set","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"get","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"anonymous":false,"inputs":[{"indexed":false,"name":"x","type":"uint256"}],"name":"setTo","type":"event"}]`
var ssabi     = `[{"constant":false,"inputs":[{"name":"_x","type":"uint256"}],"name":"set","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"get","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"}]'`


var contractAddress = "0x94b5398f8a06d35fad964e15d5170b3eef0e0012"
// var contractAddress = "0xf1e46fc70b30521cd7d45604762f9d927cd00032"
// 0x18d97e9baa446ac33ae5575d2d2d5a3c592c0032
/*








*/