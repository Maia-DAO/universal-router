// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {ERC4626} from 'solmate/src/tokens/ERC4626.sol';

import {BalancerQuoter} from '../modules/balancer/BalancerQuoter.sol';
import {BytesLib} from '../modules/uniswap/v3/BytesLib.sol';
import {ERC4626Quoter} from '../modules/erc4626/ERC4626Quoter.sol';
import {V3Quoter} from '../modules/uniswap/v3/V3Quoter.sol';

import {Commands} from '../libraries/Commands.sol';

import {IAsset, IVault} from '../interfaces/external/IVault.sol';

/// @title Decodes and Executes Commands
/// @notice Called by the UniversalRouter contract to efficiently decode and execute a singular command
abstract contract QuoteDispatcher is V3Quoter, ERC4626Quoter, BalancerQuoter {
    using BytesLib for bytes;

    error InvalidCommandType(uint256 commandType);

    /// @notice Decodes and executes the given command with the given inputs
    /// @param commandType The command type to execute
    /// @param amount The amount from the previous command to pass on to this command
    /// @param inputs The inputs to execute the command with
    /// @dev 2 masks are used to enable use of a nested-if statement in execution for efficiency reasons
    /// @return returnAmount The resulting input or output amount from the command passed on to the next command
    /// @return returnData The outputs or error messages, if any, from the command
    function dispatch(bytes1 commandType, uint256 amount, bytes calldata inputs)
        internal
        returns (uint256 returnAmount, bytes memory returnData)
    {
        uint256 command = uint8(commandType & Commands.COMMAND_TYPE_MASK);

        if (command < Commands.FOURTH_IF_BOUNDARY) {
            if (command < Commands.SECOND_IF_BOUNDARY) {
                // 0x00 <= command < 0x08
                if (command < Commands.FIRST_IF_BOUNDARY) {
                    if (command == Commands.V3_SWAP_EXACT_IN) {
                        // equivalent: abi.decode(inputs, (uint256, bytes))
                        uint256 amountIn;
                        assembly {
                            amountIn := calldataload(inputs.offset)
                        }
                        if (amountIn == 0) amountIn = amount;
                        bytes calldata path = inputs.toBytes(1);

                        (
                            uint256 amountOut,
                            uint160[] memory sqrtPriceX96AfterList,
                            uint32[] memory initializedTicksCrossedList,
                            uint256 gasEstimate
                        ) = v3QuoteExactInput(path, amountIn);
                        (returnAmount, returnData) =
                            (amountOut, abi.encode(sqrtPriceX96AfterList, initializedTicksCrossedList, gasEstimate));
                    } else if (command == Commands.V3_SWAP_EXACT_OUT) {
                        // equivalent: abi.decode(inputs, (uint256, bytes))
                        uint256 amountOut;
                        assembly {
                            amountOut := calldataload(inputs.offset)
                        }
                        if (amountOut == 0) amountOut = amount;
                        bytes calldata path = inputs.toBytes(1);

                        (
                            uint256 amountIn,
                            uint160[] memory sqrtPriceX96AfterList,
                            uint32[] memory initializedTicksCrossedList,
                            uint256 gasEstimate
                        ) = v3QuoteExactOutput(path, amountOut);
                        (returnAmount, returnData) =
                            (amountIn, abi.encode(sqrtPriceX96AfterList, initializedTicksCrossedList, gasEstimate));
                    } else {
                        // placeholder area for commands 0x02-0x07
                        revert InvalidCommandType(command);
                    }
                    // 0x08 <= command < 0x10
                } else {
                    // placeholder area for commands 0x08-0x10
                    revert InvalidCommandType(command);
                }
                // 0x10 <= command
            } else {
                // placeholder area for commands 0x10-0x20
                revert InvalidCommandType(command);
            }
            // 0x20 <= command
        } else {
            // 0x20 <= command < 0x28
            if (command < Commands.FIFTH_IF_BOUNDARY) {
                // placeholder area for commands 0x20-0x28
                revert InvalidCommandType(command);
            } else {
                // 0x28 <= command < 0x30
                if (command < Commands.SIXTH_IF_BOUNDARY) {
                    if (command == Commands.ERC4626_DEPOSIT) {
                        // equivalent: abi.decode(inputs, (address, uint256))
                        ERC4626 vault;
                        uint256 assets;
                        assembly {
                            vault := calldataload(inputs.offset)
                            assets := calldataload(add(inputs.offset, 0x20))
                        }
                        if (assets == 0) assets = amount;

                        uint256 shares = erc4626PreviewDeposit(vault, assets);
                        (returnAmount, returnData) = (shares, abi.encode(shares));
                    } else if (command == Commands.ERC4626_REDEEM) {
                        // equivalent: abi.decode(inputs, (address, uint256))
                        ERC4626 vault;
                        uint256 shares;
                        assembly {
                            vault := calldataload(inputs.offset)
                            shares := calldataload(add(inputs.offset, 0x20))
                        }
                        if (shares == 0) shares = amount;

                        uint256 assets = erc4626PreviewRedeem(vault, shares);
                        (returnAmount, returnData) = (assets, abi.encode(assets));
                    } else if (command == Commands.ERC4626_MINT) {
                        // equivalent: abi.decode(inputs, (address, uint256))
                        ERC4626 vault;
                        uint256 shares;
                        assembly {
                            vault := calldataload(inputs.offset)
                            shares := calldataload(add(inputs.offset, 0x20))
                        }
                        if (shares == 0) shares = amount;

                        uint256 assets = erc4626PreviewMint(vault, shares);
                        (returnAmount, returnData) = (assets, abi.encode(assets));
                    } else if (command == Commands.ERC4626_WITHDRAW) {
                        // equivalent: abi.decode(inputs, (address, uint256))
                        ERC4626 vault;
                        uint256 assets;
                        assembly {
                            vault := calldataload(inputs.offset)
                            assets := calldataload(add(inputs.offset, 0x20))
                        }
                        if (assets == 0) assets = amount;

                        uint256 shares = erc4626PreviewWithdraw(vault, assets);
                        (returnAmount, returnData) = (shares, abi.encode(shares));
                    } else {
                        // placeholder area for commands 0x2c-0x2f
                        revert InvalidCommandType(command);
                    }
                    // 0x30 <= command < 0x40
                } else {
                    if (command == Commands.BALANCER_BATCH_SWAPS_EXACT_IN) {
                        // During multi-hop swaps, it's not always possible to know the value of the amount for a given step.
                        // If BatchSwapStep.amount to 0, the vault will use the full output of the previous hop.
                        IVault.BatchSwapStep[] memory swaps;
                        IAsset[] memory assets;

                        (swaps, assets) = abi.decode(inputs, (IVault.BatchSwapStep[], IAsset[]));

                        if (swaps[0].amount == 0) swaps[0].amount = amount;

                        int256[] memory assetDeltas = balancerQueryBatchSwapExactIn(swaps, assets);
                        (returnAmount, returnData) =
                            (uint256(-assetDeltas[assetDeltas.length - 1]), abi.encode(assetDeltas));
                    } else if (command == Commands.BALANCER_SINGLE_SWAP_EXACT_IN) {
                        // equivalent: abi.decode(inputs, (bytes32, address, address, uint256, bytes))
                        bytes32 poolId;
                        address assetIn;
                        address assetOut;
                        uint256 amountIn;

                        assembly {
                            poolId := calldataload(inputs.offset)
                            assetIn := calldataload(add(inputs.offset, 0x20))
                            assetOut := calldataload(add(inputs.offset, 0x40))
                            amountIn := calldataload(add(inputs.offset, 0x60))
                        }
                        if (amountIn == 0) amountIn = amount;

                        bytes calldata userData = inputs.toBytes(4);

                        uint256 amountOut = balancerQuerySwapExactIn(poolId, assetIn, assetOut, amountIn, userData);
                        (returnAmount, returnData) = (amountOut, abi.encode(amountOut));
                    } else if (command == Commands.BALANCER_BATCH_SWAPS_EXACT_OUT) {
                        // During multi-hop swaps, it's not always possible to know the value of the amount for a given step.
                        // If BatchSwapStep.amount to 0, the vault will use the full output of the previous hop.
                        IVault.BatchSwapStep[] memory swaps;
                        IAsset[] memory assets;

                        (swaps, assets) = abi.decode(inputs, (IVault.BatchSwapStep[], IAsset[]));

                        uint256 lastSwapIndex = swaps.length - 1;
                        if (swaps[lastSwapIndex].amount == 0) swaps[lastSwapIndex].amount = uint256(-int256(amount));

                        int256[] memory assetDeltas = balancerQueryBatchSwapExactOut(swaps, assets);
                        (returnAmount, returnData) =
                            (uint256(assetDeltas[assetDeltas.length - 1]), abi.encode(assetDeltas));
                    } else if (command == Commands.BALANCER_SINGLE_SWAP_EXACT_OUT) {
                        // equivalent: abi.decode(inputs, (bytes32, address, address, uint256, bytes))
                        bytes32 poolId;
                        address assetIn;
                        address assetOut;
                        uint256 amountOut;

                        assembly {
                            poolId := calldataload(inputs.offset)
                            assetIn := calldataload(add(inputs.offset, 0x20))
                            assetOut := calldataload(add(inputs.offset, 0x40))
                            amountOut := calldataload(add(inputs.offset, 0x60))
                        }
                        if (amountOut == 0) amountOut = amount;

                        bytes calldata userData = inputs.toBytes(4);

                        uint256 amountIn = balancerQuerySwapExactOut(poolId, assetIn, assetOut, amountOut, userData);
                        (returnAmount, returnData) = (amountIn, abi.encode(amountIn));
                    } else {
                        // placeholder area for commands 0x32-0x3f
                        revert InvalidCommandType(command);
                    }
                }
            }
        }
    }
}
