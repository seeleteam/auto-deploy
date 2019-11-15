pragma solidity ^0.4.24;

// external modules
import "./ByteUtils.sol";
import "./ECRecovery.sol";
import "./Merkle.sol";
import "./PriorityQueue.sol";
import "./RLP.sol";
import "./RLPEncoding.sol";
import "./SafeMath.sol";
import "./StemCore.sol";
import "./StemRelay.sol";
import "./StemChallenge.sol";
import "./StemCreation.sol";

/// @title Stem subchain contract in Seele root chain
/// @notice You can use this contract for a Stem subchain in Seele.
/// @author seeledev

contract SandboxStemRootchain {
    using RLP for bytes;
    using RLP for RLP.RLPItem;
    using SafeMath for uint256;
    using PriorityQueue for uint256[];
    using StemCore for bytes;
    using StemCore for StemCore.ChainStorage;

    StemCore.ChainStorage data;

    /** @dev Reverts if called by any account other than the owner. */
    modifier onlyOwner() {
        require(msg.sender == data.owner, "You're not the owner of the contract");
         _;
    }

    /** @dev Reverts if called by any account other than the operator. */
    modifier onlyOperator() {
        require(data.operators[msg.sender] > 0, "You're not the operator of the contract");
        _;
    }

    /** @dev Reverts if the message value does not equal to the desired value */
    modifier onlyWithValue(uint256 _value) {
        require(msg.value == _value, "Incorrect amount of input!");
        _;
    }

    /**
     * @dev The rootchain constructor creates the rootchain
     * contract and initialize the owner and operators.
     * @param _subchainName Is the name of the subchain
     * @param _genesisInfo [BalanceTreeRoot, TxTreeRoot]
     * @param _staticNodes Is the static nodes
     * @param _creatorDeposit Is the deposit of creator
     * @param _ops Is the operators.
     * @param _opsDeposits Is the deposits of operators.
     * @param _refundAccounts The operators' mainnet addresses
     */
    constructor(bytes32 _subchainName, bytes32[] _genesisInfo, bytes32[] _staticNodes, uint256 _creatorDeposit, address[] _ops, uint256[] _opsDeposits, address[] _refundAccounts)
    public payable {
        StemCreation.createSubchain(data, _subchainName, _genesisInfo, _staticNodes, _creatorDeposit, _ops, _opsDeposits, _refundAccounts, msg.sender, msg.value);
        // submit block[1000]
        address[] memory testAddresses0;
        uint256[] memory testBalances0;
        StemRelay.handleRelayBlock(data, 1000, 0x461e1a3a6e69fcf502f87941c8065bc0ef02c13160d151bfbec8797d91f6a1fb, 0xc810ba2f7f7d10159a42effd535fd92e3ebf65c913dfa13fcbf874b124677bbb, testAddresses0, testBalances0, 0, msg.sender);
        // submit block[2000]
        address[] memory testAddresses = new address[](2);
        testAddresses[0] = 0x627306090abaB3A6e1400e9345bC60c78a8BEf57;
        testAddresses[1] = 0x583031D1113aD414F02576BD6afaBfb302140225;
        uint256[] memory testBalances = new uint256[](2);
        testBalances[0] = 1234565890;
        testBalances[1] = 1234568890;
        StemRelay.handleRelayBlock(data, 2000, 0x0541f8a317ff1b9e13379d46f5d67062666b74eefad90431e9fe46b3ed7d723e, 0x0bb650a613bd81bb21db5a56b3a455c6b2e2c79cc2ad75c19f12f86c77e84fa4, testAddresses, testBalances, 250, msg.sender);
    }

   function createTestChallenge() public {
      address testAddress = 0x627306090abaB3A6e1400e9345bC60c78a8BEf57;
      bytes[] memory stateArray = new bytes[](3);
      stateArray[0] = RLPEncoding.encodeAddress(testAddress);
      stateArray[1] = RLPEncoding.encodeUint(uint256(1234565890));
      stateArray[2] = RLPEncoding.encodeUint(uint256(1));
      bytes memory encodedState = RLPEncoding.encodeList(stateArray);
      StemChallenge.createChildBlockChallenge(data, address(0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c), testAddress, bytes32(0x4cce1aa6276215c3cea7ff379de9b1d796398cf38490164422e3dcca3df50e45), encodedState);
   }

     /**
     * @dev Allows any operator to submit a child block.
     * @param _blkNum The block number of the submitted block
     * @param _balanceTreeRoot The root of the balance tree of the subchain.
     * @param _txTreeRoot The root of recent tx tree of the subchain.
     * @param _accounts The accounts to be updated
     * @param _updatedBalances The updated balance of the accounts
     * @param _fee The fee income of every operator during last period
     */
     function submitBlock(uint256 _blkNum, bytes32 _balanceTreeRoot, bytes32 _txTreeRoot, address[] _accounts, uint256[] _updatedBalances, uint256 _fee) public payable onlyWithValue(data.blockSubmissionBond) {//onlyOperator onlyWithValue(data.blockSubmissionBond) {
        StemRelay.handleRelayBlock(data, _blkNum, _balanceTreeRoot, _txTreeRoot, _accounts, _updatedBalances, _fee, msg.sender);
     }

    /**
     * @dev Reverse last submitted child block
     * @param _blkNum The child block to delete
     */
    function reverseBlock(uint256 _blkNum) public {
        StemRelay.doReverseBlock(data, _blkNum);
    }

    /**
    * @dev Accept a challenge to the submitted block.
    * @param _challengeTarget The target account to challenge
    * @param _inspecBlock The block header corresponding to the _inspecTxHash
    * @param _inspecBlockSignature The operator's signature in the block
    * @param _inspecTxHash The tx hash which the challenger asks the operator to include in the response
    * @param _inspecState The state of target account in _inspecBlock
    * @param _indices  0._inspecTxIndex The tx index in the merkle tree; 1._inspecStateIndex The state index in the merkle tree
    * @param _inclusionProofs 0. The proof showing _inspecTxHash is included in _inspecBlock; 1._stateInclusionProof The proof showing _inspecState is in _inspecBlock
    */
    function challengeSubmittedBlock(address _challengeTarget, bytes _inspecBlock, bytes _inspecBlockSignature, bytes32 _inspecTxHash, bytes _inspecState, bytes _indices, bytes _inclusionProofs)
    public payable onlyWithValue(data.blockChallengeBond) {
        bytes[] memory bytesArray = new bytes[](2);
        bytesArray[0] = RLPEncoding.encodeAddress(msg.sender);
        bytesArray[1] = RLPEncoding.encodeAddress(_challengeTarget);
        bytes memory encodedAddresses = RLPEncoding.encodeList(bytesArray);
        StemChallenge.processChallenge(data, encodedAddresses, _inspecBlock, _inspecBlockSignature, _inspecTxHash, _inspecState, _indices, _inclusionProofs);
    }

    /**
    * @dev Allows an operator to submit a proof in response to a block challenge.
    * @param _challengeIndex Is the index of the challenge
    * @param _recentTxs The transactions of target account during last interval
    * @param _signatures The signatures of the tx senders
    * @param _indices The leaf indices of the tx tree, preState tree and current state tree
    * @param _preState The state of target account at the beginning of last interval
    * @param _inclusionProofs Inclusion proofs of recentTxs, preState and current state
    */
    //function responseToBlockChallenge(uint _challengeIndex, bytes _recentTxs, bytes _signatures, uint256 _txLeafIndex, bytes _recentTxInclusionProof, bytes _preState, uint256 _preStateIndex, bytes _preStateInclusionProof, uint256 _stateIndex, bytes _stateInclusionProof) public onlyOperator {
    function responseToBlockChallenge(uint _challengeIndex, bytes _recentTxs, bytes _signatures, bytes _indices, bytes _preState, bytes _inclusionProofs) public {//onlyOperator {
        StemChallenge.handleResponseToChallenge(data, _challengeIndex, _recentTxs, _signatures, _indices, _preState, _inclusionProofs, msg.sender);
    }

    /**
     */
    function getChildChainName() public view returns(bytes32) {
       return data.subchainName;
    }

    function getOperatorBalance(address _operator) public view returns(uint256) {
       return data.operators[_operator];
    }

    function getOperatorFee(address _operator) public view returns(uint256) {
       return data.operatorFee[_operator];
    }

    function getUserBalance(address _user) public view returns(uint256) {
       return data.users[_user];
    }

    function isOperatorExisted(address _operator) public view returns(bool) {
        return data.isExistedOperators[_operator];
    }

    function isUserExisted(address _user) public view returns(bool) {
        return data.isExistedUsers[_user];
    }

    function getAccountBackup(uint _index) public view returns(address) {
       return data.accountsBackup[_index];
    }

    function getBalanceBackup(uint _index) public view returns(uint256) {
       return data.balancesBackup[_index];
    }

    function getFeeBackup() public view returns(uint256) {
       return data.feeBackup;
    }

    function getStaticNodes(uint _index) public view returns(bytes32) {
       return data.staticNodes[_index];
    }

    function getOpsLen() public view returns(uint256) {
       return data.operatorIndices.length;
    }

    function getCreatorDeposit() public view returns(uint256) {
       return data.creatorDeposit;
    }

    function getLastChildBlockNum() public view returns(uint256) {
       return data.lastChildBlockNum;
    }

    function getNextChildBlockNum() public view returns(uint256) {
       return data.nextChildBlockNum;
    }

    function getOwner() public view returns(address) {
       return data.owner;
    }

    function getChildBlockTxRootHash(uint256 _blockNum) public view returns(bytes32) {
       return data.childBlocks[_blockNum].txTreeRoot;
    }

    function getChildBlockBalanceRootHash(uint256 _blockNum) public view returns(bytes32) {
       return data.childBlocks[_blockNum].balanceTreeRoot;
    }

    function getChildBlockSubmitter(uint256 _blockNum) public view returns(address) {
       return data.childBlocks[_blockNum].submitter;
    }

    function getCurDepositBlockNum() public view returns(uint256) {
       return data.curDepositBlockNum;
    }

    function getCurExitBlockNum() public view returns(uint256) {
       return data.curExitBlockNum;
    }

    function getTotalDeposit() public view returns(uint256) {
       return data.totalDeposit;
    }

    function getTotalDepositBackup() public view returns(uint256) {
       return data.totalDepositBackup;
    }

    function getDepositsLen() public view returns(uint256) {
       return data.depositsIndices.length;
    }

    function getDepositBlockNum(address _account) public view returns(uint256) {
       return data.deposits[_account].blkNum;
    }

    function getDepositAmount(address _account) public view returns(uint256) {
       return data.deposits[_account].amount;
    }

    function getDepositType(address _account) public view returns(bool) {
       return data.deposits[_account].isOperator;
    }

    function getExitsLen() public view returns(uint256) {
       return data.exitsIndices.length;
    }

    function getExitBlockNum(address _account) public view returns(uint256) {
       return data.exits[_account].blkNum;
    }

    function getExitAmount(address _account) public view returns(uint256) {
       return data.exits[_account].amount;
    }

    function getExitType(address _account) public view returns(bool) {
       return data.exits[_account].isOperator;
    }

    function getExitStatus(address _account) public view returns(bool) {
       return data.exits[_account].executed;
    }

    function getTotalBalance() public view returns(uint256) {
        return StemRelay.totalBalance(data);
    }

    function getTotalFee() public view returns(uint256) {
        return StemRelay.totalFee(data);
    }

    function getContractBalance() public view returns(uint256) {
        return address(this).balance;
    }

    function getChallengeId(uint256 _index) public view returns(uint192) {
        return data.childBlockChallengeId[_index];
    }

    function getChallengeTarget(uint192 _id) public view returns(address) {
        return data.childBlockChallenges[_id].challengeTarget;
    }

    function getChallengeLen() public view returns(uint256) {
        return data.childBlockChallengeId.length;
    }
}