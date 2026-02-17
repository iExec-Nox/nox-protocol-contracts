import { readFile } from "fs/promises";
import { join } from "path";
import connection from "./hardhat-connection-singleton.ts";

/**
 * Reads the deployed contract addresses from ignition deployment artifacts.
 * @returns A record of contract identifiers to their deployed addresses
 */
export async function readDeployedAddresses(): Promise<Record<string, string>> {
    const deploymentPath = join(
        process.cwd(),
        "ignition",
        "deployments",
        connection.networkName,
        "deployed_addresses.json",
    );

    try {
        const content = await readFile(deploymentPath, "utf-8");
        return JSON.parse(content);
    } catch {
        throw new Error(
            `Failed to read deployment artifacts at ${deploymentPath}. ` +
                `Make sure contracts are deployed on ${connection.networkName}.`,
        );
    }
}

/**
 * Reads the deployed address for a specific contract key from ignition deployment artifacts.
 * @param key The contract key (e.g., "ACL#proxy", "NoxCompute#proxy")
 * @returns The deployed address
 */
export async function readDeployedAddress(key: string): Promise<string> {
    const deployedAddresses = await readDeployedAddresses();
    const address = deployedAddresses[key];
    if (!address) {
        throw new Error(`${key} not found in deployment artifacts`);
    }
    return address;
}
