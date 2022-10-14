// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

/* TODO
 *
 */


import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {
	
	ExampleExternalContract public exampleExternalContract;
	  
	/* Solidity Mappings:
	 * 1. how much ETH is deposited into the contract
	 * 2. the time that the deposit happened
	 */
	mapping(address => uint256) public balances; 
	mapping(address => uint256) public depositTimestamps;
	
	// Public Variables for parameters
	
	// to track who sends stake()
	address payable public owner;
	address payable public user;
	address payable public contractAddress;
	address payable public externalContractAddress; // not needed
	
	uint256 public constant rewardRatePerSecond = 0.01 ether;
	uint256 public rewardRatePerBlock = 0.01 ether;
	
	
	uint256 public withdrawalDeadline = block.timestamp + 120 seconds; 
	uint256 public claimDeadline = block.timestamp + 240 seconds; 
	uint256 public currentBlock = 0;

	bool public beginInterest = false;
	
	// Events
	event Stake(address indexed sender, uint256 amount); 
	event Received(address, uint); 
	event Execute(address indexed sender, uint256 amount);
	event AccrueRewards(address indexed sender, uint256 amount);
  
  
	/** MODIFIERS **/
	
	// Checks if the withdrawal period has been reached or not
	modifier withdrawalDeadlineReached( bool requireReached ) {
		uint256 timeRemaining = withdrawalTimeLeft();
		if( requireReached ) {
			require(timeRemaining == 0, "Withdrawal period is not reached yet");
		} else {
			require(timeRemaining > 0, "Withdrawal period has been reached");
		}
		_;
	}

	// Checks if the claim period has ended or not
	modifier claimDeadlineReached( bool requireReached ) {
		uint256 timeRemaining = claimPeriodLeft();
		if( requireReached ) {
			require(timeRemaining == 0, "Claim deadline is not reached yet");
		} else {
			require(timeRemaining > 0, "Claim deadline has been reached");
		}
		_;
	}

	// Requires that the contract only be completed once!
	modifier notCompleted() {
		bool completed = exampleExternalContract.completed();
		require(!completed, "Stake already completed!");
		_;
	}
	
	// Check to see if contract is completed
	modifier stakeCompleted(bool contractCompleted) {
		bool completed = exampleExternalContract.completed();
		if( contractCompleted ) {
			require(completed, "Stake is not completed yet.");
		} else {
			require(!completed, "Stake is completed.");
		}
		_;
	}
	
	// Requires that di ting started
	modifier stakingBegan() {
		uint256 timeRemaining = withdrawalTimeLeft();
		
		if (timeRemaining == 0) {
			beginInterest = false; // ~doubt this works. but then why is accumulateInterest still triggering?
		} else {
			
			require(beginInterest, "Not currently staking");
		}
		
		//bool completed = beginInterest;
		
		//require(beginInterest, "Not currently staking");
		
		_;
	}
	
	constructor(address exampleExternalContractAddress) public {
		exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
		
		externalContractAddress = payable(exampleExternalContractAddress); //should be abe to use above.
		contractAddress = payable(address(this));
		owner = payable(msg.sender); //incorrect
	
	}
	
	/** FUNCTIONS **/
	
	
	// Stake function for a user to stake ETH in our contract
	function stake() public payable withdrawalDeadlineReached(false) claimDeadlineReached(false) {
		balances[msg.sender] = balances[msg.sender] + msg.value;
		//balances[address(this)] = balances[address(this)] + msg.value;
		//balances[msg.sender] = msg.value;
		
		user = payable(msg.sender);
		
		depositTimestamps[msg.sender] = block.timestamp;
		
		beginInterest = true;
		
		//console.log("Deposit block numer: " + block.number);
		emit Stake(msg.sender, msg.value);
	}
	
	/* Accumulate Interest Function:
	 * add interest onto balance
	 * implement exponential reward by increasing reward amount each period
	 */
	 
	function accumulateInterest() public payable stakingBegan stakeCompleted(false){
		
		balances[msg.sender] = (balances[msg.sender] + rewardRatePerBlock);
		
		rewardRatePerBlock += 0.005 ether;
		
		//emit AccrueRewards(msg.sender, balances[msg.sender]);		
		
	}
	
	
	
	/* Withdraw function:
	 * for a user to remove their staked ETH inclusive
	 * of both the principle balance and any accrued interest
	 */

	function withdraw() public payable withdrawalDeadlineReached(true) claimDeadlineReached(false) stakeCompleted(false){
		address payable to = payable(msg.sender);
		
		require(balances[msg.sender] > 0, "You have no balance to withdraw!");
		uint256 individualBalance = balances[msg.sender];
		
		
		beginInterest = false;
		balances[msg.sender] = 0;

		// Transfer all ETH via call! (not transfer) cc: https://solidity-by-example.org/sending-ether
		//Staked rewards: ${gained}
		(bool sent, bytes memory data) = to.call{value: individualBalance}("");  //indBalanceRewards
		require(sent, "RIP; withdrawal failed :( ");
	}
	
	/* Repatriate Function:
	 * Allows any user to repatriate "unproductive" funds that are left in the staking contract
	 * past the defined withdrawal period.
	 * We want notCompleted to be true since this dApp is only designed for a single use.
	 */
	function execute() public claimDeadlineReached(true) stakeCompleted(false) {
		uint256 contractBalance = address(this).balance;
		exampleExternalContract.complete{value: address(this).balance}();
	}
	
	
	// add only if it is completed
	// do I change balances[address] to zero?
	function restart() public payable claimDeadlineReached(true) stakeCompleted(true){
		require(msg.sender == user, "Only owner can reopen staking");
		exampleExternalContract.restart(contractAddress);
	}


	// do I change balances[address] to zero?
	function reopenStaking() public payable {
		// add owner only modifier / req
		require(msg.sender == externalContractAddress, "Wrong external contract");

		// reset variables
		

		rewardRatePerBlock = 0.01 ether;
		withdrawalDeadline = block.timestamp + 120 seconds; 
		claimDeadline = block.timestamp + 240 seconds;
		beginInterest = false;
		balances[user] = 0;
		
	}


	
	
	// To update contract balance
	
	/*
	function updateContractBalance(uint256 amt) public {
		address(this).balance += amt;
	}
	*/
	
	/** READ ONLY FUNCTIONS **/
	function withdrawalTimeLeft() public view returns (uint256 withdrawalTimeLeft) {
		if( block.timestamp >= withdrawalDeadline) {
			return (0);
		} else {
			return (withdrawalDeadline - block.timestamp);
		}
	}

	function claimPeriodLeft() public view returns (uint256 claimPeriodLeft) {
		if( block.timestamp >= claimDeadline) {
			return (0);
		} else {
			return (claimDeadline - block.timestamp);
		}
	}
	
	
	/* Time to "kill-time" on our local testnet */
	function killTime() public {
		currentBlock = block.timestamp;
	}

	/* Function for our smart contract to receive ETH
	 * cc: https://docs.soliditylang.org/en/latest/contracts.html#receive-ether-function
	 */
	receive() external payable {
		emit Received(msg.sender, msg.value);
	}
  
  
}