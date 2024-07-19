// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

struct BalancerQuoterParameters {
    address balancerQueries;
}

contract BalancerQuoterImmutables {
    /// @dev The address of Balancer's BalancerQueries
    address internal immutable BALANCER_QUERIES;

    constructor(BalancerQuoterParameters memory params) {
        BALANCER_QUERIES = params.balancerQueries;
    }
}
