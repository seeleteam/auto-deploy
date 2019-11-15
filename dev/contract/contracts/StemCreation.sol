pragma solidity ^0.4.24;

// external modules
import "./SafeMath.sol";
import "./StemCore.sol";

// This library includes the construtor of a Stem contract
library StemCreation {
    using SafeMath for uint256;

     /**
     * @dev The rootchain constructor creates the rootchain
     * contract, initializing the owner and operators
     * @param _subchainName The name of the subchain
     * @param _genesisInfo [balanceTreeRoot, TxTreeRoot]
     *        The hash of the genesis balance tree root
     *        The hash of the genesis tx tree root
     * @param _staticNodes The static nodes
     * @param _creatorDeposit The deposit of creator
     * @param _ops The operators.
     * @param _opsDeposits The deposits of operators.
     * @param _refundAccounts The mainnet addresses of the operators
     */
    function createSubchain(StemCore.ChainStorage storage self, bytes32 _subchainName, bytes32[] _genesisInfo, bytes32[] _staticNodes, uint256 _creatorDeposit, address[] _ops, uint256[] _opsDeposits, address[]  _refundAccounts, address _msgSender, uint256 _msgValue) public {
        // initialize the storage variables
        init(self);
        require(_ops.length >= self.MIN_LENGTH_OPERATOR && _ops.length <= self.MAX_LENGTH_OPERATOR, "Invalid operators length");
        require(_ops.length == _opsDeposits.length, "Invalid deposits length");
        require(_ops.length == _refundAccounts.length, "Invalid length of refund accounts");
        require(_creatorDeposit >= self.creatorMinDeposit, "Insufficient creator deposit value");

        // Setup the operators' deposits and initial fees
        self.totalDeposit = _creatorDeposit;
        for (uint256 i = 0; i < _ops.length && StemCore.isValidAddOperator(self, _ops[i], _opsDeposits[i]); i++){
            require(self.isExistedOperators[_ops[i]] == false, "Repeated operator");
            self.operators[_ops[i]] = _opsDeposits[i];
            self.operatorFee[_ops[i]] = 0;
            self.totalDeposit = self.totalDeposit.add(_opsDeposits[i]);
            self.isExistedOperators[_ops[i]] = true;
            self.operatorIndices.push(_ops[i]);
            self.refundAddress[_ops[i]] = _refundAccounts[i];
        }
        require(_msgValue >= self.totalDeposit, "You don't give me enough money");
        self.owner = _msgSender;
        self.creatorDeposit = _creatorDeposit;

        // Register subchain info
        self.subchainName = _subchainName;
        self.staticNodes = _staticNodes;
        uint256 submittedBlockNumber = 0;
        //Create the genesis block.
        self.childBlocks[submittedBlockNumber] = StemCore.ChildBlock({
            submitter: _msgSender,
            balanceTreeRoot: _genesisInfo[0],
            txTreeRoot: _genesisInfo[1],
            timestamp: block.timestamp
        });

        // update child block number/deposit block number/exit block number
        self.nextChildBlockNum = 0;
        self.nextChildBlockNum = self.nextChildBlockNum.add(self.CHILD_BLOCK_INTERVAL);
        self.nextDepositBlockIncrement = 1;
        self.curDepositBlockNum = self.nextChildBlockNum.add(self.nextDepositBlockIncrement);
        self.nextExitBlockIncrement = 1;
        self.curExitBlockNum = self.nextChildBlockNum.add(self.nextExitBlockIncrement);
        // By default, all the initial operators' deposit should be processed on the subchain at genesis block. (The genesis block height is 0)
    }

     /**
    * @dev Initialize the contract parameters
     */
    function init(StemCore.ChainStorage storage self) internal {
        self.MIN_LENGTH_OPERATOR = 1;
        self.MAX_LENGTH_OPERATOR = 100;
        self.CHILD_BLOCK_INTERVAL = 1000;
        self.IS_NEW_OPERATOR_ALLOWED = true;
        self.creatorMinDeposit = 1;
        self.childBlockChallengePeriod = 1 hours;//1 days;
        self.childBlockChallengeSubmissionPeriod = 2 hours;//12 hours;
        self.isBlockSubmissionBondReleased = true;
        self.blockSubmissionBond = 1;
        self.blockChallengeBond = 1;
        self.operatorMinDeposit = 3;
        self.operatorExitBond = 1;
        self.userMinDeposit = 2;
        self.userExitBond = 1;
    }
}