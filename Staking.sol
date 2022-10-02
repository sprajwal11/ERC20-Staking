// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./ERC20.sol";

// 000000000000000000
contract Staking{

    bool public active;
    uint256 public startTime;
    uint256 public cutoffTime;
    address public owner;

    ERC20 public immutable stakingToken;
    ERC20 public immutable rewardsToken;

    uint256 private totalTokens;

    struct rewardSchedule {
        uint64 days30;
        uint64 days15;
        uint64 days1;
    }
    rewardSchedule public rewardMultiplier = rewardSchedule({
        days30: 20,
        days15: 15,
        days1:10
    });

    mapping(address=>uint256)  userDepositTotal;
    mapping(address=>uint256)  numUserDeposits;
    address[] public allStakingUsers;

    struct userDeposit {
        uint256 amountNFT;
        uint256 depositTime;
    }
    mapping(address=>userDeposit[]) public userDeposits;

    uint256 public totalDeposited;
    uint256 public userFunds;
    uint256 public stakingFunds;
    uint256 public  totalRewardSupply;

    constructor(address _tokenAaddress,address _tokenBaddress,uint _totalRewardSupply) {
        stakingToken = ERC20(_tokenAaddress);
        rewardsToken = ERC20(_tokenBaddress);
        totalRewardSupply=_totalRewardSupply*1 ether;
        owner = msg.sender;
    }

    modifier onlyOwner  {require (msg.sender == owner,"You do not have access");_;}
    modifier stakingActive{require(active == true, "staking has not begun yet");_;}


    event WithdrawAll(address userAddress, uint256 principal, uint256 yield, uint256 userFundsRemaining, uint256 stakingFundsRemaining);
    event StakingBegins(uint256 timestamp, uint256 stakingFunds);
    event WithdrawPrincipal(address userAddress, uint256 principal, uint256 userFundsRemaining);
    event Deposited(address userAddress,uint256 amount);


    function changeStakingTime(uint _cutoffTime)public onlyOwner {
        require(_cutoffTime>=block.timestamp);
        cutoffTime=_cutoffTime;
    }


    function getRewardPercentage(uint256 daysStaked) public view returns(uint256) {
        if (daysStaked >= 30) return rewardMultiplier.days30;
        if (daysStaked >= 15) return rewardMultiplier.days15;
        if (daysStaked >= 1) return rewardMultiplier.days1;
        return 0;
    }

    function calculateUserReward(address userAddress) public view returns(uint256) {
        uint256 totalYield;
        for (uint256 i = 0; i < userDeposits[userAddress].length; i++) {
        uint256 daysStaked = (block.timestamp - userDeposits[userAddress][i].depositTime) / 1 days;
        // uint256 daysStaked=172800/1 days; for testing purpose
        uint256 yieldMultiplier = getRewardPercentage(daysStaked);
        totalYield += userDeposits[userAddress][i].amountNFT * yieldMultiplier /  100;
        }
        return totalYield;
    }


    function beginStaking(uint _cutoffTime) external onlyOwner {
        require(rewardsToken.balanceOf(msg.sender)>=totalRewardSupply, "you do not have enough staking rewards");
        active = true;
        startTime = block.timestamp;
        cutoffTime = _cutoffTime;
        stakingFunds = totalRewardSupply;
        emit StakingBegins(startTime, stakingFunds);
    }


    function deposit(uint256 depositAmount) external stakingActive {
        require(depositAmount>0,"Amount has to be greater than zero");
        require(stakingToken.balanceOf(msg.sender) >= depositAmount, "Insufficient balance in your account");
        require(block.timestamp < cutoffTime, "Staking Period Has Ended");

        if (userDepositTotal[msg.sender] == 0){
            allStakingUsers.push(msg.sender);
        } 
        userDepositTotal[msg.sender] += depositAmount;
        totalDeposited += depositAmount;
        userFunds += depositAmount;
        userDeposits[msg.sender].push(userDeposit({
            amountNFT: depositAmount,
            depositTime: block.timestamp
        }));
        numUserDeposits[msg.sender] = numUserDeposits[msg.sender] + 1;
        stakingToken.transferFrom(msg.sender, address(this), depositAmount);
        emit Deposited(msg.sender,depositAmount);
  }


    function withdrawRewardsAndPrincipal() public stakingActive {
        require(userDepositTotal[msg.sender] > 0, "you do not have anything to withdraw");
        uint256 withdrawalAmount = userDepositTotal[msg.sender];
        uint256 userYield = calculateUserReward(msg.sender);
        userDepositTotal[msg.sender] = 0;
        userFunds -= withdrawalAmount;
        stakingFunds -= userYield;
        for (uint256 i = 0; i < userDeposits[msg.sender].length; i++) {
            delete userDeposits[msg.sender][i];
        }
        stakingToken.transfer(msg.sender, withdrawalAmount);
        rewardsToken.transfer(msg.sender, userYield);
        emit WithdrawAll(msg.sender, withdrawalAmount, userYield, userFunds, stakingFunds);
    }


    function withdrawPrincipal() public {
        require(active == true, "There is no current Staking");
        uint256 withdrawalAmount = userDepositTotal[msg.sender];
        userDepositTotal[msg.sender] = 0;
        userFunds -= withdrawalAmount;
        for (uint256 i = 0; i < userDeposits[msg.sender].length; i++) {
            delete userDeposits[msg.sender][i];
        }
        stakingToken.transfer(msg.sender, withdrawalAmount);
        emit WithdrawPrincipal(msg.sender, withdrawalAmount, userFunds);
    }

}