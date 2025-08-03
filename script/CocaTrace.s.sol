// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/CocaTrace.sol";

contract DeployCocaTrace is Script {
    function run() external {        
        vm.startBroadcast();
        
        // Deploy CocaTrace contract
        new CocaTrace();
        vm.stopBroadcast();
    }
}