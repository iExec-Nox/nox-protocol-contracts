import connection from "./utils/hardhat-connection-singleton.ts";

// Deployment script for ProofValidator.
//
// ProofValidator uses the Nox SDK lib for internal address resolution,
// so it requires no constructor arguments.
//
// Usage: `hardhat run scripts/deploy-proof-validator.ts --network <network-name>`

/**
 * Deploys the ProofValidator contract.
 * @param printLogs whether to print deployment messages or not
 * @returns Viem contract instance for the deployed ProofValidator
 */
export async function deployProofValidator(printLogs = true) {
    const _log = printLogs ? console.log : () => {};
    const { viem } = connection;
    const walletClients = await viem.getWalletClients();

    const deployer = walletClients[0];
    if (!deployer) {
        throw new Error("No deployer wallet available. Set PRIVATE_KEY environment variable.");
    }

    _log(`Network: ${connection.networkName} (chainId: ${connection.networkConfig.chainId})`);
    _log(`Deployer: ${deployer.account.address}`);

    const proofValidator = await viem.deployContract("ProofValidator", []);
    _log(`ProofValidator deployed at: ${proofValidator.address}`);

    return { proofValidator };
}

// Execute the deployment only if the script is run directly.
if (_isHardhatRunCommand()) {
    await deployProofValidator();
}

function _isHardhatRunCommand() {
    return (
        process.argv.length >= 4 &&
        process.argv[2] === "run" &&
        process.argv[3].includes("scripts/deploy-proof-validator.ts")
    );
}
