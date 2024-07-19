// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/console2.sol';
import 'forge-std/Script.sol';
import {QuoterParameters} from 'contracts/base/QuoterImmutables.sol';
import {UnsupportedProtocol} from 'contracts/deploy/UnsupportedProtocol.sol';
import {UniversalQuoter} from 'contracts/lens/UniversalQuoter.sol';
import {Permit2} from 'permit2/src/Permit2.sol';

abstract contract DeployUniversalQuoter is Script {
    QuoterParameters internal params;
    address internal unsupported;

    address constant UNSUPPORTED_PROTOCOL = address(0);
    bytes32 constant BYTES32_ZERO = bytes32(0);

    // set values for params and unsupported
    function setUp() public virtual;

    function run() external returns (UniversalQuoter router) {
        vm.startBroadcast();

        params = QuoterParameters({
            quoterV2: mapUnsupported(params.quoterV2),
            balancerQueries: mapUnsupported(params.balancerQueries)
        });

        logParams();

        router = new UniversalQuoter(params);
        console2.log('Universal Router Deployed:', address(router));
        vm.stopBroadcast();
    }

    function logParams() internal view {
        console2.log('quoterV2:', params.quoterV2);
        console2.log('balancerQueries:', params.balancerQueries);
    }

    function mapUnsupported(address protocol) internal view returns (address) {
        return protocol == address(0) ? unsupported : protocol;
    }
}
