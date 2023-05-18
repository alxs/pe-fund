// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ComplianceRegistry Contract
 * @notice This contract manages KYC and compliance traits for accounts
 * @author alxs
 */
contract ComplianceRegistry is AccessControl {
    enum Status {
        NonCompliant,
        Compliant
    }

    struct KycStatus {
        uint256 startTime;
        uint256 expiryTime;
        Status status;
    }

    struct AmlStatus {
        uint256 startTime;
        uint256 expiryTime;
        Status status;
    }

    bytes32 public constant AML_ADMIN = keccak256("AML_ADMIN");
    bytes32 public constant KYC_ADMIN = keccak256("KYC_ADMIN");

    mapping(address => KycStatus) private kycStatuses;
    mapping(address => AmlStatus) private amlStatuses;

    constructor(address _kycAdmin, address _complianceAdmin) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(KYC_ADMIN, _kycAdmin);
        _setupRole(AML_ADMIN, _complianceAdmin);
    }

    /* ========== VIEW FUNCTIONS ========== */

    /**
     * @notice Checks if an account is both KYC'd and AML compliant
     * @param account The address of the account
     * @return True if the account is KYC'd and AML compliant, false otherwise
     */
    function isCompliant(address account) public view returns (bool) {
        return isKycCompliant(account) && isAmlCompliant(account);
    }

    /**
     * @notice Checks if an account is KYC compliant
     * @param account The address of the account
     * @return True if the account is KYC compliant, false otherwise
     */
    function isKycCompliant(address account) public view returns (bool) {
        KycStatus memory status = kycStatuses[account];
        return status.status == Status.Compliant && block.timestamp < status.expiryTime;
    }

    /**
     * @notice Checks if an account is AML compliant
     * @param account The address of the account
     * @return True if the account is compliant, false otherwise
     */
    function isAmlCompliant(address account) public view returns (bool) {
        AmlStatus memory status = amlStatuses[account];
        return status.status == Status.Compliant && block.timestamp < status.expiryTime;
    }

    /* ========== RESTRICTED KYC FUNCTIONS ========== */

    /// @notice Set the KYC status for an account if it hasn't been set yet
    /// @dev Can only be called by an account with the KYC_ADMIN role
    /// @param account The account for which to set the KYC status
    /// @param expiryTime The time at which the KYC status expires
    /// @param status The KYC status to set
    function setKycStatus(address account, uint256 expiryTime, Status status) public onlyRole(KYC_ADMIN) {
        require(kycStatuses[account].expiryTime == 0, "KYC status already set");
        kycStatuses[account] = KycStatus(block.timestamp, expiryTime, status);
    }

    /// @notice Update the KYC status for an account
    /// @dev Can only be called by an account with the KYC_ADMIN role
    /// @param account The account for which to update the KYC status
    /// @param expiryTime The time at which the KYC status expires
    /// @param status The KYC status to set
    function updateKycStatus(address account, uint256 expiryTime, Status status) public onlyRole(KYC_ADMIN) {
        require(kycStatuses[account].expiryTime != 0, "KYC status not set yet");
        kycStatuses[account] = KycStatus(block.timestamp, expiryTime, status);
    }

    /**
     * @notice Clear KYC status for an account
     * @param account The address of the account
     */
    function clearKycStatus(address account) public onlyRole(KYC_ADMIN) {
        delete kycStatuses[account];
    }

    /* ========== RESTRICTED AML FUNCTIONS ========== */

    /// @notice Set the AML status for an account if it hasn't been set yet
    /// @dev Can only be called by an account with the AML_ADMIN role
    /// @param account The account for which to set the AML status
    /// @param expiryTime The time at which the AML status expires
    /// @param status The AML status to set
    function setAmlStatus(address account, uint256 expiryTime, Status status) public onlyRole(AML_ADMIN) {
        require(amlStatuses[account].expiryTime == 0, "Compliance status already set");
        amlStatuses[account] = AmlStatus(block.timestamp, expiryTime, status);
    }

    /// @notice Update the AML status for an account
    /// @dev Can only be called by an account with the AML_ADMIN role
    /// @param account The account for which to update the AML status
    /// @param expiryTime The time at which the AML status expires
    /// @param status The AML status to set
    function updateAmlStatus(address account, uint256 expiryTime, Status status) public onlyRole(AML_ADMIN) {
        require(amlStatuses[account].expiryTime != 0, "Compliance status not set yet");
        amlStatuses[account] = AmlStatus(block.timestamp, expiryTime, status);
    }

    /**
     * @notice Clear AML status for an account
     * @param account The address of the account
     */
    function clearAmlStatus(address account) public onlyRole(AML_ADMIN) {
        delete amlStatuses[account];
    }

    /* ========== EVENTS ========== */

    event KYCStatusUpdated(address indexed account, bool status, uint64 expiry);
    event AmlStatusUpdated(address indexed account, bool status, uint64 expiry);
}
