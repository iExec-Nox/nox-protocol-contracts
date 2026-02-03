import { describe, it } from "node:test";
import { loadFixture } from "../utils/fixture.js";
import { OffChainServices } from "../utils/OffChainServicesMock.js";
import { TEEType } from "../utils/TEEType.js";

describe("[IT] TEEComputeManager", function () {
    it("Should validate handle proof", async function () {
        const { teeComputeManager, wallet1: user, wallet2: app, gateway } = await loadFixture();
        // TODO create OffChainServices inside loadFixture.
        const offChainServices = new OffChainServices(teeComputeManager.address, gateway);
        const userAddress = user.account.address;
        const appAddress = app.account.address; // The caller (app) is the user in this test
        const { handle, proof } = await offChainServices.generateHandle(TEEType.Uint256, userAddress, appAddress);
        await teeComputeManager.write.validateProof([handle, userAddress, proof, TEEType.Uint256], {
            account: app.account,
        });
    });
});
