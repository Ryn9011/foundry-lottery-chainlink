// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig HelperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , ) = HelperConfig
            .activeNetworkConfig();
        return createSubscription(vrfCoordinator);
    }

    function createSubscription(
        address vrfCoordinator
    ) public returns (uint64) {
        console.log("creating sucbcription on ChainId: ", block.chainid);
        vm.startBroadcast();
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("your subscription id is: ", subId);
        console.log("Please update your subscription id in HelperConfig.s.sol");
        return subId;
    }

    function run() external returns (uint256) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig HelperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            address link
        ) = HelperConfig.activeNetworkConfig();
    }

    function fundSubscription(
      address vrfCoordinator,
      uint64 subId,
      address link
    ) public {
      console.log("funcding subscription ", subId);
      console.log("Using vrfCoordination: ", vrfCoordinator);
      console.log("On ChainID: ", block.chainid);
      if (block.chainid == 31337) {
        vm.startBroadcast();
        VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
          subId, 
          FUND_AMOUNT
        );
        vm.stopBroadcast();
      } else {
        vm.startBroadcast();
        LinkToken(link).transferAndCall(
          vrfCoordinator,
          FUND_AMOUNT,
          abi.encode(subId)
        );
        vm.stopBroadcast();
      }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }    
}

contract AddConsumer is Script {
      function run() external {
        address contractAddress = DevOpsTools.get_most_recent_deployment("MyContract")
      }
    }
