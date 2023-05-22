// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @title Deployments Contract
 * @notice This contract is used to manage and track the deployment of assets.
 */
contract Deployments {
    struct Deployment {
        uint256 amount; // Amount of assets deployed
        uint32 time; // Timestamp of the deployment
        address assetContract; // Address of the deployed asset's contract
    }

    // Array storing all the asset deployments
    Deployment[] public deployments;

    // Variables to keep track of total amount deployed and the start time of the first deployment
    uint256 public totalDeployed;
    uint32 public deploymentStart;

    /**
     * @dev Sets the deployment start timestamp, can only be set once.
     * @param value The timestamp to be set as the start of the deployment
     */
    function setDeploymentStart(uint32 value) public {
        require(deploymentStart == 0, "Deployment start time can only be set once");
        deploymentStart = value;
    }

    /**
     * @dev Deploys the specified amount of capital at the given time to the given asset contract.
     * @param amount The amount of capital to be deployed
     * @param time The timestamp when the capital is deployed
     * @param assetContract The contract address where the capital will be deployed
     */
    function deployCapital(uint256 amount, uint32 time, address assetContract) public {
        // Create and add the new deployment to the deployments array
        deployments.push(Deployment(amount, time, assetContract));

        // Update the total amount deployed
        totalDeployed += amount;

        // Set the deployment start timestamp, if it's not set yet
        if (deploymentStart == 0) {
            setDeploymentStart(time);
        }
    }
}
