// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract HYCOTokenV2 is ERC20, ERC20Burnable, Pausable, Ownable {
    using SafeMath for uint256;

    event TimeLock(address indexed account, uint256 amount, uint256 startTime, uint256 releaseMonths);
    //event TimeUnlock(address indexed account, uint256 releaseMonths, uint256 amount);
    
    struct LockInfo {
        uint256 amount;    
        uint256 startTime;
        uint256 releaseMonths;
    }
    mapping(address => LockInfo) private _lockInfos;
    address[] private _lockedWallets;

    constructor() ERC20("HYCOTokenV2", "HYCO") {
        _mint(msg.sender, 100000000 * 10 ** decimals());
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        require( !_isLocked( from, amount ) , "ERC20: Locked balance.");
        super._beforeTokenTransfer(from, to, amount);
    }

    function setLock(address walletAddress, uint256 startTime, uint256 releaseMonths, uint256 amount) 
        public
        onlyOwner 
    {
        require(block.timestamp < startTime, "ERC20: Current time is greater than start time.");
        require(releaseMonths > 0, "ERC20: ReleaseMonths is greater than 0.");
        require(amount > 0, "ERC20: Amount is greater than 0.");
        
        _lockInfos[walletAddress] = LockInfo(amount, startTime, releaseMonths);
        _lockedWallets.push(walletAddress);

        emit TimeLock( walletAddress, amount, startTime, releaseMonths ); 
    }

    function setLockReleaseMonths(address walletAddress, uint256 releaseMonths)
        public
        onlyOwner
    {
        require(_lockInfos[walletAddress].amount > 0, "Not exist lock info.");
        require(releaseMonths > 0, "ERC20: ReleaseMonths is greater than 0.");
        _lockInfos[walletAddress].releaseMonths = releaseMonths;
    }

    function setLockStartTime(address walletAddress, uint256 startTime)
        public
        onlyOwner
    {
        require(_lockInfos[walletAddress].amount > 0, "Not exist lock info.");
        require(block.timestamp < startTime, "ERC20: Current time is greater than start time");
        _lockInfos[walletAddress].startTime = startTime;
    }

    function setLockAmount(address walletAddress, uint256 amount)
        public
        onlyOwner
    {
        require(_lockInfos[walletAddress].amount > 0, "Not exist lock info.");
        require(amount > 0, "ERC20: Amount is greater than 0.");
        _lockInfos[walletAddress].amount = amount;
    }

    function getLockInfo(address walletAddress) 
        public 
        view 
        returns (uint256 lockAmount, uint256 startTime, uint256 releaseMonths, uint256 released) 
    {
        require(msg.sender == walletAddress || msg.sender == owner(), "Caller is not the owner.");
        require(_lockInfos[walletAddress].amount > 0, "Not exist lock info.");
        
        uint256 unLockAmount = _getUnLockAmount(walletAddress, block.timestamp);

        return (_lockInfos[walletAddress].amount, _lockInfos[walletAddress].startTime, _lockInfos[walletAddress].releaseMonths, unLockAmount);
    }

    function _getUnLockAmount(address walletAddress, uint256 timestamp)
        internal
        view
        returns (uint256 unLockAmount)
    {
        uint256 lockAmount = _lockInfos[walletAddress].amount;
        uint256 lockStartTime = _lockInfos[walletAddress].startTime;
        uint256 releaseMonths = _lockInfos[walletAddress].releaseMonths;

        uint256 unLockAmountRate = timestamp.sub(lockStartTime).div(86400 * 30);  //per 30day

        if (releaseMonths <= unLockAmountRate) {
            return lockAmount;
        } else if (unLockAmountRate < 1) {
            return 0;
        } else {
            return lockAmount.mul(unLockAmountRate).div(releaseMonths);
        }
    }

    function _isLocked(address walletAddress, uint256 amount) 
        internal 
        view 
        returns (bool) 
    {
        if (_lockInfos[walletAddress].amount != 0) {
            uint256 unLockAmount = _getUnLockAmount(walletAddress, block.timestamp);
            return balanceOf(walletAddress).sub(_lockInfos[walletAddress].amount.sub(unLockAmount)) < amount;
        } else {
            return false;
        }
    }

}