// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "encrypted-types/EncryptedTypes.sol";
import {Nox} from "../sdk/Nox.sol";

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

    constructor(uint256 totalSupply) {
        _totalSupply = Nox.toEuint256(totalSupply);
        euint256 msgSenderBalance = Nox.toEuint256(totalSupply);
        _balances[msg.sender] = msgSenderBalance;
        Nox.allowThis(msgSenderBalance);
        Nox.allow(msgSenderBalance, msg.sender);
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
        return _transfer(msg.sender, to, Nox.fromExternal(encryptedAmount, inputProof));
    }

    /// @inheritdoc IERC7984
    function confidentialTransfer(address to, euint256 amount) public virtual returns (euint256) {
        require(
            Nox.isAllowed(amount, msg.sender),
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
            (success, ptr) = Nox.safeAdd(_totalSupply, amount);
            Nox.allowThis(ptr);
            _totalSupply = ptr;
        } else {
            euint256 fromBalance = _balances[from];
            require(Nox.isInitialized(fromBalance), ERC7984ZeroBalance(from));
            (success, ptr) = Nox.safeSub(fromBalance, amount);
            Nox.allowThis(ptr);
            Nox.allow(ptr, from);
            _balances[from] = ptr;
        }

        transferred = Nox.select(success, amount, Nox.toEuint256(0));

        if (to == address(0)) {
            ptr = Nox.sub(_totalSupply, transferred);
            Nox.allowThis(ptr);
            _totalSupply = ptr;
        } else {
            euint256 toBalance = _balances[to];
            if (!Nox.isInitialized(toBalance)) {
                // If the recipient has no balance, we need to initialize it.
                toBalance = Nox.toEuint256(0);
                Nox.allowThis(toBalance);
            }
            ptr = Nox.add(toBalance, transferred);
            Nox.allowThis(ptr);
            Nox.allow(ptr, to);
            _balances[to] = ptr;
        }

        if (from != address(0)) Nox.allow(transferred, from);
        if (to != address(0)) Nox.allow(transferred, to);
        Nox.allowThis(transferred);
        emit ConfidentialTransfer(from, to, transferred);
    }
}
