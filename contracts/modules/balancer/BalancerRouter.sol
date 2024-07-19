// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {ERC20} from 'solmate/src/tokens/ERC20.sol';

import {Constants} from '../../libraries/Constants.sol';
import {Permit2Payments} from '../Permit2Payments.sol';
import {IAsset, IVault} from '../../interfaces/external/IVault.sol';

/// @title BalancerRouter contract
/// @notice Performs `batchSwap` and `swap` on Balancer vaults
abstract contract BalancerRouter is Permit2Payments {
    error BalancerUnexpectedBehaviour();

    /// @dev If deadline check is desired, use it in execute() instead of here
    uint256 private constant DEADLINE = type(uint256).max;

    /// @notice Performs a exact input `batchSwap` on a Balancer vault
    /// @param swaps The swaps to perform
    /// @param assets The assets to swap
    /// @param limits The limits to use
    /// @param payer The address that will pay for the swap
    /// @param recipient The address that will receive the swapped assets
    function balancerBatchSwapExactIn(
        IVault.BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        int256[] memory limits,
        address payer,
        address payable recipient
    ) internal {
        // use amount == Constants.CONTRACT_BALANCE as a flag to swap the entire balance of the contract
        if (swaps[0].amount == Constants.CONTRACT_BALANCE) {
            if (payer != address(this)) revert BalancerUnexpectedBehaviour();

            address asset = address(assets[swaps[0].assetInIndex]);
            swaps[0].amount = ERC20(asset).balanceOf(address(this));
        } else {
            permit2TransferToThisAddress(address(assets[swaps[0].assetInIndex]), payer, swaps[0].amount);
        }

        IVault(BALANCER_VAULT).batchSwap(
            IVault.SwapKind.GIVEN_IN, swaps, assets, createFundManagement(recipient), limits, DEADLINE
        );
    }

    /// @notice Performs a exact input `swap` on a Balancer vault
    /// @param poolId The pool to swap on
    /// @param assetIn The asset to swap in
    /// @param assetOut The asset to swap out
    /// @param amount The amount of assetIn to swap in
    /// @param limit The minimum amount of assetOut to swap out
    /// @param payer The address that will pay for the swap
    /// @param recipient The address that will receive the swapped assets
    function balancerSingleSwapExactIn(
        bytes32 poolId,
        address assetIn,
        address assetOut,
        uint256 amount,
        uint256 limit,
        address payer,
        address payable recipient,
        bytes calldata userData
    ) internal {
        // use amount == Constants.CONTRACT_BALANCE as a flag to swap the entire balance of the contract
        if (amount == Constants.CONTRACT_BALANCE) {
            if (payer != address(this)) revert BalancerUnexpectedBehaviour();

            amount = ERC20(assetIn).balanceOf(address(this));
        } else {
            permit2TransferToThisAddress(assetIn, payer, amount);
        }

        _balancerSingleSwap(IVault.SwapKind.GIVEN_IN, poolId, assetIn, assetOut, amount, limit, recipient, userData);
    }

    /// @notice Performs a exact output `batchSwap` on a Balancer vault
    /// @param swaps The swaps to perform
    /// @param assets The assets to swap
    /// @param limits The limits to use
    /// @param payer The address that will pay for the swap
    /// @param recipient The address that will receive the swapped assets
    function balancerBatchSwapExactOut(
        IVault.BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        int256[] memory limits,
        address payer,
        address payable recipient
    ) internal {
        permit2TransferToThisAddress(address(assets[swaps[0].assetInIndex]), payer, uint256(limits[0]));

        IVault(BALANCER_VAULT).batchSwap(
            IVault.SwapKind.GIVEN_OUT, swaps, assets, createFundManagement(recipient), limits, DEADLINE
        );
    }

    /// @notice Performs a exact output `swap` on a Balancer vault
    /// @param poolId The pool to swap on
    /// @param assetIn The asset to swap in
    /// @param assetOut The asset to swap out
    /// @param amount The amount of assetIn to swap in
    /// @param limit The minimum amount of assetOut to swap out
    /// @param payer The address that will pay for the swap
    /// @param recipient The address that will receive the swapped assets
    function balancerSingleSwapExactOut(
        bytes32 poolId,
        address assetIn,
        address assetOut,
        uint256 amount,
        uint256 limit,
        address payer,
        address payable recipient,
        bytes calldata userData
    ) internal {
        permit2TransferToThisAddress(assetIn, payer, limit);

        _balancerSingleSwap(IVault.SwapKind.GIVEN_OUT, poolId, assetIn, assetOut, amount, limit, recipient, userData);
    }

    /// @notice Performs a `swap` on a Balancer vault
    /// @param kind The type of swap to perform
    /// @param poolId The pool to swap on
    /// @param assetIn The asset to swap in
    /// @param assetOut The asset to swap out
    /// @param amount The amount of assetIn to swap in
    /// @param limit The minimum amount of assetOut to swap out
    /// @param recipient The address that will receive the swapped assets
    /// @param userData The data to pass to the swap
    function _balancerSingleSwap(
        IVault.SwapKind kind,
        bytes32 poolId,
        address assetIn,
        address assetOut,
        uint256 amount,
        uint256 limit,
        address payable recipient,
        bytes calldata userData
    ) private {
        IVault.SingleSwap memory singleSwap = IVault.SingleSwap({
            poolId: poolId,
            kind: kind,
            assetIn: IAsset(assetIn),
            assetOut: IAsset(assetOut),
            amount: amount,
            userData: userData
        });

        IVault(BALANCER_VAULT).swap(singleSwap, createFundManagement(recipient), limit, DEADLINE);
    }

    function createFundManagement(address payable recipient) internal view returns (IVault.FundManagement memory) {
        return IVault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: recipient,
            toInternalBalance: false
        });
    }
}
