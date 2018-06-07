// Copyright 2018 Parity Technologies Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// A validator set contract that relays calls to an inner validator set
// contract, which allows upgrading the inner validator set contract. It
// provides an `initiateChange` function that allows the inner contract to
// trigger a change, since the engine will be listening for events emitted by
// the outer contract. It keeps track of finality of pending changes in order to
// validate `initiateChange` and `finalizeChange` requests.

pragma solidity ^0.4.22;

import "./Owned.sol";
import "./ValidatorSet.sol";


contract OuterSet is Owned, ValidatorSet {
	// EVENTS
	event ChangeFinalized(address[] currentSet);

	// STATE

	// System address, used by the block sealer.
	address constant SYSTEM_ADDRESS = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;
	// Address of the inner validator set contract
	InnerSet public innerSet;
	// Was the last validator change finalized.
	bool public finalized;

	// MODIFIERS
	modifier onlySystemAndNotFinalized() {
		require(msg.sender == SYSTEM_ADDRESS && !finalized);
		_;
	}

	modifier onlyInnerAndFinalized() {
		require(msg.sender == address(innerSet) && finalized);
		_;
	}

	// For innerSet
	function initiateChange(bytes32 _parentHash, address[] _newSet)
		external
		onlyInnerAndFinalized
	{
		finalized = false;
		emit InitiateChange(_parentHash, _newSet);
	}

	// For sealer
	function finalizeChange()
		external
		onlySystemAndNotFinalized
	{
		finalizeChangeInternal();
	}

	function reportBenign(address validator, uint256 blockNumber)
		external
	{
		innerSet.reportBenign(validator, blockNumber);
	}

	function reportMalicious(address validator, uint256 blockNumber, bytes proof)
		external
	{
		innerSet.reportMalicious(validator, blockNumber, proof);
	}

	function setInner(address _inner)
		public
		onlyOwner
	{
		innerSet = InnerSet(_inner);
	}

	function getValidators()
		public
		view
		returns (address[])
	{
		return innerSet.getValidators();
	}

	// This method is defined with no modifiers so it can be reused by
	// contracts inheriting it (e.g. for mocking in tests).
	function finalizeChangeInternal()
		internal
	{
		finalized = true;
		innerSet.finalizeChange();
		emit ChangeFinalized(getValidators());
	}
}


contract InnerSet is ValidatorSet {
	OuterSet public outerSet;

	modifier onlyOuter() {
		require(msg.sender == address(outerSet));
		_;
	}
}
