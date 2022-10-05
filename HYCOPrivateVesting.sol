// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";


contract HYCOPrivateVesting is Ownable {
    event SetVesting(address indexed account, uint256 amount, uint256 startTime, uint256 duration);
    event Released(address indexed account, uint256 amount);

    struct VestingInfo {
        uint256 amount;    
        uint256 startTime;
        uint256 duration;
        uint256 released;
    }
    mapping(address => VestingInfo) private _vestingInfos;
    address[] private _vestingWallets;

    IERC20 private immutable _erc20;

    /**
     * @dev Set the ERC20 token address.
     */
    constructor(
        address erc20Address
    ) {
        _erc20 = IERC20(erc20Address);
    }

    /**
     * @dev Setter for the VestingInfo.
     */
    function setVestingInfo (address beneficiaryAddress, uint256 amount, uint256 startTime, uint256 duration) external onlyOwner {
        require(beneficiaryAddress != address(0), "Beneficiary cannot be address zero");
        require(block.timestamp < startTime, "ERC20 : Current time is greater than start time");
        require(duration > 86400, "ERC20 : Duration is greater than one day");
        require(amount > 0, "ERC20: Amount is greater than 0");
        
        _vestingInfos[beneficiaryAddress] = VestingInfo(amount, startTime, duration, 0);
        _vestingWallets.push(beneficiaryAddress);

        emit SetVesting( beneficiaryAddress, amount, startTime, duration );
    }
    function setVestingAmount (address beneficiaryAddress, uint256 value) external onlyOwner {
        require(_vestingInfos[beneficiaryAddress].amount > 0, "Not exist vesting info.");
        require(value > 0, "ERC20: Amount is greater than 0.");
        _vestingInfos[beneficiaryAddress].amount = value;
    }
    function setVestingStartTime (address beneficiaryAddress, uint256 value) external onlyOwner {
        require(_vestingInfos[beneficiaryAddress].startTime > 0, "Not exist vesting info.");
        require(block.timestamp < value, "ERC20 : Current time is greater than start time");
        _vestingInfos[beneficiaryAddress].startTime = value;
    }
    function setVestingDuration(address beneficiaryAddress, uint256 value) external onlyOwner {
        require(_vestingInfos[beneficiaryAddress].duration > 0, "Not exist vesting info.");
        require(value > 86400, "ERC20 : Duration is greater than one day");
        _vestingInfos[beneficiaryAddress].duration = value;
    }

    /**
     * @dev Getter for the VestingInfo.
     */
    function getVestingInfo(address beneficiaryAddress) public view virtual returns (uint256 amount, uint256 startTime, uint256 duration, uint256 released) {
        return (_vestingInfos[beneficiaryAddress].amount, _vestingInfos[beneficiaryAddress].startTime, _vestingInfos[beneficiaryAddress].duration, _vestingInfos[beneficiaryAddress].released);
    }
    function getVestingWallets() public view virtual returns (address[] memory) {
        return (_vestingWallets);
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {TokensReleased} event.
     */
    function release(address beneficiaryAddress) public virtual {
        require(_vestingInfos[beneficiaryAddress].amount > 0, "Not exist vesting info.");

        uint256 releasable = _vestingSchedule(beneficiaryAddress, uint256(block.timestamp)) - _vestingInfos[beneficiaryAddress].released;
        
        SafeERC20.safeTransfer(_erc20, beneficiaryAddress, releasable);

        _vestingInfos[beneficiaryAddress].released += releasable;

        emit Released(beneficiaryAddress, releasable);
    }

    function releaseSchedule() public virtual onlyOwner {
        uint256 releaseTime = block.timestamp;
        for (uint8 i = 0; i < _vestingWallets.length; i++) {

            uint256 releasable = _vestingSchedule(_vestingWallets[i], releaseTime) - _vestingInfos[_vestingWallets[i]].released;
            if (releasable > 0) {
                SafeERC20.safeTransfer(_erc20, _vestingWallets[i], releasable);
                _vestingInfos[_vestingWallets[i]].released += releasable;

                emit Released(_vestingWallets[i], releasable); 
            }               

        }        
    }

    /**
     * @dev Calculates the amount of tokens that has already vested. Default implementation is a linear vesting curve.
     */
    function vestedAmount(address beneficiaryAddress, uint256 timestamp) public view virtual returns (uint256) {
        return _vestingSchedule(beneficiaryAddress, timestamp);
    }

    /**
     * @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for
     * an asset given its total historical allocation.
     */
    function _vestingSchedule(address beneficiaryAddress, uint256 timestamp) internal view virtual returns (uint256) {
        if (timestamp < _vestingInfos[beneficiaryAddress].startTime) {
            return 0;
        } else if (timestamp > _vestingInfos[beneficiaryAddress].startTime + _vestingInfos[beneficiaryAddress].duration) {
            return _vestingInfos[beneficiaryAddress].amount;
        } else {
            return (_vestingInfos[beneficiaryAddress].amount * (timestamp - _vestingInfos[beneficiaryAddress].startTime)) / _vestingInfos[beneficiaryAddress].duration;
        }
    }

}