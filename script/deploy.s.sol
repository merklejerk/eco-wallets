// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/EcoWallets.sol";

contract CounterScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast(vm.envUint('DEPLOYER_KEY'));
        new EcoWalletsEntryPoint();
    }
}
