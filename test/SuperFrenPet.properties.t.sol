// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {SuperFrenPet} from "src/SuperFrenPet.sol";

/// @dev Complements the original examples with arithmetic boundaries and multi-call properties.
/// forge-config: default.fuzz.runs = 1024
contract SuperFrenPetPropertiesTest is Test {
    uint256 internal constant SUPPLY = 1_000_000_000 * 10 ** 18;
    SuperFrenPet internal token;
    address internal alice;
    address internal bob;
    address internal spender;

    function setUp() public {
        token = new SuperFrenPet();
        alice = makeAddr("property alice");
        bob = makeAddr("property bob");
        spender = makeAddr("property spender");
    }

    function test_OneWeiCanBeTransferredAndReturned() public {
        assertTrue(token.transfer(alice, 1));
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(address(this)), SUPPLY - 1);
        vm.prank(alice);
        assertTrue(token.transfer(address(this), 1));
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_TransferMaximumUintRevertsWithoutOverflow() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(this), SUPPLY, type(uint256).max
            )
        );
        token.transfer(alice, type(uint256).max);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_MaximumFiniteAllowanceIsSpentWhenMovingEntireSupply() public {
        uint256 approved = type(uint256).max - 1;
        assertTrue(token.approve(spender, approved));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, SUPPLY));
        assertEq(token.allowance(address(this), spender), approved - SUPPLY);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(alice), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_InfiniteApprovalCannotTransferMaximumUintWithoutBalance() public {
        assertTrue(token.approve(spender, type(uint256).max));
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(this), SUPPLY, type(uint256).max
            )
        );
        vm.prank(spender);
        token.transferFrom(address(this), bob, type(uint256).max);
        assertEq(token.allowance(address(this), spender), type(uint256).max);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_DelegatedSelfTransferStillRequiresBalance() public {
        assertTrue(token.transfer(alice, 1));
        vm.prank(alice);
        assertTrue(token.approve(spender, 2));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 1, 2));
        vm.prank(spender);
        token.transferFrom(alice, alice, 2);
        assertEq(token.allowance(alice, spender), 2);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(address(this)), SUPPLY - 1);
    }

    function test_TransferFromByOwnerRequiresAndConsumesSelfApproval() public {
        assertTrue(token.transfer(alice, 2));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, alice, 0, 1));
        vm.prank(alice);
        token.transferFrom(alice, bob, 1);
        assertEq(token.balanceOf(alice), 2);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.allowance(alice, alice), 0);

        vm.startPrank(alice);
        assertTrue(token.approve(alice, 1));
        assertTrue(token.transferFrom(alice, bob, 1));
        vm.stopPrank();
        assertEq(token.allowance(alice, alice), 0);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(bob), 1);
    }

    function test_SpenderCannotPassItsApprovalToAnotherSpender() public {
        assertTrue(token.transfer(alice, 10));
        vm.prank(alice);
        assertTrue(token.approve(spender, 10));
        vm.prank(spender);
        assertTrue(token.approve(bob, type(uint256).max));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, bob, 0, 1));
        vm.prank(bob);
        token.transferFrom(alice, bob, 1);
        assertEq(token.balanceOf(alice), 10);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.balanceOf(spender), 0);
        assertEq(token.allowance(alice, spender), 10);
        assertEq(token.allowance(alice, bob), 0);
        assertEq(token.allowance(spender, bob), type(uint256).max);
    }

    function test_RevokingOneSpenderLeavesOtherSpenderAuthorized() public {
        assertTrue(token.approve(spender, type(uint256).max));
        assertTrue(token.approve(bob, 2));
        assertTrue(token.approve(spender, 0));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(address(this), alice, 1);
        vm.prank(bob);
        assertTrue(token.transferFrom(address(this), bob, 2));
        assertEq(token.allowance(address(this), bob), 0);
        assertEq(token.allowance(address(this), spender), 0);
        assertEq(token.balanceOf(bob), 2);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY - 2);
    }

    function test_ReplacingInfiniteApprovalWithFiniteApprovalEnforcesNewLimit() public {
        assertTrue(token.approve(spender, type(uint256).max));
        assertTrue(token.approve(spender, 1));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 1, 2));
        vm.prank(spender);
        token.transferFrom(address(this), bob, 2);
        assertEq(token.allowance(address(this), spender), 1);
        assertEq(token.balanceOf(bob), 0);
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), bob, 1));
        assertEq(token.allowance(address(this), spender), 0);
        assertEq(token.balanceOf(bob), 1);
        assertEq(token.balanceOf(address(this)), SUPPLY - 1);
    }

    function test_ZeroDelegatedTransferToZeroRevertsWithInfiniteApproval() public {
        assertTrue(token.approve(spender, type(uint256).max));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(spender);
        token.transferFrom(address(this), address(0), 0);
        assertEq(token.allowance(address(this), spender), type(uint256).max);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_RepeatedApprovalIsIdempotentAndDoesNotMoveTokens(uint256 approved) public {
        assertTrue(token.transfer(alice, SUPPLY / 2));
        vm.startPrank(alice);
        assertTrue(token.approve(spender, approved));
        assertTrue(token.approve(spender, approved));
        vm.stopPrank();
        assertEq(token.allowance(alice, spender), approved);
        assertEq(token.allowance(spender, alice), 0);
        assertEq(token.allowance(address(this), spender), 0);
        assertEq(token.balanceOf(alice), SUPPLY / 2);
        assertEq(token.balanceOf(address(this)), SUPPLY / 2);
        assertEq(token.balanceOf(spender), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_TransferRoundTripRestoresDistribution(uint256 initialAlice, uint256 amount) public {
        initialAlice = bound(initialAlice, 0, SUPPLY);
        amount = bound(amount, 0, initialAlice);
        assertTrue(token.transfer(alice, initialAlice));
        assertTrue(token.transfer(bob, SUPPLY - initialAlice));
        vm.prank(alice);
        assertTrue(token.transfer(bob, amount));
        assertEq(token.balanceOf(alice), initialAlice - amount);
        assertEq(token.balanceOf(bob), SUPPLY - initialAlice + amount);
        vm.prank(bob);
        assertTrue(token.transfer(alice, amount));
        assertEq(token.balanceOf(alice), initialAlice);
        assertEq(token.balanceOf(bob), SUPPLY - initialAlice);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_DelegatedAndDirectTransfersHaveIdenticalBalanceEffects(
        uint256 initialAlice,
        uint256 amount,
        uint256 approved,
        bool selfTransfer
    ) public {
        SuperFrenPet direct = new SuperFrenPet();
        initialAlice = bound(initialAlice, 0, SUPPLY);
        amount = bound(amount, 0, initialAlice);
        approved = bound(approved, amount, type(uint256).max);
        assertTrue(token.transfer(alice, initialAlice));
        assertTrue(direct.transfer(alice, initialAlice));
        address to = selfTransfer ? alice : bob;
        vm.startPrank(alice);
        assertTrue(token.approve(spender, approved));
        assertTrue(direct.transfer(to, amount));
        vm.stopPrank();
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, to, amount));

        assertEq(token.balanceOf(alice), direct.balanceOf(alice));
        assertEq(token.balanceOf(bob), direct.balanceOf(bob));
        assertEq(token.balanceOf(address(this)), direct.balanceOf(address(this)));
        assertEq(token.balanceOf(spender), 0);
        assertEq(token.allowance(alice, spender), approved == type(uint256).max ? approved : approved - amount);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(direct.totalSupply(), SUPPLY);
    }

    function testFuzz_SplittingDelegatedSpendDoesNotChangeBalancesOrAllowance(
        uint256 amount,
        uint256 firstPart,
        uint256 approved
    ) public {
        SuperFrenPet single = new SuperFrenPet();
        amount = bound(amount, 0, SUPPLY);
        firstPart = bound(firstPart, 0, amount);
        approved = bound(approved, amount, type(uint256).max);
        assertTrue(token.approve(spender, approved));
        assertTrue(single.approve(spender, approved));
        vm.startPrank(spender);
        assertTrue(token.transferFrom(address(this), alice, firstPart));
        assertTrue(token.transferFrom(address(this), alice, amount - firstPart));
        assertTrue(single.transferFrom(address(this), alice, amount));
        vm.stopPrank();
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(alice), single.balanceOf(alice));
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);
        assertEq(token.balanceOf(address(this)), single.balanceOf(address(this)));
        assertEq(token.allowance(address(this), spender), single.allowance(address(this), spender));
        assertEq(token.allowance(address(this), spender), approved == type(uint256).max ? approved : approved - amount);
        assertEq(token.balanceOf(spender), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_FailedDelegatedTransferCanBeRetriedAfterFunding(
        uint256 initialAlice,
        uint256 amount,
        bool unlimited
    ) public {
        initialAlice = bound(initialAlice, 0, SUPPLY - 1);
        amount = bound(amount, initialAlice + 1, SUPPLY);
        assertTrue(token.transfer(alice, initialAlice));
        uint256 approved = unlimited ? type(uint256).max : amount;
        vm.prank(alice);
        assertTrue(token.approve(spender, approved));
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, initialAlice, amount)
        );
        vm.prank(spender);
        token.transferFrom(alice, bob, amount);
        assertEq(token.allowance(alice, spender), approved);
        assertEq(token.balanceOf(alice), initialAlice);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY - initialAlice);

        assertTrue(token.transfer(alice, amount - initialAlice));
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, amount));
        assertEq(token.allowance(alice, spender), unlimited ? type(uint256).max : 0);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), amount);
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_FailedDelegatedTransferCanBeRetriedAfterApproval(uint256 amount, uint256 insufficient) public {
        amount = bound(amount, 1, SUPPLY);
        insufficient = bound(insufficient, 0, amount - 1);
        assertTrue(token.approve(spender, insufficient));
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, insufficient, amount)
        );
        vm.prank(spender);
        token.transferFrom(address(this), bob, amount);
        assertEq(token.allowance(address(this), spender), insufficient);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(bob), 0);

        assertTrue(token.approve(spender, amount));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), bob, amount));
        assertEq(token.allowance(address(this), spender), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);
        assertEq(token.balanceOf(bob), amount);
        assertEq(token.totalSupply(), SUPPLY);
    }
}
