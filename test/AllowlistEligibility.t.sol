// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console2 } from "forge-std/Test.sol";
import {
  AllowlistEligibility,
  AllowlistEligibility_NotOwner,
  AllowlistEligibility_NotArbitrator,
  AllowlistEligibility_NotWearer,
  AllowlistEligibility_ArrayLengthMismatch,
  AllowlistEligibility_HatNotMutable
} from "../src/AllowlistEligibility.sol";
import { AllowlistEligibilityFactory } from "../src/AllowlistEligibilityFactory.sol";
import { Deploy, DeployPrecompiled } from "../script/Deploy.s.sol";
// import {
//   HatsModuleFactory, IHats, deployModuleInstance, deployModuleFactory
// } from "hats-module/utils/DeployFunctions.sol";
import { IHats } from "hats-protocol/Interfaces/IHats.sol";
import { Hats } from "hats-protocol/Hats.sol";
import { HatsModule } from "hats-module/HatsEligibilityModule.sol";

contract AllowlistEligibilityTest is Test {
  /// @dev Inherit from DeployPrecompiled instead of Deploy if working with pre-compiled contracts

  /// @dev variables inhereted from Deploy script
  // AllowlistEligibility public implementation;
  // bytes32 public SALT;

  uint256 public fork;
  uint256 public BLOCK_NUMBER = 17_671_864; // deployment block for Hats.sol
  string internal constant x = "Hats Protocol v1";
  string internal constant y = "";
  IHats public HATS = new Hats{ salt: bytes32(abi.encode(0x4a75)) }(x, y);
  //HatsModuleFactory public factory;
  AllowlistEligibility public instance;
  bytes public otherImmutableArgs;
  bytes public initArgs;
  uint256 public hatId;

  address public org = makeAddr("org");
  address public owner = org;
  address public arbitrator = makeAddr("arbitratory");
  address public allowed1 = makeAddr("allowed1");
  address public allowed2 = makeAddr("allowed2");
  address public nonWearer = makeAddr("nonWearer");
  address public eligibility = makeAddr("eligibility");
  address public toggle = makeAddr("toggle");

  uint256 public tophat;
  uint256 public ownerHat;
  uint256 public arbitratorHat;
  uint256 public hatToClaim;

  bool public eligible;
  bool public badStanding;
  bool public standing;

  // AllowlistEligibility events
  event AccountAdded(address account);
  event AccountsAdded(address[] accounts);
  event AccountRemoved(address account);
  event AccountsRemoved(address[] accounts);
  event AccountStandingChanged(address account, bool standing);
  event AccountsStandingChanged(address[] accounts, bool[] standing);
  event OwnerHatSet(uint256 newOwnerHat);
  event ArbitratorHatSet(uint256 newArbitratorHat);

  // Hats events
  event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 amount);
  event WearerStandingChanged(uint256 hatId, address wearer, bool wearerStanding);

  string public MODULE_VERSION = "0.6.0-zksync";

  function setUp() public virtual {
    // create and activate a fork, at BLOCK_NUMBER
    // fork = vm.createSelectFork(vm.rpcUrl("mainnet"), BLOCK_NUMBER);

    // // deploy implementation via the script
    // prepare(false, MODULE_VERSION);
    // run();

    // // deploy the hats module factory
    // factory = deployModuleFactory(HATS, SALT, "test factory");
  }
}

contract WithInstanceTest is AllowlistEligibilityTest {
  function setUp() public virtual override {
    super.setUp();

    // set up the hats
    tophat = HATS.mintTopHat(org, "org's top hat", "images.org/tophat");
    vm.startPrank(org);
    ownerHat = HATS.createHat(tophat, "ownerHat", 1, eligibility, toggle, true, "images.org/ownerHat");
    arbitratorHat = HATS.createHat(tophat, "arbitratorHat", 1, eligibility, toggle, true, "images.org/arbitratorHat");
    hatToClaim = HATS.createHat(tophat, "hatToClaim", 1, address(1), toggle, true, "images.org/hatToClaim");
    HATS.mintHat(ownerHat, owner);
    HATS.mintHat(arbitratorHat, arbitrator);
    vm.stopPrank();

    // set up the other immutable args
    otherImmutableArgs = abi.encodePacked();

    // set up the init args
    initArgs = abi.encode(ownerHat, arbitratorHat);

    // deploy an instance of the module
	AllowlistEligibilityFactory factory = new AllowlistEligibilityFactory();
    instance = AllowlistEligibility(factory.deployModule(hatToClaim, address(HATS), initArgs, 1)); 

    // set the instance as the hatToClaim's eligibility
    vm.prank(org);
    HATS.changeHatEligibility(hatToClaim, address(instance));
  }

  function stateAssertions(address _account, bool _eligible, bool _standing) public {
    // state assertions
    (eligible, badStanding) = instance.allowlist(_account);
    assertEq(eligible, _eligible, "state: eligible");
    assertEq(badStanding, !_standing, "state: badStanding");
  }

  function moduleAssertions(address _account, bool _eligible, bool _standing) public {
    // eligibility module assertions
    (eligible, standing) = instance.getWearerStatus(_account, 0);
    assertEq(eligible, _eligible, "module: eligible");
    assertEq(standing, _standing, "module: standing");
  }
}

contract Deployment is WithInstanceTest {
  function test_initialization() public {
    address[] memory alloweds = new address[](2);
    alloweds[0] = allowed1;
    alloweds[1] = allowed2;

    // implementation
	AllowlistEligibility module = new AllowlistEligibility(MODULE_VERSION, address(HATS), hatId);
    module.setUp(abi.encode(ownerHat, arbitratorHat, alloweds));

    // instance
    vm.expectRevert(HatsModule.AlreadyInitialized.selector);
    module.setUp(abi.encode(ownerHat, arbitratorHat, alloweds));
  }

  function test_version() public {
    assertEq(instance.version(), MODULE_VERSION);
  }

  function test_implementation() public {
    assertEq(address(instance.IMPLEMENTATION()), address(instance));
  }

  function test_hats() public {
    assertEq(address(instance.HATS()), address(HATS));
  }

  function test_hatId() public {
    assertEq(instance.hatId(), hatToClaim);
  }

  function test_ownerHat() public {
    assertEq(instance.ownerHat(), ownerHat);
  }

  function test_arbitratorHat() public {
    assertEq(instance.arbitratorHat(), arbitratorHat);
  }
}

contract AddAccount is WithInstanceTest {
  function test_owner_canAdd() public {
    vm.expectEmit();
    emit AccountAdded(allowed1);

    vm.prank(owner);
    instance.addAccount(allowed1);

    stateAssertions(allowed1, true, true);
    moduleAssertions(allowed1, true, true);
  }

  function test_owner_canAddAnother() public {
    vm.expectEmit();
    emit AccountAdded(allowed2);

    vm.prank(owner);
    instance.addAccount(allowed2);

    stateAssertions(allowed2, true, true);
    moduleAssertions(allowed2, true, true);
  }

  function test_revert_nonOwner_cannotAdd() public {
    vm.expectRevert(AllowlistEligibility_NotOwner.selector);

    vm.prank(nonWearer);
    instance.addAccount(allowed1);

    stateAssertions(allowed1, false, true);
    moduleAssertions(allowed1, false, true);
  }
}

contract AddAccounts is WithInstanceTest {
  function test_owner_canAddTwoAccounts() public {
    address[] memory alloweds = new address[](2);
    alloweds[0] = allowed1;
    alloweds[1] = allowed2;

    vm.expectEmit();
    emit AccountsAdded(alloweds);

    vm.prank(owner);
    instance.addAccounts(alloweds);

    stateAssertions(allowed1, true, true);
    stateAssertions(allowed2, true, true);

    moduleAssertions(allowed1, true, true);
    moduleAssertions(allowed2, true, true);
  }

  function test_revert_nonOwner_cannotAddMultipleAccounts() public {
    address[] memory alloweds = new address[](2);
    alloweds[0] = allowed1;
    alloweds[1] = allowed2;

    vm.expectRevert(AllowlistEligibility_NotOwner.selector);

    vm.prank(nonWearer);
    instance.addAccounts(alloweds);

    stateAssertions(allowed1, false, true);
    stateAssertions(allowed2, false, true);

    moduleAssertions(allowed1, false, true);
    moduleAssertions(allowed2, false, true);
  }
}

contract RemoveAccount is WithInstanceTest {
  function test_owner_canRemove() public {
    vm.prank(owner);
    instance.addAccount(allowed1);

    vm.expectEmit();
    emit AccountRemoved(allowed1);

    vm.prank(owner);
    instance.removeAccount(allowed1);

    stateAssertions(allowed1, false, true);
    moduleAssertions(allowed1, false, true);
  }

  function test_revert_nonOwner_cannotRemove() public {
    vm.prank(owner);
    instance.addAccount(allowed1);

    vm.expectRevert(AllowlistEligibility_NotOwner.selector);

    vm.prank(nonWearer);
    instance.removeAccount(allowed1);

    stateAssertions(allowed1, true, true);
    moduleAssertions(allowed1, true, true);
  }
}

contract RemoveAccounts is WithInstanceTest {
  function test_owner_canRemoveTwoAccounts() public {
    address[] memory alloweds = new address[](2);
    alloweds[0] = allowed1;
    alloweds[1] = allowed2;

    vm.prank(owner);
    instance.addAccounts(alloweds);

    vm.expectEmit();
    emit AccountsRemoved(alloweds);

    vm.prank(owner);
    instance.removeAccounts(alloweds);

    stateAssertions(allowed1, false, true);
    stateAssertions(allowed2, false, true);

    moduleAssertions(allowed1, false, true);
    moduleAssertions(allowed2, false, true);
  }

  function test_revert_nonOwner_cannotRemoveMultipleAccounts() public {
    address[] memory alloweds = new address[](2);
    alloweds[0] = allowed1;
    alloweds[1] = allowed2;

    vm.prank(owner);
    instance.addAccounts(alloweds);

    vm.expectRevert(AllowlistEligibility_NotOwner.selector);

    vm.prank(nonWearer);
    instance.removeAccounts(alloweds);

    stateAssertions(allowed1, true, true);
    stateAssertions(allowed2, true, true);

    moduleAssertions(allowed1, true, true);
    moduleAssertions(allowed2, true, true);
  }
}

contract RemoveAccountAndBurnHat is WithInstanceTest {
  function test_wearer_owner_canRemoveAndBurn() public {
    vm.prank(owner);
    instance.addAccount(allowed1);

    vm.prank(org);
    HATS.mintHat(hatToClaim, allowed1);

    vm.expectEmit();
    emit AccountRemoved(allowed1);

    vm.expectEmit();
    emit TransferSingle(address(instance), allowed1, address(0), hatToClaim, 1); // burn event

    vm.prank(owner);
    instance.removeAccountAndBurnHat(allowed1);

    stateAssertions(allowed1, false, true);
    moduleAssertions(allowed1, false, true);
  }

  function test_revert_nonWearer_owner_cannotRemoveAndBurn() public {
    vm.prank(owner);
    instance.addAccount(allowed1);

    vm.expectRevert(AllowlistEligibility_NotWearer.selector);

    vm.prank(owner);
    instance.removeAccountAndBurnHat(allowed1);

    stateAssertions(allowed1, true, true);
    moduleAssertions(allowed1, true, true);
  }

  function test_revert_wearer_nonOwner_cannotRemoveAndBurn() public {
    vm.prank(owner);
    instance.addAccount(allowed1);

    vm.prank(org);
    HATS.mintHat(hatToClaim, allowed1);

    vm.expectRevert(AllowlistEligibility_NotOwner.selector);

    vm.prank(nonWearer);
    instance.removeAccountAndBurnHat(allowed1);

    stateAssertions(allowed1, true, true);
    moduleAssertions(allowed1, true, true);
  }

  function test_revert_nonWearer_nonOwner_cannotRemoveAndBurn() public {
    vm.prank(owner);
    instance.addAccount(allowed1);

    vm.prank(org);
    HATS.mintHat(hatToClaim, allowed1);

    vm.expectRevert(AllowlistEligibility_NotOwner.selector);

    vm.prank(nonWearer);
    instance.removeAccountAndBurnHat(allowed1);

    stateAssertions(allowed1, true, true);
    moduleAssertions(allowed1, true, true);
  }
}

contract SetStandingForAccount is WithInstanceTest {
  function test_arbitrator_forAdded_canSetStanding() public {
    vm.prank(owner);
    instance.addAccount(allowed1);

    // 1. set in bad standing
    vm.expectEmit();
    emit AccountStandingChanged(allowed1, false);

    vm.prank(arbitrator);
    instance.setStandingForAccount(allowed1, false);

    stateAssertions(allowed1, true, false);
    moduleAssertions(allowed1, false, false);

    // 2. return to good standing
    vm.expectEmit();
    emit AccountStandingChanged(allowed1, true);

    vm.prank(arbitrator);
    instance.setStandingForAccount(allowed1, true);

    stateAssertions(allowed1, true, true);
    moduleAssertions(allowed1, true, true);
  }

  function test_arbitrator_forNonAdded_canSetStanding() public {
    // 1. set in bad standing
    vm.expectEmit();
    emit AccountStandingChanged(allowed1, false);

    vm.prank(arbitrator);
    instance.setStandingForAccount(allowed1, false);

    stateAssertions(allowed1, false, false);
    moduleAssertions(allowed1, false, false);

    // 2. return to good standing
    vm.expectEmit();
    emit AccountStandingChanged(allowed1, true);

    vm.prank(arbitrator);
    instance.setStandingForAccount(allowed1, true);

    stateAssertions(allowed1, false, true);
    moduleAssertions(allowed1, false, true);
  }

  function test_revert_nonArbitrator_cannotSetStanding() public {
    vm.prank(owner);
    instance.addAccount(allowed1);

    vm.expectRevert(AllowlistEligibility_NotArbitrator.selector);

    vm.prank(nonWearer);
    instance.setStandingForAccount(allowed1, false);

    stateAssertions(allowed1, true, true);
    moduleAssertions(allowed1, true, true);
  }
}

contract SetStandingForAccounts is WithInstanceTest {
  function test_arbitrator_forAddedAndNonAdded_canSetStanding() public {
    address[] memory alloweds = new address[](2);
    alloweds[0] = allowed1;
    alloweds[1] = allowed2;

    vm.prank(owner);
    instance.addAccounts(alloweds);

    // set 1 to bad standing and 2 to good standing
    bool[] memory standings = new bool[](2);
    standings[0] = false;
    standings[1] = true;

    vm.expectEmit();
    emit AccountsStandingChanged(alloweds, standings);

    vm.prank(arbitrator);
    instance.setStandingForAccounts(alloweds, standings);

    stateAssertions(allowed1, true, false);
    stateAssertions(allowed2, true, true);

    moduleAssertions(allowed1, false, false);
    moduleAssertions(allowed2, true, true);
  }

  function test_revert_nonArbitrator_forAddedAndNonAdded_cannotSetStanding() public {
    address[] memory alloweds = new address[](2);
    alloweds[0] = allowed1;
    alloweds[1] = allowed2;

    vm.prank(owner);
    instance.addAccounts(alloweds);

    // attempt to set 1 to bad standing and 2 to good standing, expecting revert
    bool[] memory standings = new bool[](2);
    standings[0] = false;
    standings[1] = true;

    vm.expectRevert(AllowlistEligibility_NotArbitrator.selector);

    vm.prank(nonWearer);
    instance.setStandingForAccounts(alloweds, standings);

    stateAssertions(allowed1, true, true);
    stateAssertions(allowed2, true, true);

    moduleAssertions(allowed1, true, true);
    moduleAssertions(allowed2, true, true);
  }
}

contract SetBadStandingAndBurnHat is WithInstanceTest {
  function test_arbitrator_forWearer_canSetBadStandingAndBurnHat() public {
    vm.prank(owner);
    instance.addAccount(allowed1);

    vm.prank(org);
    HATS.mintHat(hatToClaim, allowed1);

    vm.expectEmit();
    emit AccountStandingChanged(allowed1, false);

    vm.expectEmit();
    emit TransferSingle(address(instance), allowed1, address(0), hatToClaim, 1); // burn event

    vm.expectEmit();
    emit WearerStandingChanged(hatToClaim, allowed1, false);

    vm.prank(arbitrator);
    instance.setBadStandingAndBurnHat(allowed1);

    stateAssertions(allowed1, true, false);
    moduleAssertions(allowed1, false, false);
  }

  function test_revert_arbitrator_forNonWearer_cannotSetBadStandingAndBurnHat() public {
    vm.prank(owner);
    instance.addAccount(allowed1);

    vm.expectRevert(AllowlistEligibility_NotWearer.selector);

    vm.prank(arbitrator);
    instance.setBadStandingAndBurnHat(allowed1);

    stateAssertions(allowed1, true, true);
    moduleAssertions(allowed1, true, true);
  }

  function test_revert_nonArbitrator_cannotSetBadStandingAndBurnHat() public {
    vm.prank(owner);
    instance.addAccount(allowed1);

    vm.prank(org);
    HATS.mintHat(hatToClaim, allowed1);

    vm.expectRevert(AllowlistEligibility_NotArbitrator.selector);

    vm.prank(nonWearer);
    instance.setBadStandingAndBurnHat(allowed1);

    stateAssertions(allowed1, true, true);
    moduleAssertions(allowed1, true, true);
  }
}

contract SetOwnerHat is WithInstanceTest {
  function test_owner_mutable() public {
    uint256 newOwnerHat = 1;
    vm.expectEmit();
    emit OwnerHatSet(newOwnerHat);

    vm.prank(owner);
    instance.setOwnerHat(newOwnerHat);
  }

  function test_revert_nonOwner_mutable() public {
    uint256 newOwnerHat = 1;
    vm.expectRevert(AllowlistEligibility_NotOwner.selector);

    vm.prank(nonWearer);
    instance.setOwnerHat(newOwnerHat);
  }

  function test_revert_owner_immutable() public {
    uint256 newOwnerHat = 1;

    vm.prank(org);
    HATS.makeHatImmutable(hatToClaim);

    vm.expectRevert(AllowlistEligibility_HatNotMutable.selector);

    vm.prank(owner);
    instance.setOwnerHat(newOwnerHat);
  }
}

contract SetArbitratorHat is WithInstanceTest {
  function test_owner_mutable() public {
    uint256 newArbitratorHat = 1;
    vm.expectEmit();
    emit ArbitratorHatSet(newArbitratorHat);

    vm.prank(owner);
    instance.setArbitratorHat(newArbitratorHat);
  }

  function test_revert_nonOwner_mutable() public {
    uint256 newArbitratorHat = 1;
    vm.expectRevert(AllowlistEligibility_NotOwner.selector);

    vm.prank(nonWearer);
    instance.setArbitratorHat(newArbitratorHat);
  }

  function test_revert_owner_immutable() public {
    uint256 newArbitratorHat = 1;

    vm.prank(org);
    HATS.makeHatImmutable(hatToClaim);

    vm.expectRevert(AllowlistEligibility_HatNotMutable.selector);

    vm.prank(owner);
    instance.setArbitratorHat(newArbitratorHat);
  }
}
