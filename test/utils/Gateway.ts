// A stub to simulate the Gateway.

import { randomBytes } from "crypto";
import connection from "../../scripts/utils/hardhat-connection-singleton.ts";
import { concatHex, PrivateKeyAccount, toHex } from "viem";
import { TEEType } from "./TEEType.ts";

const client = await connection.viem.getPublicClient();

export class Gateway {
    private noxComputeAddress: `0x${string}`;
    private gatewayAccount: PrivateKeyAccount;

    constructor(noxComputeAddress: `0x${string}`, gatewayAccount: PrivateKeyAccount) {
        this.noxComputeAddress = noxComputeAddress;
        this.gatewayAccount = gatewayAccount;
    }

    /**
     * Generates a random handle and its proof.
     */
    async generateHandle(
        teeType: TEEType,
        userAddress: `0x${string}`,
        appAddress: `0x${string}`,
    ): Promise<{ handle: `0x${string}`; proof: `0x${string}` }> {
        const chainId = client.chain.id;
        const versionByte = toHex(0, { size: 1 });
        const chainIdBytes = toHex(chainId, { size: 4 });
        const teeTypeByte = toHex(teeType, { size: 1 });
        const attributesByte = toHex(0x01, { size: 1 }); // isUniqueHandle=1
        const preHandle = toHex(randomBytes(25));
        const handle = concatHex([versionByte, chainIdBytes, teeTypeByte, attributesByte, preHandle]);
        const createdAt = BigInt(Math.floor(Date.now() / 1000)); // in seconds
        const domain = {
            name: "NoxCompute",
            version: "1",
            chainId,
            verifyingContract: this.noxComputeAddress,
        } as const;
        const types = {
            HandleProof: [
                { name: "handle", type: "bytes32" },
                { name: "owner", type: "address" },
                { name: "app", type: "address" },
                { name: "createdAt", type: "uint256" },
            ],
        } as const;
        const message = {
            handle,
            owner: userAddress,
            app: appAddress,
            createdAt,
        } as const;
        const signature = await this.gatewayAccount.signTypedData({
            domain,
            types,
            primaryType: "HandleProof",
            message,
        });
        const proof = concatHex([userAddress, appAddress, toHex(createdAt, { size: 32 }), signature]);
        return { handle, proof };
    }
}
