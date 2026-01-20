import { describe, it } from "node:test";
import { loadFixture } from "../utils/fixture.js";
import { concatHex, toHex } from "viem";

const handle = "0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd";

describe("[IT] TEEComputeManager", function () {
    it("Should validate input proof", async function () {
        const { teeComputeManager, wallet1: user } = await loadFixture();
        const userAddress = user.account.address;
        const aclAddress = await teeComputeManager.read.acl();
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
                { name: "acl", type: "address" },
                { name: "createdAt", type: "uint256" },
            ],
        } as const;
        const message = {
            handle,
            owner: userAddress,
            acl: aclAddress,
            createdAt,
        } as const;

        const signature = await user.signTypedData({
            domain,
            types,
            primaryType: "HandleProof",
            message,
        });
        // Construct proof
        // proof = owner || ACL || createdAt || EIP712Signature (65 bytes)
        //          20      20       32                    65
        const proof = concatHex([userAddress, aclAddress, toHex(createdAt, { size: 32 }), signature]);
        await teeComputeManager.read.validateProof([handle, userAddress, proof]);
    });
});
