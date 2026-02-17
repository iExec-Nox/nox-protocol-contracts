import connection from "./hardhat-connection-singleton.ts";

/**
 * Returns true only for a fresh local network (edr-simulated without forking).
 * Forked networks already have contracts deployed, so they should read from artifacts.
 */
export function isFreshLocalNetwork(): boolean {
    const networkConfig = connection.networkConfig;
    return networkConfig.type === "edr-simulated" && !("fork" in networkConfig);
}
