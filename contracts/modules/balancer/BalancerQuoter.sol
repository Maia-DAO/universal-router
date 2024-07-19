// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IAsset, IVault} from '../../interfaces/external/IVault.sol';
import {IBalancerQueries} from '../../interfaces/external/IBalancerQueries.sol';
import {BalancerQuoterImmutables} from './BalancerQuoterImmutables.sol';

/**
 * @title Balancer V2 Vault Swap Quoter
 * @notice Supports quoting the calculated amounts from exact input or exact output swaps.
 * @dev Provides a way to perform queries on swaps, joins and exits, simulating these operations and returning the exact
 * result they would have if called on the Vault given the current state. Note that the results will be affected by
 * other transactions interacting with the Pools involved.
 *
 * All query functions can be called both on-chain and off-chain.
 *
 * If calling them from a contract, note that all query functions are not `view`. Despite this, these functions produce
 * no net state change, and for all intents and purposes can be thought of as if they were indeed `view`. However,
 * calling them via STATICCALL will fail.
 *
 * If calling them from an off-chain client, make sure to use eth_call: most clients default to eth_sendTransaction for
 * non-view functions.
 *
 * In all cases, the `fromInternalBalance` and `toInternalBalance` fields are entirely ignored: we just use the same
 * structs for simplicity.
 */
abstract contract BalancerQuoter is BalancerQuoterImmutables {
    /// @notice Returns the amount out received for a given exact input batch swap without executing the swap
    /// @param swaps The swaps to perform
    /// @param assets The assets to swap
    /// @return assetDeltas The amount of each token that would be computed, positive if receiving, negative if sending
    function balancerQueryBatchSwapExactIn(IVault.BatchSwapStep[] memory swaps, IAsset[] memory assets)
        internal
        returns (int256[] memory assetDeltas)
    {
        return IBalancerQueries(BALANCER_QUERIES).queryBatchSwap(
            IVault.SwapKind.GIVEN_IN, swaps, assets, createFundManagement()
        );
    }

    /// @notice Returns the amount out received for a given exact input swap without executing the swap
    /// @param poolId The pool to swap on
    /// @param assetIn The asset to swap in
    /// @param assetOut The asset to swap out
    /// @param amount The amount of assetIn to swap in
    /// @return assetDelta The amount of the token that would be computed, positive if receiving, negative if sending
    function balancerQuerySwapExactIn(
        bytes32 poolId,
        address assetIn,
        address assetOut,
        uint256 amount,
        bytes calldata userData
    ) internal returns (uint256 assetDelta) {
        return IBalancerQueries(BALANCER_QUERIES).querySwap(
            IVault.SingleSwap({
                poolId: poolId,
                kind: IVault.SwapKind.GIVEN_IN,
                assetIn: IAsset(assetIn),
                assetOut: IAsset(assetOut),
                amount: amount,
                userData: userData
            }),
            createFundManagement()
        );
    }

    /// @notice Returns the amount out received for a given exact output batch swap without executing the swap
    /// @param swaps The swaps to perform
    /// @param assets The assets to swap
    /// @return assetDeltas The amount of each token that would be computed, positive if receiving, negative if sending
    function balancerQueryBatchSwapExactOut(IVault.BatchSwapStep[] memory swaps, IAsset[] memory assets)
        internal
        returns (int256[] memory assetDeltas)
    {
        return IBalancerQueries(BALANCER_QUERIES).queryBatchSwap(
            IVault.SwapKind.GIVEN_OUT, swaps, assets, createFundManagement()
        );
    }

    /// @notice Returns the amount out received for a given exact output swap without executing the swap
    /// @param poolId The pool to swap on
    /// @param assetIn The asset to swap in
    /// @param assetOut The asset to swap out
    /// @param amount The amount of assetOut to swap out
    /// @return assetDelta The amount of the token that would be computed, positive if receiving, negative if sending
    function balancerQuerySwapExactOut(
        bytes32 poolId,
        address assetIn,
        address assetOut,
        uint256 amount,
        bytes calldata userData
    ) internal returns (uint256 assetDelta) {
        return IBalancerQueries(BALANCER_QUERIES).querySwap(
            IVault.SingleSwap({
                poolId: poolId,
                kind: IVault.SwapKind.GIVEN_OUT,
                assetIn: IAsset(assetIn),
                assetOut: IAsset(assetOut),
                amount: amount,
                userData: userData
            }),
            createFundManagement()
        );
    }

    // Create a FundManagement struct with default values for the quoter
    function createFundManagement() internal view returns (IVault.FundManagement memory) {
        return IVault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });
    }
}
