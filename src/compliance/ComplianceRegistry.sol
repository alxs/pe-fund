// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ComplianceRegistry Contract
 * @notice Manages the Know Your Customer (KYC) and Anti-Money Laundering (AML) compliance status for user accounts.
 */
contract ComplianceRegistry is AccessControl {
    // Compliance statuses
    enum Status {
        NonCompliant,
        Compliant
    }

    // KYC status includes start time, expiry time, and compliance status
    struct KycStatus {
        uint256 startTime;
        uint256 expiryTime;
        Status status;
    }

    // AML status includes start time, expiry time, and compliance status
    struct AmlStatus {
        uint256 startTime;
        uint256 expiryTime;
        Status status;
    }

    // Role identifiers for KYC and AML administrators
    bytes32 public constant AML_ADMIN = keccak256("AML_ADMIN");
    bytes32 public constant KYC_ADMIN = keccak256("KYC_ADMIN");

    // Mappings to store the KYC and AML statuses of user accounts
    mapping(address => KycStatus) private kycStatuses;
    mapping(address => AmlStatus) private amlStatuses;

    /**
     * @notice Assigns roles on contract deployment
     * @param _kycAdmin The address to assign the KYC_ADMIN role
     * @param _complianceAdmin The address to assign the AML_ADMIN role
     */
    constructor(address _kycAdmin, address _complianceAdmin) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(KYC_ADMIN, _kycAdmin);
        _setupRole(AML_ADMIN, _complianceAdmin);
    }

    /* ========== VIEW FUNCTIONS ========== */

    /**
     * @notice Determines if a user account is compliant with both KYC and AML requirements.
     * @param account The address of the user account
     * @return True if the user account is KYC and AML compliant, false otherwise
     */
    function isCompliant(address account) public view returns (bool) {
        return isKycCompliant(account) && isAmlCompliant(account);
    }

    /**
     * @notice Determines if a user account is KYC compliant.
     * @param account The address of the user account
     * @return True if the user account is KYC compliant, false otherwise
     */
    function isKycCompliant(address account) public view returns (bool) {
        KycStatus memory status = kycStatuses[account];
        return status.status == Status.Compliant && block.timestamp < status.expiryTime;
    }

    /**
     * @notice Determines if a user account is AML compliant.
     * @param account The address of the user account
     * @return True if the user account is AML compliant, false otherwise
     */
    function isAmlCompliant(address account) public view returns (bool) {
        AmlStatus memory status = amlStatuses[account];
        return status.status == Status.Compliant && block.timestamp < status.expiryTime;
    }

    /* ========== RESTRICTED KYC FUNCTIONS ========== */

    /**
     * @notice Sets the KYC status for a user account if it has not been set before.
     * @dev Accessible only by an account with the KYC_ADMIN role.
     * @param account The address of the user account
     *
     * @param expiryTime The timestamp when the KYC status expires
     * @param status The KYC compliance status to set
     */
    function setKycStatus(address account, uint256 expiryTime, Status status) public onlyRole(KYC_ADMIN) {
        require(kycStatuses[account].expiryTime == 0, "KYC status already set");
        kycStatuses[account] = KycStatus(block.timestamp, expiryTime, status);
    }

    /**
     * @notice Updates the KYC status for a user account.
     * @dev Accessible only by an account with the KYC_ADMIN role.
     * @param account The address of the user account
     * @param expiryTime The timestamp when the KYC status expires
     * @param status The updated KYC compliance status
     */
    function updateKycStatus(address account, uint256 expiryTime, Status status) public onlyRole(KYC_ADMIN) {
        require(kycStatuses[account].expiryTime != 0, "KYC status not set yet");
        kycStatuses[account] = KycStatus(block.timestamp, expiryTime, status);
    }

    /**
     * @notice Clears the KYC status for a user account.
     * @dev Accessible only by an account with the KYC_ADMIN role.
     * @param account The address of the user account
     */
    function clearKycStatus(address account) public onlyRole(KYC_ADMIN) {
        delete kycStatuses[account];
    }

    /* ========== RESTRICTED AML FUNCTIONS ========== */

    /**
     * @notice Sets the AML status for a user account if it has not been set before.
     * @dev Accessible only by an account with the AML_ADMIN role.
     * @param account The address of the user account
     * @param expiryTime The timestamp when the AML status expires
     * @param status The AML compliance status to set
     */
    function setAmlStatus(address account, uint256 expiryTime, Status status) public onlyRole(AML_ADMIN) {
        require(amlStatuses[account].expiryTime == 0, "AML status already set");
        amlStatuses[account] = AmlStatus(block.timestamp, expiryTime, status);
    }

    /**
     * @notice Updates the AML status for a user account.
     * @dev Accessible only by an account with the AML_ADMIN role.
     * @param account The address of the user account
     * @param expiryTime The timestamp when the AML status expires
     * @param status The updated AML compliance status
     */
    function updateAmlStatus(address account, uint256 expiryTime, Status status) public onlyRole(AML_ADMIN) {
        require(amlStatuses[account].expiryTime != 0, "AML status not set yet");
        amlStatuses[account] = AmlStatus(block.timestamp, expiryTime, status);
    }

    /**
     * @notice Clears the AML status for a user account.
     * @dev Accessible only by an account with the AML_ADMIN role.
     * @param account The address of the user account
     */
    function clearAmlStatus(address account) public onlyRole(AML_ADMIN) {
        delete amlStatuses[account];
    }

    /* ========== EVENTS ========== */

    // Emitted when the KYC status of an account has been updated
    event KYCStatusUpdated(address indexed account, bool status, uint64 expiry);

    // Emitted when the AML status of an account has been updated
    event AmlStatusUpdated(address indexed account, bool status, uint64 expiry);
}
