pragma solidity ^0.4.21;

import "./BurnableToken.sol";
import "./StandardToken.sol";
import "./Claimable.sol";
import "./Pausable.sol";
import "./SafeMath.sol";

contract PausableToken is StandardToken, BurnableToken, Claimable, Pausable {
    function transfer(address to, uint256 value) public whenNotPaused returns (bool) {
    	return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public whenNotPaused returns (bool) {
    	return super.transferFrom(from, to, value);
    }

    function approve(address spender, uint256 value) public whenNotPaused returns (bool) {
    	return super.approve(spender, value);
    }
}

contract LockableToken is PausableToken {
	using SafeMath for uint256;

	event Lock(address indexed owner, uint256 orderId, uint256 amount, uint256 releaseTimestamp);
	event UnLock(address indexed owner, uint256 orderId, uint256 amount);

	struct LockRecord {
	    
	    ///@dev order id
	    uint256 orderId;

	    ///@dev lock amount
	    uint256 amount;

	    ///@dev unlock timestamp
	    uint256 releaseTimestamp;
	}
	
	mapping (address => LockRecord[]) ownedLockRecords;
	mapping (address => uint256) ownedLockAmount;

	/**
	* @dev Lock token until _timeSpan second.
	* @param _orderId uint256
	* @param _amount uint256
	*/
	function lockTokenForNode(uint256 _orderId, uint256 _amount, uint256 _timeSpan) public whenNotPaused {
		require(balances[msg.sender] >= _amount);
		require(_timeSpan > 0 && _timeSpan <= 3 years);
	    
		uint256 releaseTimestamp = now + _timeSpan;

	 	_lockToken(_orderId, _amount, releaseTimestamp);
	}


	function unlockToken() public whenNotPaused {
		LockRecord[] memory list = ownedLockRecords[msg.sender];
		for(uint i = list.length - 1; i >= 0; i--) {
			// If a record can be release.
			if (now >= list[i].releaseTimestamp) {
				_unlockTokenByIndex(i);
			}
			/// @dev i is a type of uint , so it must be break when i == 0.
			if (i == 0) {
				break;
			}
		}
	}

	/**
	* @param _index uint256 Lock record idnex.
	* @return Return a lock record (lock amount, releaseTimestamp)
	*/
	function getLockByIndex(uint256 _index) public view returns(uint256, uint256, uint256) {
        LockRecord memory record = ownedLockRecords[msg.sender][_index];
        
        return (record.orderId, record.amount, record.releaseTimestamp);
    }

    function getLockAmount() public view returns(uint256) {
    	LockRecord[] memory list = ownedLockRecords[msg.sender];
    	uint sum = 0;
    	for (uint i = 0; i < list.length; i++) {
    		sum += list[i].amount;
    	}

    	return sum;
    }

	/**
	* @param _amount uint256 Lock amount.
	* @param _releaseTimestamp uint256 Unlock timestamp.
	*/
	function _lockToken(uint256 _orderId, uint256 _amount, uint256 _releaseTimestamp) internal {
		balances[msg.sender] = balances[msg.sender].sub(_amount);

		///@dev We don't care the orderId already exist or not. 
		/// Because the web server will detect it.
		ownedLockRecords[msg.sender].push( LockRecord(_orderId, _amount, _releaseTimestamp) );
		ownedLockAmount[msg.sender] = ownedLockAmount[msg.sender].add(_amount);

		emit Lock(msg.sender, _orderId, _amount, _releaseTimestamp);
	}

	/**
	* @dev using by internal.
	*/
	function _unlockTokenByIndex(uint256 _index) internal {
		LockRecord memory record = ownedLockRecords[msg.sender][_index];
		uint length = ownedLockRecords[msg.sender].length;

		ownedLockRecords[msg.sender][_index] = ownedLockRecords[msg.sender][length - 1];
		delete ownedLockRecords[msg.sender][length - 1];
		ownedLockRecords[msg.sender].length--;

		ownedLockAmount[msg.sender] = ownedLockAmount[msg.sender].sub(record.amount);
		balances[msg.sender] = balances[msg.sender].add(record.amount);

		emit UnLock(msg.sender, record.orderId, record.amount);
	}

}

contract TuzyPayableToken is LockableToken {
	
	event Pay(address indexed owner, uint256 orderId, uint256 amount, uint256 burnAmount);

	address public cooAddress;

	/// @dev User pay action will consume a certain amount of token.
	//uint256 public payAmount;

	/// @dev User pay action will brun a certain amount of token their owned.
	//uint256 public payBrunAmount;


	/**
	* @dev The TuzyPayableToken constructor sets the original `cooAddress` of the contract to the sender
	* account.
	*/
	function TuzyPayableToken() public {
		cooAddress = msg.sender;
	}
	
	/// @dev Assigns a new address to act as the COO.
    /// @param _newCOO The address of the new COO.
    function setCOO(address _newCOO) external onlyOwner {
        require(_newCOO != address(0));
        
        cooAddress = _newCOO;
    }

    /**
    * @dev Pay for order
    *
    */ 
    function payOrder(uint256 _orderId, uint256 _amount, uint256 _burnAmount) external whenNotPaused {
    	require(balances[msg.sender] >= _amount);
    	
    	/// @dev _burnAmount must be less then _amount, the code can be executed to the next line.
    	uint256 fee = _amount.sub(_burnAmount);
    	if (fee > 0) {
    		transfer(cooAddress, fee);
    	}
    	burn(_burnAmount);
    	emit Pay(msg.sender, _orderId, _amount, _burnAmount);
    }
}

contract TuzyToken is TuzyPayableToken {
	string public name    = "TuzyToken";
	string public symbol  = "TUC";
	uint8 public decimals = 8;

	// 1.6 billion in initial supply
	uint256 public constant INITIAL_SUPPLY = 1600000000;

	function TuzyToken() public {
		totalSupply_ = INITIAL_SUPPLY * (10 ** uint256(decimals));
		balances[msg.sender] = totalSupply_;
	}
}