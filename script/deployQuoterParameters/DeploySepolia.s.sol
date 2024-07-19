// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployUniversalQuoter} from '../DeployUniversalQuoter.s.sol';
import {QuoterParameters} from 'contracts/base/QuoterImmutables.sol';

contract DeploySepolia is DeployUniversalQuoter {
    function setUp() public override {
        params = QuoterParameters({
            quoterV2: 0xEd1f6473345F45b75F8179591dd5bA1888cf2FB3,
            balancerQueries: 0x1802953277FD955f9a254B80Aa0582f193cF1d77
        });

        unsupported = 0x5302086A3a25d473aAbBd0356eFf8Dd811a4d89B;
    }
}
