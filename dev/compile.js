const { soff, sweb } = require('./../sdk/index')
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

// compiler('./contract/contracts/bin/PriorityQueue.sol' )
compiler('./contract/contracts/temp.sol' )

var path = './contract/contracts/'
