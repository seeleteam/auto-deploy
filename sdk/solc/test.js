var solc = require('solc');
var solc = solc.setupMethods(require("./0.4.24"))


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
var input = {language: 'Solidity',sources: {'test.sol': {content: code}},settings: {outputSelection: {'*': {'*': ['*']}}}}
var output = JSON.parse(solc.compile(JSON.stringify(input)))
var contractName = 'SimpleStorage'
var abi = output.contracts['test.sol'][contractName].abi
var version = JSON.parse(output.contracts['test.sol'][contractName].metadata).compiler.version
var payload = "0x"+output.contracts['test.sol'][contractName].evm.bytecode.object;
console.log(payload)
console.log(abi);
console.log(version);
