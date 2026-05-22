// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {NoxCompute} from "../../contracts/NoxCompute.sol";
import {INoxCompute} from "../../contracts/interfaces/INoxCompute.sol";
import {TEEType} from "../../contracts/utils/TypeUtils.sol";
import {TestHelper} from "../utils/TestHelper.sol";

// TODO
contract NoxCompute_PaymentTest is Test {
    address owner = makeAddr("owner");
    address gateway = vm.addr(123456789);
    NoxCompute noxCompute;

    address app = makeAddr("app");
    address sponsor = makeAddr("sponsor");
    address licenseOwner = makeAddr("licenseOwner");

    function setUp() public {
        noxCompute = TestHelper.deploy(owner, gateway, 1);
        vm.label(app, "app");
        vm.label(sponsor, "sponsor");
        vm.label(licenseOwner, "licenseOwner");
    }
}
