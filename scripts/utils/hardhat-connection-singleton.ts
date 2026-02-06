import hre from "hardhat";

// Hardhat 3 creates a new NetworkConnection instance on each call to hre.network.connect()
// when working with "edr-simulated" networks. This leads to issues when trying to share the
// same state between the deployment script and tests.
// This ConnectionSingleton ensures that only one instance of NetworkConnection is created
// and shared between the deployment scripts and tests.

// Explicitly connect to the hardhat network if no network is selected
// This is needed for the Node.js test runner which doesn't auto-select a network
const networkName = hre.network?.name ?? "hardhat";
export default await hre.network.connect(networkName);
