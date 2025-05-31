// SPDX-License-Identifier: APGL-3.0-only
pragma solidity 0.8.22;

import "forge-std-1.9.7/Script.sol";
 
contract DeployEditions is Script {

    function run() public {
        // get environment variables
        bytes memory constructorArgs = vm.envBytes("CONSTRUCTOR_ARGS");

        // deploy
        vm.broadcast();
        deployCode("src/send_and_receive_editions.vy", constructorArgs);
    }
}