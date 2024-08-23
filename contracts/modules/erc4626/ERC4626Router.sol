// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {ERC4626} from 'solmate/src/tokens/ERC4626.sol';

import {Constants} from '../../libraries/Constants.sol';
import {Permit2Payments} from '../Permit2Payments.sol';

/// @title Router for ERC4626 vaults
/// @notice Performs `deposit`, `mint`, `redeem`, and `withdraw` on ERC4626 vaults
/// @dev No slippage checks are performed to avoid unnecessary calldata when used in the middle of multi-hop swaps.
///      Multi-hop swaps are being prioritized because they are the most expensive.
/// @dev This contract always has custody of the input assets and is the recipient of the output assets
///
/// NOTE: Slippage and transferring output checks MUST be performed in subsequent commands (ex: use Command.SWEEP)
///       Balances used MUST be gotten from previous commands and MUST be sent to a recipient in subsequent commands
abstract contract ERC4626Router is Permit2Payments {
    error ERC4626TooLittleReceived();
    error ERC4626TooMuchRequested();
    error ERC4626UnexpectedBehaviour();

    /// @notice Performs a `deposit` into an ERC4626 vault
    /// @param vault The ERC4626 vault to deposit into
    /// @param assets The amount of assets to deposit
    /// @param payer The address that will pay for the deposit
    /// @param minShares The minimum amount of shares to receive
    /// @param recipient The address that will receive the shares
    function erc4626Deposit(ERC4626 vault, uint256 assets, address payer, uint256 minShares, address recipient)
        internal
    {
        // use amountIn == Constants.CONTRACT_BALANCE as a flag to swap the entire balance of the contract
        if (assets == Constants.CONTRACT_BALANCE) {
            if (payer != address(this)) revert ERC4626UnexpectedBehaviour();

            assets = vault.asset().balanceOf(address(this));
        } else {
            permit2TransferToThisAddress(address(vault.asset()), payer, assets);
        }

        uint256 shares = vault.deposit(assets, recipient);

        // check that we received enough shares
        if (shares < minShares) revert ERC4626TooLittleReceived();
    }

    /// @notice Performs a `redeem` from an ERC4626 vault
    /// @param vault The ERC4626 vault to redeem from
    /// @param shares The amount of shares to redeem
    /// @param payer The address that will pay for the redeem
    /// @param minAssets The minimum amount of assets to receive
    /// @param recipient The address that will receive the assets
    function erc4626Redeem(ERC4626 vault, uint256 shares, address payer, uint256 minAssets, address recipient)
        internal
    {
        // use amountIn == Constants.CONTRACT_BALANCE as a flag to swap the entire balance of the contract
        if (shares == Constants.CONTRACT_BALANCE) {
            if (payer != address(this)) revert ERC4626UnexpectedBehaviour();

            shares = vault.balanceOf(address(this));
        } else {
            permit2TransferToThisAddress(address(vault), payer, shares);
        }

        uint256 assets = vault.redeem(shares, recipient, address(this));

        // check that we received enough assets
        if (assets < minAssets) revert ERC4626TooLittleReceived();
    }

    /// @notice Performs a `mint` into an ERC4626 vault
    /// @param vault The ERC4626 vault to mint into
    /// @param shares The amount of shares to mint
    /// @param payer The address that will pay for the mint
    /// @param maxAssets The maximum amount of assets to use
    /// @param recipient The address that will receive the shares
    function erc4626Mint(ERC4626 vault, uint256 shares, address payer, uint256 maxAssets, address recipient) internal {
        permit2TransferToThisAddress(address(vault.asset()), payer, maxAssets);

        uint256 assets = vault.mint(shares, recipient);

        // check that we used less than maxAssets
        if (maxAssets > 0) if (assets > maxAssets) revert ERC4626TooMuchRequested();
    }

    /// @notice Performs a `withdraw` from an ERC4626 vault
    /// @param vault The ERC4626 vault to withdraw from
    /// @param assets The amount of assets to withdraw
    /// @param payer The address that will pay for the withdraw
    /// @param maxShares The maximum amount of shares to receive
    /// @param recipient The address that will receive the assets
    function erc4626Withdraw(ERC4626 vault, uint256 assets, address payer, uint256 maxShares, address recipient)
        internal
    {
        permit2TransferToThisAddress(address(vault), payer, maxShares);

        uint256 shares = vault.withdraw(assets, recipient, address(this));

        // check that we used less than maxShares
        if (maxShares > 0) if (shares > maxShares) revert ERC4626TooMuchRequested();
    }

    /// @notice Decodes the inputs for an ERC4626 command
    /// @param inputs The inputs to decode
    /// @return vault The ERC4626 vault to perform the command on
    /// @return amount The amount of assets or shares to use
    /// @return payerIsUser A flag for whether the payer is the user or not
    /// @return minOrMaxAmount A flag for whether the amount is a minimum or maximum
    /// @return recipient A flag for whether the recipient is the user or not
    function decodeERC4626Command(bytes calldata inputs)
        internal
        pure
        returns (ERC4626 vault, uint256 amount, bool payerIsUser, uint256 minOrMaxAmount, address recipient)
    {
        // equivalent: abi.decode(inputs, (address, uint256, bool, uint256, address))
        assembly {
            vault := calldataload(inputs.offset)
            amount := calldataload(add(inputs.offset, 0x20))

            // payerIsUser is a flag for whether the payer is the user or not, default to false
            if iszero(lt(inputs.length, 0x40)) {
                payerIsUser := calldataload(add(inputs.offset, 0x40))

                // minOrMaxAmount is a flag for whether the amount is a minimum or maximum, defaults to not checking
                if iszero(lt(inputs.length, 0x60)) {
                    minOrMaxAmount := calldataload(add(inputs.offset, 0x60))

                    // recipient is a flag for whether the recipient is the user or not, defaults to address(this)
                    if iszero(lt(inputs.length, 0x80)) { recipient := calldataload(add(inputs.offset, 0x80)) }
                }
            }

            if iszero(recipient) { recipient := 2 } // Constants.ADDRESS_THIS
        }
    }
}
