pragma solidity ^0.4.24;

// external modules
import "./RLP.sol";
import "./RLPEncoding.sol";
import "./SafeMath.sol";
import "./StemCore.sol";
import "./StemChallenge.sol";

library StemRelay {
    using RLP for bytes;
    using RLP for RLP.RLPItem;
    using RLPEncoding for address;
    using RLPEncoding for uint256;
    using RLPEncoding for bytes[];
    using SafeMath for uint256;

    event BlockSubmitted(uint256 blkNum, uint256 timestamp);
    event BlockReversed(uint256 blkNum);

    function handleRelayBlock(StemCore.ChainStorage storage self, uint256 _blkNum, bytes32 _balanceTreeRoot, bytes32 _txTreeRoot, address[] _accounts, uint256[] _updatedBalances, uint256 _fee, address _msgSender) public {
        // make sure last submitted child block is confirmed and release last block submitter's bond
        require(StemCore.isLastChildBlockConfirmed(self), "Last block is not confirmed yet");
        require(_accounts.length == _updatedBalances.length, "The number of accounts and the number of updated balances should be the same");
        require(self.nextChildBlockNum == _blkNum, "Invalid child block number");
        if (!self.isBlockSubmissionBondReleased)
        {
            self.childBlocks[self.lastChildBlockNum].submitter.transfer(self.blockSubmissionBond);
        }

        // operator bond is locked again
        self.isBlockSubmissionBondReleased = false;

        // Create the block.
        self.childBlocks[self.nextChildBlockNum] = StemCore.ChildBlock({
            submitter: _msgSender,
            balanceTreeRoot: _balanceTreeRoot,
            txTreeRoot: _txTreeRoot,
            timestamp: block.timestamp
        });

        // deal with deposits and exits executed during last period
        StemCore.executeDepositsAndExits(self);

        // backup and update some accounts
        updateBalancesAndFee(self, _accounts, _updatedBalances, _fee);

        // Update the next child and deposit blocks.
        self.nextChildBlockNum = self.nextChildBlockNum.add(self.CHILD_BLOCK_INTERVAL);
        self.lastChildBlockNum = self.lastChildBlockNum.add(self.CHILD_BLOCK_INTERVAL);
        if (self.curDepositBlockNum < self.nextChildBlockNum) {
            self.nextDepositBlockIncrement = 1;
            self.curDepositBlockNum = self.nextChildBlockNum.add(self.nextDepositBlockIncrement);
        }
        if (self.curExitBlockNum < self.nextChildBlockNum) {
            self.nextExitBlockIncrement = 1;
            self.curExitBlockNum = self.nextChildBlockNum.add(self.nextExitBlockIncrement);
        }

        emit BlockSubmitted(_blkNum, block.timestamp);

    }

     /**
     * @dev Update balances and fee of operator/user accounts
     * @param _accounts Accounts to be updated
     * @param _updatedBalances Updated balances
     * @param _fee Fee income for each active operator account
     */
    function updateBalancesAndFee(StemCore.ChainStorage storage self, address[] _accounts, uint256[] _updatedBalances, uint256 _fee) internal {
        delete self.accountsBackup;
        delete self.balancesBackup;
        for (uint j = 0; j < _accounts.length; j++) {
            if (self.isExistedOperators[_accounts[j]]) {
                self.accountsBackup.push(_accounts[j]);
                self.balancesBackup.push(self.operators[_accounts[j]]);
                self.operators[_accounts[j]] = _updatedBalances[j];
            } else if (self.isExistedUsers[_accounts[j]]) {
                self.accountsBackup.push(_accounts[j]);
                self.balancesBackup.push(self.users[_accounts[j]]);
                self.users[_accounts[j]] = _updatedBalances[j];
            }
        }

        // backup and update operator fee account
        self.feeBackup = _fee;
        for (j = 0; j < self.operatorIndices.length; j++) {
            self.operatorFee[self.operatorIndices[j]] = self.operatorFee[self.operatorIndices[j]].add(self.feeBackup);
        }
        // The sum of the total balance and fee of a subchain should be within a certain range
        // TODO consider the bond
        require(totalFee(self).add(totalBalance(self)) <= self.totalDeposit && self.totalDeposit < address(this).balance.sub(self.creatorMinDeposit));
    }

    function doReverseBlock(StemCore.ChainStorage storage self, uint256 _blkNum) public {
        require(block.timestamp.sub(self.childBlocks[self.lastChildBlockNum].timestamp) >= self.childBlockChallengePeriod, "Last submitted block is in challenge period");
        //require(self.childBlockChallengeId.length > 0, "No existing child block challenges");
        require(self.lastChildBlockNum == _blkNum, "Invalid child block number");
        delete self.childBlocks[self.lastChildBlockNum];
        self.nextChildBlockNum = self.lastChildBlockNum;
        self.lastChildBlockNum = StemCore.getLastChildBlockNumber(self);

        // reverse the balances updated by last submitted child block
        reverseBalancesAndFee(self);
        reverseOperatorIndices(self);

        // only the first challenger gets the blockSubmissionBond
        /*if (!self.isBlockSubmissionBondReleased)
        {
            self.childBlockChallenges[self.childBlockChallengeId[0]].challengerAddress.transfer(self.blockSubmissionBond);
            self.isBlockSubmissionBondReleased = true;
        }*/
        // clear challenges
        StemChallenge.clearExistingBlockChallenges(self);

        emit BlockReversed(self.nextChildBlockNum);
    }

    /**
     * @dev Reverse the balances and fee updated by last submitted child block
     */
    function reverseBalancesAndFee(StemCore.ChainStorage storage self) internal {
        for (uint i = 0; i < self.accountsBackup.length; i++) {
            if (self.isExistedOperators[self.accountsBackup[i]]) {
                self.operators[self.accountsBackup[i]] = self.balancesBackup[i];
            } else if (self.isExistedUsers[self.accountsBackup[i]]) {
                self.users[self.accountsBackup[i]] = self.balancesBackup[i];
            }
        }
        self.totalDeposit = self.totalDepositBackup;
        delete self.accountsBackup;
        delete self.balancesBackup;

        for (uint j = 0; j < self.operatorIndices.length; j++) {
            self.operatorFee[self.operatorIndices[j]] = self.operatorFee[self.operatorIndices[j]].sub(self.feeBackup);
        }
    }

     /**
     * @dev Reverse the operator indices updated by last submitted child block
     */
    function reverseOperatorIndices(StemCore.ChainStorage storage self) internal {
        address account;
        for (uint j = 0; j < self.depositsIndices.length; j++) {
            account = self.depositsIndices[j];
            if (self.deposits[account].blkNum > self.lastChildBlockNum && self.deposits[account].blkNum < self.nextChildBlockNum) {
                if (self.deposits[account].isOperator) {
                    self.isExistedOperators[account] = false;
                    StemCore.deleteOperatorIndicesByAccount(self, account);
                }
            }
        }
    }

    /**
    * @dev Get the total balance of operator accounts and user accounts
    * @return The total balance
    */
    function totalBalance(StemCore.ChainStorage storage self) public view returns (uint256){
        uint256 amount = 0;
        for (uint i = 0; i < self.operatorIndices.length; i++) {
            amount = amount.add(self.operators[self.operatorIndices[i]]);
        }
        for (uint j = 0; j < self.userIndices.length; j++) {
            amount = amount.add(self.users[self.userIndices[j]]);
        }
        return amount;
    }

    /**
    * @dev Get the total fee of operator accounts
    * @return The total fee
    */
    function totalFee(StemCore.ChainStorage storage self) public view returns (uint256){
        uint256 amount = 0;
        for (uint i = 0; i < self.operatorIndices.length; i++) {
            amount = amount.add(self.operatorFee[self.operatorIndices[i]]);
        }
        return amount;
    }
}