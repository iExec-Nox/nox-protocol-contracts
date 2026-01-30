import { after, describe, it } from "node:test";
import assert from "node:assert";
import { concatHex, toHex } from "viem";
import { loadFixture } from "../utils/fixture.js";
import connection from "../../scripts/utils/hardhat-connection-singleton.js";
import { createHandleAndProof, start, stop } from "./OffChainServicesMock.js";

// Random handle with chain id 31337 (0x00007a69) of type uint256 (3) and version 0
const handle = "0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd00007a690300";

describe.only("[e2e] ConfidentialToken", function () {
    after(async function () {
        await stop();
    });

    it("Should transfer tokens between two addresses", async function () {
        const { teeComputeManager, admin, wallet1: user, gateway } = await loadFixture();
        const client = await connection.viem.getPublicClient();
        // Start the mock gateway service here.
        await start(teeComputeManager.address);
        const confidentialTokenMock = await connection.viem.deployContract("ConfidentialTokenMock", [
            teeComputeManager.address,
        ]);
        const initialAdminBalance = await confidentialTokenMock.read.confidentialBalanceOf([admin.account.address]);
        const totalSupply = await confidentialTokenMock.read.confidentialTotalSupply();
        console.log("Total supply:", totalSupply);
        assert.equal(totalSupply, "0x00000000000000000000000000000000000000000000000f424000007a690300");
        console.log("Initial balance:", initialAdminBalance);
        assert.equal(initialAdminBalance, "0x00000000000000000000000000000000000000000000000f424000007a690300");
        const initialUserBalance = await confidentialTokenMock.read.confidentialBalanceOf([user.account.address]);
        console.log("Initial user balance:", initialUserBalance);
        assert.equal(initialUserBalance, toHex(0, { size: 32 }));
        // Transfer some tokens from admin to user
        const { handle, proof } = await createHandleAndProof(
            1000,
            3,
            await admin.getChainId(),
            admin.account.address,
            confidentialTokenMock.address,
            gateway,
            teeComputeManager.address,
        );
        const tx = await confidentialTokenMock.write.confidentialTransfer([user.account.address, handle, proof], {
            account: admin.account,
        });
        await client.waitForTransactionReceipt({ hash: tx });
        const finalAdminBalance = await confidentialTokenMock.read.confidentialBalanceOf([admin.account.address]);
        const finalUserBalance = await confidentialTokenMock.read.confidentialBalanceOf([user.account.address]);
        // assert.equal(decrypt(finalAdminBalance), 1_000_000_000 - 1000);
        // assert.equal(decrypt(finalUserBalance), 1000);
        // await stop();
    });
});
