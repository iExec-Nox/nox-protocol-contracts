import { after, beforeEach, describe, it } from "node:test";
import assert from "node:assert";
import { zeroHash } from "viem";
import { loadFixture } from "../utils/fixture.js";
import connection from "../../scripts/utils/hardhat-connection-singleton.js";
import { OffChainServices } from "./OffChainServicesMock.js";

let teeComputeManager: Awaited<ReturnType<typeof loadFixture>>["teeComputeManager"];
let admin: Awaited<ReturnType<typeof loadFixture>>["admin"];
let user: Awaited<ReturnType<typeof loadFixture>>["wallet1"];
let gateway: Awaited<ReturnType<typeof loadFixture>>["gateway"];
let offChainServices: OffChainServices;
let client: Awaited<ReturnType<typeof connection.viem.getPublicClient>>;

describe.only("[IT] ConfidentialToken", function () {
    beforeEach(async function () {
        ({ teeComputeManager, admin, wallet1: user, gateway } = await loadFixture());
        // Start the off-chain services mock.
        offChainServices = new OffChainServices(teeComputeManager.address, gateway, await admin.getChainId());
        await offChainServices.start();
        client = await connection.viem.getPublicClient();
    });

    after(async function () {
        // Make sure tests always exit even if something fails.
        await offChainServices.stop();
    });

    it("Should transfer tokens between two addresses", async function () {
        //
        // Deploy the ConfidentialTokenMock contract.
        //
        const totalSupply = 1_000_000_000n;
        const confidentialTokenMock = await connection.viem.deployContract("ConfidentialTokenMock", [
            totalSupply,
            teeComputeManager.address,
        ]);
        await offChainServices.waitForEventProcessing();
        //
        // Check initial balances
        //
        const initialTotalSupply = await confidentialTokenMock.read.confidentialTotalSupply();
        const initialAdminBalance = await confidentialTokenMock.read.confidentialBalanceOf([admin.account.address]);
        const initialUserBalance = await confidentialTokenMock.read.confidentialBalanceOf([user.account.address]);
        assert.equal(offChainServices.decrypt(initialTotalSupply), totalSupply);
        assert.equal(offChainServices.decrypt(initialAdminBalance), totalSupply);
        assert.equal(initialUserBalance, zeroHash); // User balance not defined yet.
        //
        // Transfer some tokens from admin to user
        //
        const amount = 1000n;
        const { handle, proof } = await offChainServices.createHandleAndProof(
            amount,
            3, // TEEType.uint256
            admin.account.address,
            confidentialTokenMock.address,
        );
        const txHash = await confidentialTokenMock.write.confidentialTransfer([user.account.address, handle, proof], {
            account: admin.account,
        });
        await offChainServices.waitForEventProcessing();
        // Check balances after transfer.
        const finalTotalSupply = await confidentialTokenMock.read.confidentialTotalSupply();
        const finalAdminBalance = await confidentialTokenMock.read.confidentialBalanceOf([admin.account.address]);
        const finalUserBalance = await confidentialTokenMock.read.confidentialBalanceOf([user.account.address]);
        assert.equal(offChainServices.decrypt(finalTotalSupply), totalSupply);
        assert.equal(offChainServices.decrypt(finalUserBalance), amount);
        assert.equal(offChainServices.decrypt(finalAdminBalance), totalSupply - amount);
    });
});
