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

    /// @dev The given receiver `receiver` is invalid for transfers.
    error ERC7984InvalidReceiver(address receiver);

    /// @dev The given sender `sender` is invalid for transfers.
    error ERC7984InvalidSender(address sender);

    /// @dev The holder `holder` is trying to send tokens but has a balance of 0.
    error ERC7984ZeroBalance(address holder);

    /**
     * @dev The caller `user` does not have access to the encrypted amount `amount`.
     *
     * NOTE: Try using the equivalent transfer function with an input proof.
     */
    error ERC7984UnauthorizedUseOfEncryptedAmount(euint256 amount, address user);

    constructor(uint256 totalSupply, address teeComputeManager) {
        TEEPrimitives.setNoxConfig(teeComputeManager);
        _totalSupply = TEEPrimitives.toEuint256(totalSupply);
        euint256 msgSenderBalance = TEEPrimitives.toEuint256(totalSupply);
        _balances[msg.sender] = msgSenderBalance;
        TEEPrimitives.allowThis(msgSenderBalance);
        TEEPrimitives.allow(msgSenderBalance, msg.sender);
    }

    function confidentialTotalSupply() public view override returns (euint256) {
        return _totalSupply;
    }

    function confidentialBalanceOf(address account) public view override returns (euint256) {
        return _balances[account];
    }

    /// @inheritdoc IERC7984
    function confidentialTransfer(
        address to,
        externalEuint256 encryptedAmount,
        bytes calldata inputProof
    ) public virtual returns (euint256) {
        return _transfer(msg.sender, to, TEEPrimitives.fromExternal(encryptedAmount, inputProof));
    }

    /// @inheritdoc IERC7984
    function confidentialTransfer(address to, euint256 amount) public virtual returns (euint256) {
        require(
            TEEPrimitives.isAllowed(amount, msg.sender),
            ERC7984UnauthorizedUseOfEncryptedAmount(amount, msg.sender)
        );
        return _transfer(msg.sender, to, amount);
    }

    function _transfer(
        address from,
        address to,
        euint256 amount
    ) internal returns (euint256 transferred) {
        require(from != address(0), ERC7984InvalidSender(address(0)));
        require(to != address(0), ERC7984InvalidReceiver(address(0)));
        return _update(from, to, amount);
    }

    function _update(
        address from,
        address to,
        euint256 amount
    ) internal virtual returns (euint256 transferred) {
        ebool success;
        euint256 ptr;

        if (from == address(0)) {
            (success, ptr) = TEEPrimitives.safeAdd(_totalSupply, amount);
            TEEPrimitives.allowThis(ptr);
            _totalSupply = ptr;
        } else {
            euint256 fromBalance = _balances[from];
            require(TEEPrimitives.isInitialized(fromBalance), ERC7984ZeroBalance(from));
            (success, ptr) = TEEPrimitives.safeSub(fromBalance, amount);
            TEEPrimitives.allowThis(ptr);
            TEEPrimitives.allow(ptr, from);
            _balances[from] = ptr;
        }

        transferred = TEEPrimitives.select(success, amount, TEEPrimitives.toEuint256(0));

        if (to == address(0)) {
            ptr = TEEPrimitives.sub(_totalSupply, transferred);
            TEEPrimitives.allowThis(ptr);
            _totalSupply = ptr;
        } else {
            euint256 toBalance = _balances[to];
            if (!TEEPrimitives.isInitialized(toBalance)) {
                // If the recipient has no balance, we need to initialize it.
                toBalance = TEEPrimitives.toEuint256(0);
                TEEPrimitives.allowThis(toBalance);
            }
            ptr = TEEPrimitives.add(toBalance, transferred);
            TEEPrimitives.allowThis(ptr);
            TEEPrimitives.allow(ptr, to);
            _balances[to] = ptr;
        }

        if (from != address(0)) TEEPrimitives.allow(transferred, from);
        if (to != address(0)) TEEPrimitives.allow(transferred, to);
        TEEPrimitives.allowThis(transferred);
        emit ConfidentialTransfer(from, to, transferred);
    }
}
