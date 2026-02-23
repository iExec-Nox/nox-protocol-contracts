import { afterEach, beforeEach, describe, it } from "node:test";
import { loadFixture } from "../utils/fixture.ts";
import { OffChainServices } from "../utils/OffChainServicesMock.ts";
import { TEEType } from "../utils/TEEType.ts";

let noxCompute: Awaited<ReturnType<typeof loadFixture>>["noxCompute"];
let user: Awaited<ReturnType<typeof loadFixture>>["wallet1"];
let app: Awaited<ReturnType<typeof loadFixture>>["wallet2"];
let offChainServices: OffChainServices;

describe("[IT] NoxCompute", function () {
    beforeEach(async function () {
        ({ noxCompute, wallet1: user, wallet2: app } = await loadFixture());
        offChainServices = new OffChainServices(noxCompute.address);
        await offChainServices.start();
    });

    afterEach(async function () {
        await offChainServices.stop();
    });

    it("Should validate handle proof", async function () {
        const userAddress = user.account.address;
        const appAddress = app.account.address;
        const client = await offChainServices.createClient(user.account);
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const { handle, handleProof: proof } = await client.encryptInput(0n as any, "uint256", appAddress);
        await noxCompute.write.validateProof(
            [handle as `0x${string}`, userAddress, proof as `0x${string}`, TEEType.Uint256],
            { account: app.account },
        );
    });
});
