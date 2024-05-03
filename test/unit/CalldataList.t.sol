// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC1155Receiver} from
    "@openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC721Receiver} from
    "@openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {
    IERC165,
    ERC165
} from "@openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";

import {Test, console} from "forge-std/Test.sol";

import {Timelock} from "src/Timelock.sol";
import {MockSafe} from "test/mock/MockSafe.sol";
import {MockLending} from "test/mock/MockLending.sol";

contract CalldataListUnitTest is Test {
    /// @notice reference to the Timelock contract
    Timelock private timelock;

    /// @notice reference to the MockSafe contract
    MockSafe private safe;

    /// @notice reference to the MockLending contract
    MockLending private lending;

    /// @notice empty for now, will change once tests progress
    address[] public contractAddresses;

    /// @notice empty for now, will change once tests progress
    bytes4[] public selector;

    /// @notice empty for now, will change once tests progress
    uint16[] public startIndex;

    /// @notice empty for now, will change once tests progress
    uint16[] public endIndex;

    /// @notice empty for now, will change once tests progress
    bytes[] public data;

    /// @notice address of the guardian that can pause and break glass in case of emergency
    address public guardian = address(0x11111);

    /// @notice duration of pause once glass is broken in seconds
    uint128 public constant PAUSE_DURATION = 10 days;

    /// @notice minimum delay for a timelocked transaction in seconds
    uint256 public constant MINIMUM_DELAY = 1 days;

    /// @notice expiration period for a timelocked transaction in seconds
    uint256 public constant EXPIRATION_PERIOD = 5 days;

    function setUp() public {
        // at least start at unix timestamp of 1m so that block timestamp isn't 0
        vm.warp(block.timestamp + 1_000_000);

        safe = new MockSafe();

        lending = new MockLending();

        // Assume the necessary parameters for the constructor
        timelock = new Timelock(
            address(safe), // _safe
            MINIMUM_DELAY, // _minDelay
            EXPIRATION_PERIOD, // _expirationPeriod
            guardian, // _pauser
            PAUSE_DURATION, // _pauseDuration
            contractAddresses, // contractAddresses
            selector, // selector
            startIndex, // startIndex
            endIndex, // endIndex
            data // data
        );
    }

    function testArityMismatchAddCalldataChecks() public {
        address[] memory targets = new address[](1);
        targets[0] = address(timelock);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        address[] memory targetAddresses = new address[](2);
        targetAddresses[0] = address(lending);
        targetAddresses[1] = address(lending);

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = MockLending.deposit.selector;
        selectors[1] = MockLending.withdraw.selector;

        /// compare first 20 bytes
        uint16[] memory startIndexes = new uint16[](2);
        startIndexes[0] = 16;
        startIndexes[1] = 16;

        uint16[] memory endIndexes = new uint16[](2);
        endIndexes[0] = 36;
        endIndexes[1] = 36;

        /// can only deposit to timelock
        bytes[] memory checkedCalldata = new bytes[](1);
        checkedCalldata[0] = abi.encodePacked(address(timelock));

        vm.expectRevert("CalldataList: Array lengths must be equal");
        vm.prank(address(timelock));
        timelock.addCalldataChecks(
            targetAddresses,
            selectors,
            startIndexes,
            endIndexes,
            checkedCalldata
        );
    }

    function testAddCalldataCheckFailsStartIndexLt4() public {
        vm.prank(address(timelock));
        vm.expectRevert("CalldataList: Start index must be greater than 3");
        timelock.addCalldataCheck(
            address(lending),
            MockLending.deposit.selector,
            3,
            4,
            abi.encodePacked(address(timelock))
        );
    }

    function testAddCalldataCheckFailsStartIndexEqEndIndex() public {
        vm.prank(address(timelock));
        vm.expectRevert(
            "CalldataList: End index must be greater than start index"
        );
        timelock.addCalldataCheck(
            address(lending),
            MockLending.deposit.selector,
            4,
            4,
            abi.encodePacked(address(timelock))
        );
    }

    function testAddCalldataCheckFailsStartIndexGtEndIndex() public {
        vm.prank(address(timelock));
        vm.expectRevert(
            "CalldataList: End index must be greater than start index"
        );
        timelock.addCalldataCheck(
            address(lending),
            MockLending.deposit.selector,
            4,
            3,
            abi.encodePacked(address(timelock))
        );
    }

    function testAddCalldataCheckFailsWhitelistedCalldataTimelock() public {
        vm.prank(address(timelock));
        vm.expectRevert("CalldataList: Contract address cannot be this");
        timelock.addCalldataCheck(
            address(timelock),
            Timelock.schedule.selector,
            4,
            5,
            abi.encodePacked(address(timelock))
        );
    }
}