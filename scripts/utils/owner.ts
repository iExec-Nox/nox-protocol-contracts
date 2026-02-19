import { parseEther } from "viem";
import config from "../../config/config.ts";
import connection from "./hardhat-connection-singleton.ts";
import { isLocalNetwork } from "./network.ts";

/**
 * Prepares the owner account for script execution and returns the owner address.
 * - On non-local networks with requireWallet: validates a wallet client is available (PRIVATE_KEY is set).
 * - On local EDR networks: impersonates the owner account and funds it with test ETH.
 */
export async function prepareOwner({
    requireWallet = false,
}: { requireWallet?: boolean } = {}): Promise<`0x${string}`> {
    const chainConfig = config[connection.networkName];
    const owner = chainConfig.initialOwner as `0x${string}`;

    if (!isLocalNetwork() && requireWallet) {
        const walletClients = await connection.viem.getWalletClients();
        if (!walletClients[0]) {
            throw new Error("No owner wallet available. Set PRIVATE_KEY environment variable.");
        }
    }

    if (isLocalNetwork()) {
        await connection.networkHelpers.impersonateAccount(owner);
        await connection.networkHelpers.setBalance(owner, parseEther("1000"));
    }

    return owner;
}
