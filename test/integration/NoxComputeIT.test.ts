import { describe, it } from "node:test";

import { loadFixture } from "../utils/fixture.ts";
import { Gateway } from "../utils/Gateway.ts";
import { TEEType } from "../utils/TEEType.ts";

describe("[IT] NoxCompute", function () {
    it("Should validate handle proof", async function () {
        const { noxCompute, wallet1: user, wallet2: app, gateway: gatewayAccount } = await loadFixture();
        const gateway = new Gateway(noxCompute.address, gatewayAccount);
        const userAddress = user.account.address;
        const appAddress = app.account.address; // The caller (app) is the user in this test
        const { handle, proof } = await gateway.generateHandle(TEEType.Uint256, userAddress, appAddress);
        await noxCompute.write.validateInputProof([handle, userAddress, proof, TEEType.Uint256], {
            account: app.account,
        });
    });
});
