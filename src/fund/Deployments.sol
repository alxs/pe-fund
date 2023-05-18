// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @title Deployments
 * @dev The Deployments contract has an initializer and functions to manage deployments.
 */
contract Deployments {

    // Struct to store deployment details
    struct Deployment {
        uint256 amount;
        uint64 time;
        address assetContract;
    }

    // Array to store deployments
    Deployment[] private deployments;

    // Internal variables for total deployed and deployment start
    uint256 private totalDeployed;
    uint64 private deploymentStart;

    /**
     * @dev Initializes the contract setting the initial deployments to zero.
     */
    function init() public {

    }

    /**
     * @dev Sets the deployment start.
     * @param value The value to set
     */
    function setDeploymentStart(uint64 value) public {
        require(deploymentStart == 0, "Deployment start already set");
        deploymentStart = value;
    }

    /**
     * @dev Deploys the capital.
     * @param amount The amount to deploy
     * @param time The timestamp of deployment
     * @param assetContract The address of the asset contract
     */
    function deployCapital(uint256 amount, uint64 time, address assetContract) public {
        // Add the deployment
        deployments.push(Deployment(amount, time, assetContract));

        // Update the total
        totalDeployed = totalDeployed + amount;
        setDeploymentStart(time);
    }
}
