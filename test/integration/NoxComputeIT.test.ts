import { describe, it } from "node:test";
import { loadFixture } from "../utils/fixture.ts";
import { Gateway } from "../utils/OffChainServicesMock.ts";
import { TEEType } from "../utils/TEEType.ts";

describe("[IT] NoxCompute", function () {
    it("Should validate handle proof", async function () {
        const { noxCompute, wallet1: user, wallet2: app, gateway } = await loadFixture();
        const offChainServices = new Gateway(noxCompute.address, gateway);
        const userAddress = user.account.address;
        const appAddress = app.account.address; // The caller (app) is the user in this test
        const { handle, proof } = await offChainServices.generateHandle(TEEType.Uint256, userAddress, appAddress);
        await noxCompute.write.validateInputProof([handle, userAddress, proof, TEEType.Uint256], {
            account: app.account,
        });
    });
});
