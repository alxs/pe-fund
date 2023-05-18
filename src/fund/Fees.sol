// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @title Fee Management
 * @dev This contract is for managing fees. It stores fee details and allows
 * for the addition of fee requests to a historical log.
 */
contract Fees {
    // Fee structure details
    uint256 public prefRate;
    uint8 public compoundingInterval;
    uint8 public gpClawback;
    uint8 public carriedInterest;
    uint8 public managementFee;

    // Structure to hold the fee request details
    struct FeeRequest {
        uint8 fee;
        uint64 time;
    }

    // Array to store the history of fee requests
    FeeRequest[] public feeHistory;

    /**
     * @notice Initializes the contract with initial fee details
     * @dev This constructor takes in parameters to initialize the fee structure.
     * @param _prefRate Preferred Rate
     * @param _compoundingInterval Compounding Interval
     * @param _gpClawback GP Clawback
     * @param _carriedInterest Carried Interest
     * @param _managementFee Management Fee
     */
    constructor(
        uint256 _prefRate,
        uint8 _compoundingInterval,
        uint8 _gpClawback,
        uint8 _carriedInterest,
        uint8 _managementFee
    ) {
        prefRate = _prefRate;
        compoundingInterval = _compoundingInterval;
        gpClawback = _gpClawback;
        carriedInterest = _carriedInterest;
        managementFee = _managementFee;
    }

    /**
     * @notice Returns the current preferred rate
     * @return The current preferred rate
     */
    function getPrefRate() public view returns (uint256) {
        return prefRate;
    }

    /**
     * @notice Returns the current compounding interval
     * @return The current compounding interval
     */
    function getCompoundingInterval() public view returns (uint8) {
        return compoundingInterval;
    }

    /**
     * @notice Updates the preferred rate
     * @dev Only accessible internally
     * @param _prefRate The new preferred rate to be set
     */
    function _setPrefRate(uint256 _prefRate) internal {
        prefRate = _prefRate;
    }

    /**
     * @notice Updates the compounding interval
     * @dev Only accessible internally
     * @param _compoundingInterval The new compounding interval to be set
     */
    function _setCompoundingInterval(uint8 _compoundingInterval) internal {
        compoundingInterval = _compoundingInterval;
    }

    /**
     * @notice Updates the GP Clawback rate
     * @dev Only accessible internally
     * @param _gpClawback The new GP Clawback rate to be set
     */
    function _setGPClawback(uint8 _gpClawback) internal {
        gpClawback = _gpClawback;
    }

    /**
     * @notice Updates the carried interest rate
     * @dev Only accessible internally
     * @param _carriedInterest The new carried interest rate to be set
     */
    function _setCarriedInterest(uint8 _carriedInterest) internal {
        carriedInterest = _carriedInterest;
    }

    /**
     * @notice Updates the management fee
     * @dev Only accessible internally
     * @param _managementFee The new management fee to be set
     */
    function _setManagementFee(uint8 _managementFee) internal {
        managementFee = _managementFee;
    }

    /**
     * @notice Adds a new fee request to the history
     * @dev Creates a new FeeRequest instance and adds it to the feeHistory array.
     *      Only accessible internally
     * @param fee The fee to add
     * @param time The time of the fee request
     * @return count The current count of fee requests after the new addition
     */
    function addFeeRequest(uint8 fee, uint64 time) internal returns (uint256 count) {
        FeeRequest memory newFeeRequest = FeeRequest({fee: fee, time: time});
        feeHistory.push(newFeeRequest);
        return feeHistory.length;
    }
}
