pragma solidity ^0.4.21;

import "./BurnableToken.sol";
import "./StandardToken.sol";
import "./Claimable.sol";
import "./Pausable.sol";
import "./SafeMath.sol";


contract LockableToken is StandardToken, BurnableToken, Claimable, Pausable {
	using SafeMath for uint256;

	event Lock(address indexed owner, uint256 value);
	event UnLock(address indexed owner, uint256 value);

	uint256 public nodeSmallAmount;

	uint256 public nodeBigAmount;

	struct LockRecord {
	    
	    // lock amount
	    uint256 amount;
	    
	    /// unlock timestamp
	    uint256 releaseTimestamp;
	}
	
	mapping (address => LockRecord[]) ownedLockRecords;
	mapping (address => uint256) ownedLockAmount;

	function setNodeSmallAmount(uint256 _amount) external onlyOwner {
		nodeSmallAmount = _amount;
	}

	function setNodeBigAmount(uint256 _amount) external onlyOwner {
		nodeBigAmount = _amount;	
	}

	/**
	* @dev Lock token until 1 year.
	*/
	function lockTokenForNodeSmall() public whenNotPaused {
		require(balances[msg.sender] >= nodeSmallAmount);
	    
	    uint256 amount = nodeSmallAmount;
	    ////@dev for test
		uint256 releaseTimestamp = now + 3 seconds;

	 	_lockToken(amount, releaseTimestamp);
	}

	function lockTokenForNodeBig() public whenNotPaused {
		require(balances[msg.sender] >= nodeBigAmount);
		
		uint256 amount = nodeBigAmount;
		uint256 releaseTimestamp = now + 3 seconds;

	 	_lockToken(amount, releaseTimestamp);   
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

	/*
	* @param _index uint256 Lock record idnex.
	* @return Return a lock record (lock amount, releaseTimestamp)
	*/
	function getLockByIndex(uint256 _index) public view returns(uint256, uint256) {
        LockRecord memory record = ownedLockRecords[msg.sender][_index];
        
        return (record.amount, record.releaseTimestamp);
    }

    function getLockAmount() public view returns(uint256) {
    	LockRecord[] memory list = ownedLockRecords[msg.sender];
    	uint sum = 0;
    	for (uint i = 0; i < list.length; i++) {
    		sum += list[i].amount;
    	}

    	return sum;
    }

	/*
	* @param _amount uint256 Lock amount.
	* @param _releaseTimestamp uint256 Unlock timestamp.
	*/
	function _lockToken(uint256 _amount, uint256 _releaseTimestamp) internal {
		balances[msg.sender] = balances[msg.sender].sub(_amount);
		ownedLockRecords[msg.sender].push( LockRecord(_amount, _releaseTimestamp) );
		ownedLockAmount[msg.sender] = ownedLockAmount[msg.sender].add(_amount);

		emit Lock(msg.sender, _amount);
	}

	/*
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

		emit UnLock(msg.sender, record.amount);
	}

}

contract BunnyBurnableToken is LockableToken {
	
	event Upgrade(address indexed owner, uint256 value);
	event UpgradeFor(address indexed from, address indexed to, uint256 value);

	address public cooAddress;

	/// @dev User upgrade action will consume a certain amount of token.
	uint256 public upgradeAmount;

	/// @dev User upgrade action will brun a certain amount of token their owned.
	uint256 public upgradeBrunAmount;


	 /**
	* @dev The BunnyBurnableToken constructor sets the original `cooAddress` of the contract to the sender
	* account.
	*/
	function BunnyBurnableToken() public {
		cooAddress = msg.sender;
	}
	
	/// @dev Assigns a new address to act as the COO.
    /// @param _newCOO The address of the new COO.
    function setCOO(address _newCOO) external onlyOwner {
        require(_newCOO != address(0));
        
        cooAddress = _newCOO;
    }

    function setUpgradeAmount(uint256 _upgradeAmount) external onlyOwner {
        upgradeAmount = _upgradeAmount;
    }

    function setUpgradeBrunAmount(uint256 _upgradeBrunAmount) external onlyOwner {
        upgradeBrunAmount = _upgradeBrunAmount;
    }

    function burnBunnyFor(address _address) external whenNotPaused {
    	require(balances[msg.sender] >= upgradeAmount);

    	balances[msg.sender] = balances[msg.sender].sub(upgradeAmount);
    	uint256 fee = upgradeAmount.sub(upgradeBrunAmount);
    	balances[cooAddress] = balances[cooAddress].add(fee);
    	
    	burn(upgradeBrunAmount);

    	emit Transfer(msg.sender, cooAddress, fee);
    	emit UpgradeFor(msg.sender, _address, upgradeAmount);
    }

    function burnBunny() external whenNotPaused {
    	require(balances[msg.sender] >= upgradeAmount);

    	balances[msg.sender] = balances[msg.sender].sub(upgradeAmount);
    	uint256 fee = upgradeAmount.sub(upgradeBrunAmount);
    	balances[cooAddress] = balances[cooAddress].add(fee);
    	
    	burn(upgradeBrunAmount);

    	emit Transfer(msg.sender, cooAddress, fee);
    	emit Upgrade(msg.sender, upgradeAmount);
    }
}

contract BunnyToken is BunnyBurnableToken {
	string public name    = "AAA";
	string public symbol  = "AA";
	uint8 public decimals = 8;

	// 1.6 billion in initial supply
	uint256 public constant INITIAL_SUPPLY = 1600000000;

	function BunnyToken() public {
		totalSupply_      = INITIAL_SUPPLY * (10 ** uint256(decimals));
		nodeSmallAmount   = 10000  * (10 ** uint256(decimals));
	    nodeBigAmount     = 100000  * (10 ** uint256(decimals));
	    upgradeAmount     = 126 * (10 ** uint256(decimals));
	    upgradeBrunAmount = 100 * (10 ** uint256(decimals));

		balances[msg.sender] = totalSupply_;
	}
}