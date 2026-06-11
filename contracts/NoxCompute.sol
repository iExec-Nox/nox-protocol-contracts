// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Admin} from "./modules/Admin.sol";
import {ACL} from "./modules/ACL.sol";
import {Compute} from "./modules/Compute.sol";

/**
 * @title NoxCompute
 * @notice The entry point contract for the Nox TEE compute protocol.
 * It's role includes:
 * - Managing the access control list (ACL) for encrypted handles
 * - Validating handle proofs issued by a trusted gateway
 * - Wrapping plaintext values into public handles
 * - Triggering off-chain TEE computations through event emissions
 */
contract NoxCompute is Admin, ACL, Compute {
    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() EIP712("NoxCompute", "1") {
        _disableInitializers();
    }

    /**
     * Initializes the proxy contract state for a fresh deployment.
     * @param admin Address granted `DEFAULT_ADMIN_ROLE`.
     * @param upgrader Address granted `UPGRADER_ROLE`.
     * @param kmsPublicKey KMS public key for ECIES encryption.
     * @param gateway Gateway wallet address.
     */
    function initialize(
        address admin,
        address upgrader,
        bytes calldata kmsPublicKey,
        address gateway
    ) public initializer {
        // v0.1.0
        _setKmsPublicKey(kmsPublicKey);
        _setGateway(gateway);
        _setProofExpirationDuration(1 hours);
        // v0.2.0
        _emitZeroHandleSeeds();
        // v0.2.3
        _initAccessControl(admin, upgrader);
    }

    /**
     * @notice Initializer of 0.X.Y upgrade for already deployed proxies.
     */
    function initializeV4() public reinitializer(4) {}
}
