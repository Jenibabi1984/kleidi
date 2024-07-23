// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

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
import {CallHelper} from "test/utils/CallHelper.t.sol";
import {MockLending} from "test/mock/MockLending.sol";
import {TimelockFactory} from "src/TimelockFactory.sol";
import {MockReentrancyExecutor} from "test/mock/MockReentrancyExecutor.sol";
import {
    _DONE_TIMESTAMP,
    MIN_DELAY,
    MIN_DELAY as MINIMUM_DELAY,
    MAX_DELAY
} from "src/utils/Constants.sol";

contract TimelockUnitFixture is CallHelper {
    /// @notice reference to the Timelock contract
    Timelock public timelock;

    /// @notice timelock factory
    TimelockFactory public timelockFactory;

    /// @notice reference to the MockSafe contract
    MockSafe public safe;

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

    /// @notice expiration period for a timelocked transaction in seconds
    uint256 public constant EXPIRATION_PERIOD = 5 days;

    /// @notice salt for timelock creation through the factory
    bytes32 public constant salt = keccak256(hex"3afe");

    function setUp() public {
        // at least start at unix timestamp of 1m so that block timestamp isn't 0
        vm.warp(block.timestamp + 1_000_000 + EXPIRATION_PERIOD);

        safe = new MockSafe();

        timelockFactory = new TimelockFactory();

        // Assume the necessary parameters for the constructor
        timelock = Timelock(
            payable(
                timelockFactory.createTimelock(
                    address(safe), // _safe
                    MINIMUM_DELAY, // _minDelay
                    EXPIRATION_PERIOD, // _expirationPeriod
                    guardian, // _pauser
                    PAUSE_DURATION, // _pauseDuration
                    contractAddresses, // contractAddresses
                    selector, // selector
                    startIndex, // startIndex
                    endIndex, // endIndex
                    data, // data
                    salt
                )
            )
        );
    }
}