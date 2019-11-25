const Web3 = require('web3')
var web3 = new Web3()
//obj is [] json 
var obj = []
var SimpleStorageContract = new web3.eth.Contract(obj)
console.log(SimpleStorageContract.methods.set(['0x64ae863f7fdd2081e2dac40ef38a9a8f028d9ad1', '0x64ae863f7fdd2081e2dac40ef38a9a8f028d9ad1']).encodeABI());


