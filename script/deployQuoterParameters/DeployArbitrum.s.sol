// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployUniversalQuoter} from '../DeployUniversalQuoter.s.sol';
import {QuoterParameters} from 'contracts/base/QuoterImmutables.sol';

contract DeployArbitrum is DeployUniversalQuoter {
    function setUp() public override {
        params = QuoterParameters({
            quoterV2: 0x61fFE014bA17989E743c5F6cB21bF9697530B21e,
            balancerQueries: 0xE39B5e3B6D74016b2F6A9673D7d7493B6DF549d5
        });

        unsupported = 0xEf1c6E67703c7BD7107eed8303Fbe6EC2554BF6B;
    }
}
