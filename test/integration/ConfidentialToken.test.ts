import { describe, it } from "node:test";
import { loadFixture } from "../utils/fixture.js";
import { concatHex, toHex } from "viem";
import connection from "../../scripts/utils/hardhat-connection-singleton.js";
import assert from "node:assert";

// Random handle with chain id 31337 (0x00007a69) of type uint256 (3) and version 0
const handle = "0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd00007a690300";

describe("[e2e] ConfidentialToken", function () {
    it("Should transfer tokens between two addresses", async function () {
        const { teeComputeManager, admin, wallet1: user, gateway } = await loadFixture();
        const confidentialTokenMock = await connection.viem.deployContract("ConfidentialTokenMock", [
            teeComputeManager.address,
        ]);
        const initialAdminBalance = await confidentialTokenMock.read.confidentialBalanceOf([admin.account.address]);
        const totalSupply = await confidentialTokenMock.read.confidentialTotalSupply();
        console.log("Total supply:", totalSupply);
        assert.equal(totalSupply, "0x8feb32af145f911a6dedaec518831684917b0d1f72db724025ec131a587ed576");
        console.log("Initial balance:", initialAdminBalance);
        assert.equal(initialAdminBalance, "0x8feb32af145f911a6dedaec518831684917b0d1f72db724025ec131a587ed576");
        const initialUserBalance = await confidentialTokenMock.read.confidentialBalanceOf([user.account.address]);
        console.log("Initial user balance:", initialUserBalance);
        assert.equal(initialUserBalance, toHex(0, { size: 32 }));
    });
});
