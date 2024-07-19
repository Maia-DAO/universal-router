// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {ERC4626} from 'solmate/src/tokens/ERC4626.sol';

import {Constants} from '../../libraries/Constants.sol';
import {Permit2Payments} from '../Permit2Payments.sol';

/// @title Quoter for ERC4626 vaults
/// @notice Performs preview `deposit`, `mint`, `redeem`, and `withdraw` on ERC4626 vaults
abstract contract ERC4626Quoter {
    /// @notice Performs a `previewDeposit` into an ERC4626 vault
    /// @param vault The ERC4626 vault to deposit into
    /// @param assets The amount of assets to deposit
    /// @return shares The amount of shares to receive
    function erc4626PreviewDeposit(ERC4626 vault, uint256 assets) internal view returns (uint256 shares) {
        return vault.previewDeposit(assets);
    }

    /// @notice Performs a `previewRedeem` from an ERC4626 vault
    /// @param vault The ERC4626 vault to redeem from
    /// @param shares The amount of shares to redeem
    /// @return assets The amount of assets to receive
    function erc4626PreviewRedeem(ERC4626 vault, uint256 shares) internal view returns (uint256 assets) {
        return vault.previewRedeem(shares);
    }

    /// @notice Performs a `previewMint` on an ERC4626 vault
    /// @param vault The ERC4626 vault to mint on
    /// @param assets The amount of assets to mint
    /// @return shares The amount of shares to receive
    function erc4626PreviewMint(ERC4626 vault, uint256 assets) internal view returns (uint256 shares) {
        return vault.previewMint(assets);
    }

    /// @notice Performs a `previewWithdraw` from an ERC4626 vault
    /// @param vault The ERC4626 vault to withdraw from
    /// @param shares The amount of shares to withdraw
    /// @return assets The amount of assets to receive
    function erc4626PreviewWithdraw(ERC4626 vault, uint256 shares) internal view returns (uint256 assets) {
        return vault.previewWithdraw(shares);
    }
}
