import { describe, it } from "node:test";
import { loadFixture } from "../utils/fixture.js";
import { concatHex, toHex } from "viem";

// Random handle with chain id 31337 (0x00007a69) of type uint256 (3) and version 0
const handle = "0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd00007a690300";

describe("[IT] TEEComputeManager", function () {
    it("Should validate handle proof", async function () {
        const { teeComputeManager, wallet1: user, gateway } = await loadFixture();
        const userAddress = user.account.address;
        const appAddress = userAddress; // The caller (app) is the user in this test
        const createdAt = BigInt(Math.floor(Date.now() / 1000)); // in seconds
        const chainId = BigInt(await user.getChainId());

        const domain = {
            name: "TEEComputeManager",
            version: "1",
            chainId,
            verifyingContract: teeComputeManager.address,
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

        const signature = await gateway.signTypedData({
            domain,
            types,
            primaryType: "HandleProof",
            message,
        });
        const proof = concatHex([userAddress, appAddress, toHex(createdAt, { size: 32 }), signature]);
        await teeComputeManager.simulate.validateProof([handle, userAddress, proof, 3], {
            account: user.account,
        }); // TEEType.Uint256
    });
});
