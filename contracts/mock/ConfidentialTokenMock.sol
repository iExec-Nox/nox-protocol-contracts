// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "encrypted-types/EncryptedTypes.sol";
import {TEEPrimitives} from "../lib/TEEPrimitives.sol";

// TODO remove this interface and use @openzeppelin/contracts when the rest
// of the functions are implemented.

/**
 * Partial definition of the ERC7984 interface.
 */
interface IERC7984 {
    event ConfidentialTransfer(address indexed from, address indexed to, euint256 indexed amount);

    function confidentialTotalSupply() external view returns (euint256);
    function confidentialBalanceOf(address account) external view returns (euint256);
    function confidentialTransfer(
        address to,
        externalEuint256 encryptedAmount,
        bytes calldata inputProof
    ) external returns (euint256);
    function confidentialTransfer(
        address to,
        euint256 amount
    ) external returns (euint256 transferred);
}

/**
 * A mock client contract to simulate client interactions with
 * the Nox protocol contracts.
 */
contract ConfidentialTokenMock is IERC7984 {
    mapping(address holder => euint256) private _balances;
    euint256 private _totalSupply;

    constructor(address teeComputeManager) {
        TEEPrimitives.setNoxConfig(teeComputeManager);
        _totalSupply = TEEPrimitives.toEuint256(1_000_000);
        _balances[msg.sender] = _totalSupply;
    }

    function confidentialTotalSupply() public view override returns (euint256) {
        return _totalSupply;
    }

    function confidentialBalanceOf(address account) public view override returns (euint256) {
        return _balances[account];
    }

    function confidentialTransfer(
        address to,
        externalEuint256 amountHandle,
        bytes calldata handleProof
    ) public override returns (euint256) {
        return _transfer(msg.sender, to, TEEPrimitives.fromExternal(amountHandle, handleProof));
    }

    function confidentialTransfer(address to, euint256 amount) public override returns (euint256) {
        require(TEEPrimitives.isAllowed(amount, msg.sender), "Not allowed");
        return _transfer(msg.sender, to, amount);
    }

    function _transfer(address from, address to, euint256 amount) internal returns (euint256) {
        require(from != address(0), "Zero from address");
        require(to != address(0), "Zero to address");
        // Try to decrease balance of `from`.
        // `result` will have the same value as `_balances[from]` if subtraction fails.
        (ebool success, euint256 result) = TEEPrimitives.safeSub(_balances[from], amount);
        _balances[from] = result;
        TEEPrimitives.allowThis(result);
        TEEPrimitives.allow(result, from);
        // If subtraction fails, transferred amount is 0.
        euint256 actualAmount = TEEPrimitives.select(success, amount, TEEPrimitives.toEuint256(0));
        TEEPrimitives.allowThis(actualAmount);
        TEEPrimitives.allow(actualAmount, from);
        TEEPrimitives.allow(actualAmount, to);
        // Update balance of `to` with the actual transferred amount.
        (, euint256 newToBalance) = TEEPrimitives.safeAdd(_balances[to], actualAmount);
        _balances[to] = newToBalance;
        TEEPrimitives.allowThis(newToBalance);
        TEEPrimitives.allow(newToBalance, to);
        emit ConfidentialTransfer(from, to, actualAmount);
        return actualAmount;
    }
}
