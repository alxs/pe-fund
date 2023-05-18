// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISecurityToken is IERC20 {
    function mint(address recipient, uint256 amount) external;
    function chargeManagementFee(uint8 mgtFee, uint256 price, uint64 ts) external;
    function distribute(uint32 distId, string memory distType, uint64 time, uint256 amount, uint256 scale) external;
    function isCommitToken() external view returns (bool);
    function updateFeeStatus(uint32 feeId, uint8 status, uint64 ts, address[] memory accounts) external;
}
