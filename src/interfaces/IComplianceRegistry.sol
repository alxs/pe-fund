// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

interface IComplianceRegistry {
    function isCompliant(address _account) external view returns (bool);
    function isAmlCompliant(address _account) external view returns (bool);
    function isKycCompliant(address _account) external view returns (bool);
}
