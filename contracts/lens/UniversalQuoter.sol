// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

// Command implementations
import {QuoteDispatcher} from '../base/QuoteDispatcher.sol';
import {QuoterParameters} from '../base/QuoterImmutables.sol';
import {IUniversalQuoter} from '../interfaces/IUniversalQuoter.sol';
import {UniswapQuoterImmutables, UniswapQuoterParameters} from '../modules/uniswap/UniswapQuoterImmutables.sol';
import {BalancerQuoterImmutables, BalancerQuoterParameters} from '../modules/balancer/BalancerQuoterImmutables.sol';

/// @dev These functions are not marked view because they rely on calling non-view functions and reverting
/// to compute the result. They are also not gas efficient and should not be called on-chain.
contract UniversalQuoter is IUniversalQuoter, QuoteDispatcher {
    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert TransactionDeadlinePassed();
        _;
    }

    constructor(QuoterParameters memory params)
        UniswapQuoterImmutables(UniswapQuoterParameters(params.quoterV2))
        BalancerQuoterImmutables(BalancerQuoterParameters(params.balancerQueries))
    {}

    /// @inheritdoc IUniversalQuoter
    function execute(bytes calldata commands, bytes[] calldata inputs)
        external
        override
        returns (uint256 amount, bytes[] memory outputs)
    {
        uint256 numCommands = commands.length;
        if (inputs.length != numCommands) revert LengthMismatch();

        outputs = new bytes[](numCommands);

        // loop through all given commands, execute them and pass along outputs as defined
        for (uint256 commandIndex = 0; commandIndex < numCommands;) {
            bytes1 command = commands[commandIndex];

            bytes calldata input = inputs[commandIndex];

            (amount, outputs[commandIndex]) = dispatch(command, amount, input);

            unchecked {
                commandIndex++;
            }
        }
    }
}
