import { describe, it } from "node:test";
import { loadFixture } from "../utils/fixture.js";
import { OffChainServices } from "./OffChainServicesMock.js";

describe("[IT] TEEComputeManager", function () {
    it("Should validate handle proof", async function () {
        const { teeComputeManager, wallet1: user, wallet2: app, gateway } = await loadFixture();
        const offChainServices = new OffChainServices(teeComputeManager.address, gateway);
        const userAddress = user.account.address;
        const appAddress = app.account.address; // The caller (app) is the user in this test
        const uint256Type = 3;
        const { handle, proof } = await offChainServices.generateHandle(uint256Type, userAddress, appAddress);
        await teeComputeManager.write.validateProof([handle, userAddress, proof, uint256Type], {
            account: app.account,
        });
    });
});
