import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { encodeAbiParameters, keccak256, padHex, toHex } from "viem";
import { loadFixture } from "../utils/fixture.ts";
import connection from "../../scripts/utils/hardhat-connection-singleton.ts";

// TODO rename to NoxCompute.test.ts.
describe("NoxCompute", function () {
    describe("Transient & Persistent permissions", function () {
        it("Should clear transient permissions after transaction while persistent remain", async function () {
            const { wallet1 } = await loadFixture();
            const viem = connection.viem;
            // Deploy NoxComputeMock
            const noxComputeMock = await viem.deployContract("NoxComputeMock", []);
            const handleTransient = keccak256(toHex("handle-transient"));
            const handlePersistent = keccak256(toHex("handle-persistent"));
            // Force-allow the mock contract to manage handles by putting `true` in the admins mapping.
            await _allow(noxComputeMock.address, handleTransient);
            await _allow(noxComputeMock.address, handlePersistent);
            // Single transaction: Grant transient to one handle and persistent to another (same account)
            await noxComputeMock.write.grantTransientAndPersistent([
                handleTransient,
                handlePersistent,
                wallet1.account.address,
            ]);
            // Mine a new block to further verify persistence
            await connection.networkHelpers.mine();
            // New transaction: Check permissions - transient should be gone, persistent should remain
            const isAllowedTransient = await noxComputeMock.read.isAllowed([handleTransient, wallet1.account.address]);
            const isAllowedPersistent = await noxComputeMock.read.isAllowed([
                handlePersistent,
                wallet1.account.address,
            ]);
            assert.strictEqual(isAllowedTransient, false, "Transient permission should be cleared after tx");
            assert.strictEqual(isAllowedPersistent, true, "Persistent permission should remain");
        });
    });
});

async function _allow(account: `0x${string}`, handle: `0x${string}`) {
    const adminsMappingStorageLocation = "0x118a408ef9c0c38d6620cca4d300c2ce1c4f4cbcd93520940a6461e96acdcd00";
    // mapping(bytes32 key1 => mapping(key2 => bool)) map;
    // outer = keccak256(abi.encode(key1, position of map));
    // slot = keccak256(abi.encode(key2, outer));
    const outerKeyStorageLocation = keccak256(
        encodeAbiParameters([{ type: "bytes32" }, { type: "bytes32" }], [handle, adminsMappingStorageLocation]),
    );
    const slotLocation = keccak256(
        encodeAbiParameters([{ type: "address" }, { type: "bytes32" }], [account, outerKeyStorageLocation]),
    );
    await connection.networkHelpers.setStorageAt(account, slotLocation, padHex("0x01", { size: 32 }));
}
