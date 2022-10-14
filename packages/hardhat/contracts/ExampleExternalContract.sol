// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;  //Do not change the solidity version as it negativly impacts submission grading

import "./Staker.sol";

contract ExampleExternalContract {
	
  Staker public stakerContract;

  bool public completed;

  function complete() public payable {
    completed = true;
  }

  function restart(address payable stakerAddress) public {

	stakerContract = Staker(stakerAddress);

	completed = false;
	/*
	(bool sent, bytes memory data) = staker.call{value: address(this).balance}("");
	require(sent, "RIP; restart failed :( ");
	*/

	stakerContract.reopenStaking{value: address(this).balance}();
  }
}
