pragma solidity ^0.4.24;

// external modules
import "./SafeMath.sol";

library StemCore {
    using SafeMath for uint256;

    struct ChildBlock{
        address submitter;
        bytes32 balanceTreeRoot;
        bytes32 txTreeRoot;
        uint256 timestamp;
    }

    struct ChildBlockChallenge{
        address challengerAddress;
        address challengeTarget;
        bytes32 inspecTxHash;
        bytes inspecState;
    }

    struct Deposit{
        uint256 amount;
        uint256 blkNum;
        bool    isOperator;
        address refundAccount;
    }

    struct Exit{
        uint256 amount;
        uint256 blkNum;
        bool    isOperator;
        bool    executed;
    }

     struct InspecBlock {
        address creator;
        bytes32 txTreeRoot;
        bytes32 balanceTreeRoot;
    }

    struct ChainStorage {
        uint8   MIN_LENGTH_OPERATOR;
        uint8   MAX_LENGTH_OPERATOR;
        uint256 CHILD_BLOCK_INTERVAL;
        bool    IS_NEW_OPERATOR_ALLOWED;

        /** @dev subchain info */
        address   owner;
        bytes32   subchainName;
        bytes32[] staticNodes;
        uint256   totalDeposit;
        uint256   creatorDeposit;
        uint256   creatorMinDeposit;

        /** @dev subchain related */
        uint256 curDepositBlockNum;
        uint256 nextDepositBlockIncrement;
        uint256 curExitBlockNum;
        uint256 nextExitBlockIncrement;
        uint256 nextChildBlockNum;
        uint256 lastChildBlockNum;
        mapping(uint256 => ChildBlock) childBlocks;
        uint256 childBlockChallengePeriod;
        uint256 childBlockChallengeSubmissionPeriod;
        bool    isBlockSubmissionBondReleased;
        uint256 blockSubmissionBond;
        uint256 blockChallengeBond;
        uint192[] childBlockChallengeId;
        mapping(uint192 => ChildBlockChallenge) childBlockChallenges;

        /** @dev Operator related */
        address[] operatorIndices;
        mapping(address => uint256) operators;
        mapping(address => uint256) operatorFee;
        mapping(address => bool)    isExistedOperators;
        uint256 operatorMinDeposit;
        uint256 operatorExitBond;

        /** @dev User related */
        address[] userIndices;
        mapping(address => uint256) users;
        mapping(address => bool)    isExistedUsers;
        uint256 userMinDeposit;
        uint256 userExitBond;

        /** @dev deposit and exit related */
        mapping(address => address) refundAddress;
        mapping(address => Deposit) deposits;
        address[] depositsIndices;
        mapping(address => Exit) exits;
        address[] exitsIndices;

        /** @dev backup params */
        uint256   feeBackup;
        uint256   totalDepositBackup;
        address[] accountsBackup;
        uint256[] balancesBackup;

    }

    event AddOperatorRequest(address account, uint256 depositBlockNum, uint256 amount);
    event UserDepositRequest(address account, uint256 depositBlockNum, uint256 amount);
    event OperatorExitRequest(address account, uint256 exitBlockNum, uint256 amount);
    event UserExitRequest(address account, uint256 exitBlockNum, uint256 amount);

    /**
    * @dev  create an AddOperator request
    * @param _operator      Operator address
    * @param _refundAccount The account to get the fund back
    * @param _msgSender     msg.sender
    * @param _msgValue      msg.value
    */
    function createAddOperatorRequest(ChainStorage storage self, address _operator, address _refundAccount, address _msgSender, uint256 _msgValue) public {
        require(_msgSender == _refundAccount || _msgSender == self.owner, "Requests should be sent by the operator or the creator");
        require(self.IS_NEW_OPERATOR_ALLOWED, "Adding new operator is not allowed");
        require(self.isExistedOperators[_operator] == false, "Repeated operator");
        require(self.isExistedUsers[_operator] == false, "This address has been registered as a user");
        require(self.deposits[_operator].amount == 0, "Another request exists for this address");
        require(isValidAddOperator(self, _operator, _msgValue), "Unable to add this operator");
        require(self.operatorIndices.length < self.MAX_LENGTH_OPERATOR, "Reach the maximum number of operators");
        require(existUnresolvedRequest(self, _operator) == false, "Another unresolved request exists for this address");

        self.curDepositBlockNum = processDepositBlockNum(self);
        self.depositsIndices.push(_operator);
        self.deposits[_operator] = Deposit({
            amount: _msgValue,
            blkNum: self.curDepositBlockNum,
            isOperator: true,
            refundAccount: _refundAccount
        });

        emit AddOperatorRequest(
            _operator,
            self.curDepositBlockNum,
            _msgValue
        );
    }

     /**
    * @dev  create an userDeposit request
    * @param _user      user address
    * @param _refundAccount The account to get the fund back
    * @param _msgSender     msg.sender
    * @param _msgValue      msg.value
    */
    function createUserDepositRequest(ChainStorage storage self, address _user, address _refundAccount, address _msgSender, uint256 _msgValue) public {
        require(_msgSender == _refundAccount || _msgSender == self.owner, "Requests should be sent by the user or the creator");
        require(self.isExistedOperators[_user] == false, "This address has been registered as an operator");
        require(self.deposits[_user].amount == 0 || (self.deposits[_user].amount > 0 && self.deposits[_user].isOperator == false), "An addOperator request exists for this address");
        require(isValidUserDeposit(self, _user, _msgValue), "Unable to deposit for this user");
        require(existUnresolvedRequest(self, _user) == false, "Another unresolved request exists for this user");

        // merge this request with existing deposit/exit requests that have the same execution period
        uint256 depositAmount = _msgValue;
        if (self.deposits[_user].blkNum > self.nextChildBlockNum) {
            // merge current deposit request with a previous deposit request
            self.deposits[_user].amount = self.deposits[_user].amount.add(_msgValue);
            emit UserDepositRequest(
                _user,
                self.deposits[_user].blkNum,
                self.deposits[_user].amount
            );
            return;
        } else if (self.exits[_user].blkNum > self.nextChildBlockNum) {
            // merge current deposit request with a previous exit request
            if (self.exits[_user].amount < depositAmount) {
                depositAmount = depositAmount.sub(self.exits[_user].amount);
                self.refundAddress[_user].transfer(self.exits[_user].amount.add(self.userExitBond));
                delete self.exits[_user];
            } else if (self.exits[_user].amount > depositAmount) {
                self.exits[_user].amount = self.exits[_user].amount.sub(depositAmount);
                self.refundAddress[_user].transfer(depositAmount);
                emit UserExitRequest(
                    _user,
                    self.exits[_user].blkNum,
                    self.exits[_user].amount
                );
                return;
            } else {
                // exit request and deposit request cancel out each other
                self.refundAddress[_user].transfer(depositAmount.add(self.userExitBond));
                delete self.exits[_user];
                emit UserExitRequest(
                    _user,
                    self.exits[_user].blkNum,
                    uint256(0)
                );
                return;
            }
        }

        // create new deposit
        self.curDepositBlockNum = processDepositBlockNum(self);
        self.depositsIndices.push(_user);
        self.deposits[_user] = Deposit({
                amount: depositAmount,
                blkNum: self.curDepositBlockNum,
                isOperator: false,
                refundAccount: _refundAccount
            });

        emit UserDepositRequest(
            _user,
            self.curDepositBlockNum,
            depositAmount
        );
    }

     /**
     * @dev Verify that the operator is valid and that the deposit is sufficient
     * @param _operator The operator of the subchain
     * @param _deposit The deposit of the operator.
     * @return true if the operator is valid
     */
    function isValidAddOperator(ChainStorage storage self, address _operator, uint256 _deposit) public view returns(bool){
        require(_operator != address(0), "Invalid address");
        require(_deposit >= self.operatorMinDeposit, "Insufficient deposit amount");

        return true;
    }

    /**
    * @dev Verify that the user is valid and that the deposit is sufficient
    * @param _user The user of the subchain
    * @param _deposit The deposit of the user.
    * @return true if the user is valid
    */
    function isValidUserDeposit(ChainStorage storage self, address _user, uint256 _deposit) public view returns(bool){
        require(_user != address(0), "Invalid user address");
        require(_deposit >= self.userMinDeposit, "Insufficient user deposit value");

        return true;
    }

    /**
    * @dev Process next deposit block number
    * @return next deposit block number
    */
    function processDepositBlockNum(ChainStorage storage self) internal returns(uint256) {
        // Only allow a limited number of deposits per child block. 1 <= nextDepositBlockIncrement < CHILD_BLOCK_INTERVAL.
        require(self.nextDepositBlockIncrement < self.CHILD_BLOCK_INTERVAL);
        require(self.curDepositBlockNum < self.nextChildBlockNum.add(self.CHILD_BLOCK_INTERVAL));

        // get next deposit block number.
        uint256 blknum = getDepositBlockNumber(self);
        self.nextDepositBlockIncrement++;

        return blknum;
    }

    /**
    * @dev Calculates the next deposit block.
    * @return Next deposit block number.
    */
    function getDepositBlockNumber(ChainStorage storage self) public view returns (uint256)
    {
        return self.nextChildBlockNum.add(self.nextDepositBlockIncrement);
    }

    /**
    * @dev Delete deposit index by account
    * @param _account The account to deposit
     */
    function deleteDepositsIndicesByAccount(ChainStorage storage self, address _account) internal {
        for (uint i = 0; i < self.depositsIndices.length; i++) {
            if (_account == self.depositsIndices[i]) {
                self.depositsIndices[i] = self.depositsIndices[self.depositsIndices.length - 1];
                delete self.depositsIndices[self.depositsIndices.length - 1];
                self.depositsIndices.length--;
            }
        }
    }

    /**
     * @dev Process deposits and exits executed during last period
     */
    function executeDepositsAndExits(ChainStorage storage self) internal {
        address account;
        // execute exits
        for (uint j = 0; j < self.exitsIndices.length; j++) {
            account = self.exitsIndices[j];
            if (self.exits[account].isOperator) {
                executeOperatorExit(self, account);
            } else {
                executeUserExit(self, account);
            }
        }

        // backup after the execution of exits
        self.totalDepositBackup = self.totalDeposit;
        for (j = 0; j < self.depositsIndices.length; j++) {
            account = self.depositsIndices[j];
            if (self.deposits[account].blkNum > self.lastChildBlockNum && self.deposits[account].blkNum < self.nextChildBlockNum) {
                if (self.deposits[account].isOperator) {
                    self.operatorFee[account] = 0;
                    self.isExistedOperators[account] = true;
                    self.operatorIndices.push(account);
                } else {
                    if (self.isExistedUsers[account] == false) {
                        self.isExistedUsers[account] = true;
                        self.userIndices.push(account);
                    }
                }
                self.totalDeposit = self.totalDeposit.add(self.deposits[account].amount);
            }
        }
    }

    /**
    * @dev Create an operator exit request. It's a complete exit.
    * @param _operator The operator account
     */
    function createOperatorExitRequest(ChainStorage storage self, address _operator) public {
        //require(_msgSender == _operator, "Exit requests should be sent by the operator");
        require(self.isExistedOperators[_operator] || self.deposits[_operator].blkNum > self.nextChildBlockNum, "This operator does not exist and does not has any deposit request");
        require(existUnresolvedRequest(self, _operator) == false, "Another unresolved request exists for this operator");
        if (self.isExistedOperators[_operator]) {
            if (isLastChildBlockConfirmed(self)) {
                // last block is confirmed
                require(self.operators[_operator] >= self.operatorMinDeposit, "Invalid deposit amount");
            } else {
                uint index = self.accountsBackup.length;
                for (uint i = 0; i < self.accountsBackup.length; i++) {
                    if (self.accountsBackup[i] == _operator) {
                        index = i;
                        break;
                    }
                }
                require(self.operators[_operator] >= self.operatorMinDeposit || (index < self.accountsBackup.length && self.balancesBackup[index] >= self.operatorMinDeposit) , "Invalid deposit amount");
            }
        }

        // merge with existing deposit or exit requests
        if (self.exits[_operator].blkNum > self.nextChildBlockNum) {
            // an operator exit already exists
            self.refundAddress[_operator].transfer(self.operatorExitBond);
            return;
        } else if (self.deposits[_operator].blkNum > self.nextChildBlockNum) {
            // exit request and deposit request cancel out each other
            // TODO: emit an event to cancel deposit request
            self.refundAddress[_operator].transfer(self.deposits[_operator].amount.add(self.operatorExitBond));
            deleteDepositsIndicesByAccount(self, _operator);
            delete self.deposits[_operator];
            emit AddOperatorRequest(
                _operator,
                self.deposits[_operator].blkNum,
                uint256(0)
            );
            return;
        }

        self.curExitBlockNum = processExitBlockNum(self);
        self.exitsIndices.push(_operator);
        self.exits[_operator] = Exit({
                amount: self.operators[_operator],
                blkNum: self.curExitBlockNum,
                isOperator: true,
                executed: false
            });

        emit OperatorExitRequest(
            _operator,
            self.curExitBlockNum,
            self.operators[_operator]
        );
    }

    /**
    * @dev Create a user exit request
    * @param _user User account
    * @param _amount Exit amount
     */
    function createUserExitRequest(ChainStorage storage self, address _user, uint256 _amount) public {
        //require(_msgSender == _user, "Exit requests should be sent by the user");
        require(self.isExistedUsers[_user] || self.deposits[_user].blkNum > self.nextChildBlockNum, "This user does not exist and does not has any deposit request");
        require(existUnresolvedRequest(self, _user) == false, "Another unresolved request exists for this user");

        // merge existing deposit or exit requests
        uint256 exitAmount = _amount;
        if (self.exits[_user].blkNum > self.nextChildBlockNum) {
            // merge current exit request with a previous exit request
            self.exits[_user].amount = self.exits[_user].amount.add(exitAmount);
            self.refundAddress[_user].transfer(self.userExitBond);
            emit UserExitRequest(
                _user,
                self.exits[_user].blkNum,
                self.exits[_user].amount
            );
            return;
        } else if (self.deposits[_user].blkNum > self.nextChildBlockNum) {
            // merge current exit request with a previous deposit request
            if (self.deposits[_user].amount < exitAmount) {
                exitAmount = exitAmount.sub(self.deposits[_user].amount);
                self.refundAddress[_user].transfer(self.deposits[_user].amount);
                deleteDepositsIndicesByAccount(self, _user);
                delete self.deposits[_user];
            } else if (self.deposits[_user].amount > exitAmount) {
                self.deposits[_user].amount = self.deposits[_user].amount.sub(exitAmount);
                self.refundAddress[_user].transfer(exitAmount.add(self.userExitBond));
                emit UserDepositRequest(
                    _user,
                    self.deposits[_user].blkNum,
                    self.deposits[_user].amount
                );
                return;
            } else {
                // exit request and deposit request cancel out each other
                // TODO: emit an event to cancel deposit request
                self.refundAddress[_user].transfer(exitAmount.add(self.userExitBond));
                deleteDepositsIndicesByAccount(self, _user);
                delete self.deposits[_user];
                 emit UserDepositRequest(
                    _user,
                    self.deposits[_user].blkNum,
                    uint256(0)
                );
                return;
            }
        }

        require(self.isExistedUsers[_user], "This user does not exist");
        if (isLastChildBlockConfirmed(self)) {
            // last block is confirmed
            require(self.users[_user] >= exitAmount, "Invalid exit amount");
        } else {
            uint index = self.accountsBackup.length;
            for (uint i = 0; i < self.accountsBackup.length; i++) {
                if (self.accountsBackup[i] == _user) {
                    index = i;
                    break;
                }
            }
            require(self.users[_user] >= exitAmount || (index < self.accountsBackup.length && self.balancesBackup[index] >= exitAmount), "Invalid exit amount");
        }

        self.curExitBlockNum = processExitBlockNum(self);
        self.exitsIndices.push(_user);
        self.exits[_user] = Exit({
                amount: exitAmount,
                blkNum: self.curExitBlockNum,
                isOperator: false,
                executed: false
            });

        emit UserExitRequest(
            _user,
            self.curExitBlockNum,
            exitAmount
        );
    }

      /**
    * @dev process next exit block number
    * @return next exit block number
    */
    function processExitBlockNum(ChainStorage storage self) internal returns(uint256) {
        // Only allow a limited number of exits per child block. 1 <= nextExitBlockIncrement < CHILD_BLOCK_INTERVAL.
        require(self.nextExitBlockIncrement < self.CHILD_BLOCK_INTERVAL, "Too many exit blocks");
        require(self.curExitBlockNum < self.nextChildBlockNum.add(self.CHILD_BLOCK_INTERVAL), "Currrent exit block number cannot be too far in the future");

        // get next deposit block number.
        uint256 blknum = getExitBlockNumber(self);
        self.nextExitBlockIncrement++;

        return blknum;
    }

    /**
    * @dev Calculates the next exit block.
    * @return Next exit block number.
    */
    function getExitBlockNumber(ChainStorage storage self) public view returns (uint256)
    {
        return self.nextChildBlockNum.add(self.nextExitBlockIncrement);
    }

    /**
    * @dev Execute operator exit
    * @param _operator The operator account to exit from
    */
    function executeOperatorExit(ChainStorage storage self, address _operator) public {
        if (self.exits[_operator].amount <= 0) {return;}
        // make sure the exit is in execution period
        if (self.exits[_operator].blkNum <= self.lastChildBlockNum || self.exits[_operator].blkNum >= self.nextChildBlockNum) {return;}
        if (!isLastChildBlockConfirmed(self)) {return;}
        if (self.exits[_operator].executed == true) {return;}
        if (self.operators[_operator] < self.operatorMinDeposit) {
            deleteExitsIndicesByAccount(self, _operator);
            delete self.exits[_operator];
        } else {
            self.refundAddress[_operator].transfer(self.operatorFee[_operator].add(self.operators[_operator].add(self.operatorExitBond)));
            delete self.operators[_operator];
            delete self.operatorFee[_operator];
            self.isExistedOperators[_operator] = false;
            deleteOperatorIndicesByAccount(self, _operator);
            self.totalDeposit = self.totalDeposit.sub(self.operators[_operator].add(self.operatorFee[_operator]));
            self.exits[_operator].executed = true;
        }
    }

    /**
    * @dev Delete operator index by the account
    * @param _operator The operator account
     */
    function deleteOperatorIndicesByAccount(ChainStorage storage self, address _operator) internal {
        for (uint i = 0; i < self.operatorIndices.length; i++) {
            if (_operator == self.operatorIndices[i]) {
                self.operatorIndices[i] = self.operatorIndices[self.operatorIndices.length - 1];
                delete self.operatorIndices[self.operatorIndices.length - 1];
                self.operatorIndices.length--;
            }
        }
    }

    /**
    * @dev Execute user exit
    * @param _user The user account to exit from
    */
    function executeUserExit(ChainStorage storage self, address _user) public {
        if(self.exits[_user].amount <= 0) {return;}
        // make sure the exit is in execution period
        if (self.exits[_user].blkNum <= self.lastChildBlockNum || self.exits[_user].blkNum >= self.nextChildBlockNum) {return;}
        if (!isLastChildBlockConfirmed(self)) {return;}
        if (self.exits[_user].executed == true) {return;}
        if (self.exits[_user].amount > self.users[_user]) {
            deleteExitsIndicesByAccount(self, _user);
            delete self.exits[_user];
        } else {
            self.refundAddress[_user].transfer(self.exits[_user].amount.add(self.userExitBond));
            self.users[_user] = self.users[_user].sub(self.exits[_user].amount);
            self.totalDeposit = self.totalDeposit.sub(self.exits[_user].amount);
            self.exits[_user].executed = true;
        }
    }

     /**
    * @dev Delete exit index by the account
    * @param _account The exit account
     */
    function deleteExitsIndicesByAccount(ChainStorage storage self, address _account) internal {
        for (uint i = 0; i < self.exitsIndices.length; i++) {
            if (_account == self.exitsIndices[i]) {
                self.exitsIndices[i] = self.exitsIndices[self.exitsIndices.length - 1];
                delete self.exitsIndices[self.exitsIndices.length - 1];
                self.exitsIndices.length--;
            }
        }
    }

    /**
    * @dev Check whether there is an unresolved (still in or has passed the execution period) deposit/exit
    *      request for the input account
    * @param _account The account to check
    * @return true if there is an unresolved request
    */
    function existUnresolvedRequest(ChainStorage storage self, address _account) public view returns(bool) {
        if (self.exits[_account].amount > 0 && self.exits[_account].blkNum < self.nextChildBlockNum) {
            return true;
        } else if (self.deposits[_account].amount > 0 && self.deposits[_account].blkNum < self.nextChildBlockNum) {
            return true;
        } else {
            return false;
        }
    }

    /**
    * @dev Calculates the block height of last confirmed child block
    * @return The block height of last confirmed child block
    */
    function getLastConfirmedChildBlockNumber(ChainStorage storage self) public view returns(uint256) {
        if (isLastChildBlockConfirmed(self)) {
            return self.lastChildBlockNum;
        } else {
            return self.lastChildBlockNum.sub(self.CHILD_BLOCK_INTERVAL);
        }
    }

    /**
    * @dev Calculates the last submitted child block num.
    * @return The block height of last submitted child block.
    */
    function getLastChildBlockNumber(ChainStorage storage self) public view returns(uint256) {
        return self.nextChildBlockNum.sub(self.CHILD_BLOCK_INTERVAL);
    }

    /**
    * @dev Check whether last submitted child block is confirmed
    * @return true if last submitted child block is confirmed.
    */
    function isLastChildBlockConfirmed(ChainStorage storage self) public view returns(bool) {
        return block.timestamp.sub(self.childBlocks[self.lastChildBlockNum].timestamp) >= self.childBlockChallengePeriod && self.childBlockChallengeId.length == 0;
    }
}