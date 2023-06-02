// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IComplianceRegistry.sol";

/**
 * @title ComplianceRegistry
 * @notice A contract to handle KYC (Know Your Customer) and AML (Anti-Money Laundering) compliance.
 * The contract allows for the verification status of addresses, their KYC and AML compliance status, to be tracked and updated.
 * There are two roles, KYC_ADMIN and AML_ADMIN, responsible for updating the respective statuses.
 * The compliance status of an address expires after a certain time, specified during the status update.
 * An address is considered compliant if it is both KYC and AML compliant and the statuses haven't expired.
 *
 * @dev The contract utilizes AccessControl for role-based permissions.
 * Use initialize function to set KYC_ADMIN and AML_ADMIN roles on deployment.
 */
contract ComplianceRegistry is IComplianceRegistry, Initializable, AccessControlUpgradeable {
    enum Status {
        NonCompliant,
        Compliant
    }

    struct KycStatus {
        uint32 expiryTime;
        Status status;
    }

    struct AmlStatus {
        uint32 expiryTime;
        Status status;
    }

    // Role identifiers for KYC and AML administrators
    bytes32 public constant AML_ADMIN = keccak256("AML_ADMIN");
    bytes32 public constant KYC_ADMIN = keccak256("KYC_ADMIN");

    // Mappings to store the KYC and AML statuses of user accounts
    mapping(address => KycStatus) private kycStatuses;
    mapping(address => AmlStatus) private amlStatuses;

    // Event declarations.
    event KycStatusUpdated(address indexed account, Status indexed status, uint256 expiry);
    event AmlStatusUpdated(address indexed account, Status indexed status, uint256 expiry);

    /* ========== INITIALISATION ========== */

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Assigns roles on contract deployment
     * @dev Grants the KYC_ADMIN role to _kycAdmin and the AML_ADMIN role to _complianceAdmin.
     * @param _kycAdmin Address to be assigned the KYC_ADMIN role
     * @param _complianceAdmin Address to be assigned the AML_ADMIN role
     */
    function initialize(address _kycAdmin, address _complianceAdmin) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(KYC_ADMIN, _kycAdmin);
        _setupRole(AML_ADMIN, _complianceAdmin);
    }

    /* ========== READ-ONLY FUNCTIONS ========== */

    /**
     * @notice Check if a user account is compliant with both KYC and AML requirements.
     * @param account Address of the user account
     * @return True if the user account is KYC and AML compliant, false otherwise
     */
    function isCompliant(address account) public view returns (bool) {
        return isKycCompliant(account) && isAmlCompliant(account);
    }

    /**
     * @notice Check if a user account is KYC compliant.
     * @param account Address of the user account
     * @return True if the user account is KYC compliant, false otherwise
     */
    function isKycCompliant(address account) public view returns (bool) {
        KycStatus memory status = kycStatuses[account];
        return status.status == Status.Compliant && block.timestamp < status.expiryTime;
    }

    /**
     * @notice Check if a user account is AML compliant.
     * @param account Address of the user account
     * @return True if the user account is AML compliant, false otherwise
     */
    function isAmlCompliant(address account) public view returns (bool) {
        AmlStatus memory status = amlStatuses[account];
        return status.status == Status.Compliant && block.timestamp < status.expiryTime;
    }

    /* ========== RESTRICTED KYC FUNCTIONS ========== */

    /**
     * @notice Sets the KYC status for a user account if it has not been set before.
     * @dev Requires the sender to have the KYC_ADMIN role.
     * @param account Address of the user account
     * @param expiryTime Timestamp when the KYC status expires
     * @param status The KYC compliance status to set
     */
    function setKycStatus(address account, uint32 expiryTime, Status status) public onlyRole(KYC_ADMIN) {
        require(kycStatuses[account].expiryTime == 0, "KYC status already set");
        kycStatuses[account] = KycStatus(expiryTime, status);
        emit KycStatusUpdated(account, status, expiryTime);
    }

    /**
     * @notice Updates the KYC status for a user account.
     * @dev Requires the sender to have the KYC_ADMIN role.
     * @param account Address of the user account
     * @param expiryTime Timestamp when the KYC status expires
     * @param status The updated KYC compliance status
     */
    function updateKycStatus(address account, uint32 expiryTime, Status status) public onlyRole(KYC_ADMIN) {
        require(kycStatuses[account].expiryTime != 0, "KYC status not set yet");
        kycStatuses[account] = KycStatus(expiryTime, status);
        emit KycStatusUpdated(account, status, expiryTime);
    }

    /**
     * @notice Clears the KYC status for a user account.
     * @dev Requires the sender to have the KYC_ADMIN role.
     * @param account Address of the user account
     */
    function clearKycStatus(address account) public onlyRole(KYC_ADMIN) {
        delete kycStatuses[account];
        emit KycStatusUpdated(account, Status.NonCompliant, 0);
    }

    /* ========== RESTRICTED AML FUNCTIONS ========== */

    /**
     * @notice Sets the AML status for a user account if it has not been set before.
     * @dev Requires the sender to have the AML_ADMIN role.
     * @param account Address of the user account
     * @param expiryTime Timestamp when the AML status expires
     * @param status The AML compliance status to set
     */
    function setAmlStatus(address account, uint32 expiryTime, Status status) public onlyRole(AML_ADMIN) {
        require(amlStatuses[account].expiryTime == 0, "AML status already set");
        amlStatuses[account] = AmlStatus(expiryTime, status);
        emit AmlStatusUpdated(account, status, expiryTime);
    }

    /**
     * @notice Updates the AML status for a user account.
     * @dev Requires the sender to have the AML_ADMIN role.
     * @param account Address of the user account
     * @param expiryTime Timestamp when the AML status expires
     * @param status The updated AML compliance status
     */
    function updateAmlStatus(address account, uint32 expiryTime, Status status) public onlyRole(AML_ADMIN) {
        require(amlStatuses[account].expiryTime != 0, "AML status not set yet");
        amlStatuses[account] = AmlStatus(expiryTime, status);
        emit AmlStatusUpdated(account, status, expiryTime);
    }

    /**
     * @notice Clears the AML status for a user account.
     * @dev Requires the sender to have the AML_ADMIN role.
     * @param account Address of the user account
     */
    function clearAmlStatus(address account) public onlyRole(AML_ADMIN) {
        delete amlStatuses[account];
        emit AmlStatusUpdated(account, Status.NonCompliant, 0);
    }
}
