pragma solidity ^0.4.24;

// external modules
import "./SafeMath.sol";
import "./RLPEncoding.sol";
import "./StemCore.sol";
import "./StemRelay.sol";
import "./StemChallenge.sol";
import "./StemCreation.sol";

/// @title Stem subchain contract in Seele root chain
/// @notice You can use this contract to manage a Seele Stem subchain
/// @author seeledev

contract StemRootchain {
    using SafeMath for uint256;
    using StemCore for bytes;
    using StemCore for StemCore.ChainStorage;

    StemCore.ChainStorage private data;

    /** events */
     event AddOperatorRequest(address account, uint256 depositBlockNum, uint256 amount);
     event UserDepositRequest(address account, uint256 depositBlockNum, uint256 amount);
     event OperatorExitRequest(address account, uint256 exitBlockNum, uint256 amount);
     event UserExitRequest(address account, uint256 exitBlockNum, uint256 amount);
     event BlockSubmitted(uint256 blkNum, uint256 timestamp);
     event BlockReversed(uint256 blkNum);
     event BlockChallenge(address challengeTarget, uint256 blkNum);
     event RemoveBlockChallenge(uint challengeIndex);

    /** @dev Reverts if called by any account other than the owner. */
    modifier onlyOwner() {
        require(msg.sender == data.owner, "You're not the owner of the contract!");
         _;
    }

    /** @dev Reverts if called by any account other than the operator. */
    modifier onlyOperator() {
        require(data.operators[msg.sender] > 0, "You're not the operator of the contract!");
        _;
    }

    /** @dev Reverts if the message value does not equal to the desired value */
    modifier onlyWithValue(uint256 _value) {
        require(msg.value == _value, "Incorrect amount of input!");
        _;
    }

    /**
     * @dev The rootchain constructor creates the rootchain
     * contract, initializing the owner and operators.
     * @param _subchainName The name of the subchain
     * @param _genesisInfo [_genesisBalanceTreeRoot, _genesisTxTreeRoot]
     *        The hash of the genesis balance tree root
     *        The hash of the genesis tx tree root
     * @param _staticNodes The static nodes
     * @param _creatorDeposit The deposit of creator
     * @param _ops The operators.
     * @param _opsDeposits The deposits of operators.
     * @param _refundAccounts The operators' mainnet addresses
     */
    constructor(bytes32 _subchainName, bytes32[] _genesisInfo, bytes32[] _staticNodes, uint256 _creatorDeposit, address[] _ops, uint256[] _opsDeposits, address[] _refundAccounts)
    public payable {
        StemCreation.createSubchain(data, _subchainName, _genesisInfo, _staticNodes, _creatorDeposit, _ops, _opsDeposits, _refundAccounts, msg.sender, msg.value);
    }

    /**
    * @dev Create a request to add new operator to the subchain
    * @param _operator The operator to be added
    * @param _refundAccount The account where the fund will be returned
    */
    function addOperatorRequest(address _operator, address _refundAccount) public payable {
        data.createAddOperatorRequest(_operator, _refundAccount, msg.sender, msg.value);
    }

    /**
    * @dev Allow user deposit to the subchain
    * @param _user The user account to deposit value
    * @param _refundAccount The account where the fund will be returned
    */
    function userDepositRequest(address _user, address _refundAccount) public payable {
        data.createUserDepositRequest(_user, _refundAccount, msg.sender, msg.value);
    }

    /**
    * @dev Remove inactive deposit request
    * @param _account The associated account of the deposit to be removed
    */
    function removeDepositRequest(address _account) public {
        require(data.deposits[_account].amount > 0, "This deposit does not exist");
        require(data.deposits[_account].blkNum < data.lastChildBlockNum, "This deposit is still active");
        require(data.isLastChildBlockConfirmed(), "Last block is not confirmed yet");
        data.deleteDepositsIndicesByAccount(_account);
        delete data.deposits[_account];
    }

    /**
    * @dev Create a request for operator exit
    * @param _operator The operator account to exit from
    */
    function operatorExitRequest(address _operator) public payable onlyWithValue(data.operatorExitBond) {
        data.createOperatorExitRequest(_operator);
    }

    /**
    * @dev Execute operator exit request
    * @param _operator The operator account to exit from
    */
    function execOperatorExit(address _operator) public {
        data.executeOperatorExit(_operator);
    }
    /**
    * @dev Create a request for user exit
    * @param _user The user account to exit from
    * @param _amount Amount of fund to exit
    */
    function userExitRequest(address _user, uint256 _amount) public payable onlyWithValue(data.userExitBond) {
        data.createUserExitRequest(_user, _amount);
    }

    function execUserExit(address _user) public {
        data.executeUserExit(_user);
    }

    /**
    * @dev Remove inactive exit request
    * @param _account The account to exit from
    */
    function removeExitRequest(address _account) public {
        require(data.exits[_account].amount > 0, "This exit does not exist");
        require(data.exits[_account].blkNum < data.lastChildBlockNum, "This exit is still active");
        require(data.isLastChildBlockConfirmed(), "Last block is not confirmed yet");
        data.deleteExitsIndicesByAccount(_account);
        delete data.exits[_account];
    }

    /**
    * @dev Withdraw fee from an operator fee account
    * @param _operator The operator account to withdraw fee from
    * @param _amount The amount of fee to withdraw
    */
    function feeExit(address _operator, uint256 _amount) public {
        //require(msg.sender == _operator, "Exit requests should be sent from the operator");
        require(data.isLastChildBlockConfirmed(), "Last block is not confirmed yet");
        require(data.operatorFee[_operator] >= _amount, "Invalid exit amount");
        data.refundAddress[_operator].transfer(_amount);
        data.operatorFee[_operator] = data.operatorFee[_operator].sub(_amount);
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
    /**
    * @dev Get child block's hash
    * @param _blockNum Is the submitted block number
    */
    /*function getChildBlockTimestamp(uint256 _blockNum) public view returns(uint256) {
       return childBlocks[_blockNum].timestamp;
    }*/
}