// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFundToken is IERC20 {
    function mint(address recipient, uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
    function chargeManagementFee(uint8 mgtFee, uint256 id, uint256 price, uint256 timestamp) external;
    function distribute(uint32 distId, string memory distType, uint256 time, uint256 amount, uint256 scale) external;
    function isCommitToken() external view returns (bool);
}
