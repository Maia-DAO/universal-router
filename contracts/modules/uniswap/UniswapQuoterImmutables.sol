// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

struct UniswapQuoterParameters {
    address quoterV2;
}

contract UniswapQuoterImmutables {
    /// @dev The address of Uniswap's QuoterV2
    address internal immutable QUOTER_V2;

    constructor(UniswapQuoterParameters memory params) {
        QUOTER_V2 = params.quoterV2;
    }
}
