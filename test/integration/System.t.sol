// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC1155Receiver} from
    "@openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import {SafeProxyFactory} from "@safe/proxies/SafeProxyFactory.sol";
import {IERC721Receiver} from
    "@openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {
    IERC165,
    ERC165
} from "@openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ModuleManager} from "@safe/base/ModuleManager.sol";
import {GuardManager} from "@safe/base/GuardManager.sol";
import {SafeL2} from "@safe/SafeL2.sol";

import {Test, console} from "forge-std/Test.sol";

import {Enum} from "@safe/common/Enum.sol";
import {Timelock} from "src/Timelock.sol";
import {BytesHelper} from "src/BytesHelper.sol";
import {TimeRestricted} from "src/TimeRestricted.sol";
import {
    IMorpho,
    Position,
    IMorphoBase,
    MarketParams
} from "src/interface/IMorpho.sol";

interface call3 {
    struct Call3 {
        // Target contract to call.
        address target;
        // If false, the entire call will revert if the call fails.
        bool allowFailure;
        // Data to call on the target contract.
        bytes callData;
    }

    struct Result {
        // True if the call succeeded, false otherwise.
        bool success;
        // Return data if the call succeeded, or revert data if the call reverted.
        bytes returnData;
    }

    /// @notice Aggregate calls, ensuring each returns success if required
    /// @param calls An array of Call3 structs
    /// @return returnData An array of Result structs
    function aggregate3(Call3[] calldata calls)
        external
        payable
        returns (Result[] memory returnData);
}

contract SystemIntegrationTest is Test {
    using BytesHelper for bytes;

    /// @notice reference to the Timelock contract
    Timelock private timelock;

    /// @notice reference to the deployed Safe contract
    SafeL2 private safe;

    /// @notice reference to the TimeRestricted contract
    TimeRestricted public restricted;

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

    /// @notice first private key
    uint256 public constant pk1 = 4;

    /// @notice second private key
    uint256 public constant pk2 = 2;

    /// @notice third private key
    uint256 public constant pk3 = 3;

    /// @notice address of the factory contract
    SafeProxyFactory public constant factory =
        SafeProxyFactory(0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2);

    /// @notice address of the logic contract
    address public logic = 0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552;

    /// @notice address of the multicall contract
    address public multicall = 0xcA11bde05977b3631167028862bE2a173976CA11;

    /// @notice address of the morphoBlue contract
    address public morphoBlue = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    /// @notice address of the ethena token contract
    address public ethenaUsd = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;

    /// @notice address of the dai token contract
    address public constant dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    /// @notice address of the irm contract
    address public constant irm = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;

    /// @notice address of the oracle contract
    address public constant oracle = 0xaE4750d0813B5E37A51f7629beedd72AF1f9cA35;

    /// @notice liquidation loan to value ratio
    uint256 public constant lltv = 915000000000000000;

    /// @notice storage slot for the guard
    /// keccak256("guard_manager.guard.address")
    uint256 private constant GUARD_STORAGE_SLOT =
        0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;

    address[] public owners;

    uint256 public startTimestamp;

    function setUp() public {
        startTimestamp = block.timestamp;

        restricted = new TimeRestricted();

        owners.push(vm.addr(pk1));
        owners.push(vm.addr(pk2));
        owners.push(vm.addr(pk3));

        bytes memory initdata = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners,
            2,
            address(0),
            "",
            address(0),
            address(0),
            0,
            address(0)
        );

        safe = SafeL2(
            payable(address(factory.createProxyWithNonce(logic, initdata, 0)))
        );

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

    function testSafeSetup() public view {
        (address[] memory modules,) = safe.getModulesPaginated(address(1), 10);
        assertEq(
            modules.length, 0, "incorrect modules length, none should exist"
        );

        address[] memory currentOwners = safe.getOwners();
        assertEq(currentOwners.length, 3, "incorrect owners length");

        assertEq(currentOwners[0], vm.addr(pk1), "incorrect owner 1");
        assertEq(currentOwners[1], vm.addr(pk2), "incorrect owner 2");
        assertEq(currentOwners[2], vm.addr(pk3), "incorrect owner 3");

        assertTrue(safe.isOwner(vm.addr(pk1)), "pk1 is not an owner");
        assertTrue(safe.isOwner(vm.addr(pk2)), "pk2 is not an owner");
        assertTrue(safe.isOwner(vm.addr(pk3)), "pk3 is not an owner");

        assertEq(safe.getThreshold(), 2, "incorrect threshold");

        bytes32 fallbackHandler = vm.load(
            address(safe),
            0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5
        );
        assertEq(fallbackHandler, bytes32(0), "fallback handler is not 0");

        bytes32 guard = vm.load(
            address(safe),
            0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8
        );
        assertEq(guard, bytes32(0), "guard is not 0");

        assertEq(safe.nonce(), 0, "incorrect nonce");
    }

    function testTimelockSetup() public view {
        assertEq(timelock.safe(), address(safe), "incorrect safe address");
        assertEq(timelock.minDelay(), MINIMUM_DELAY, "incorrect min delay");
        assertEq(
            timelock.expirationPeriod(),
            EXPIRATION_PERIOD,
            "incorrect expiration period"
        );
        assertEq(timelock.pauseGuardian(), guardian, "incorrect pauser");
        assertEq(
            timelock.pauseDuration(), PAUSE_DURATION, "incorrect pause duration"
        );
    }

    ///
    /// 2. Queue and execute a transaction in the Gnosis Safe to perform the following actions:
    ///  - initialize configuration with the timelock address, and allowed time ranges and their corresponding allowed days
    ///  - add the guard to the Safe
    ///  - add the Timelock as a Safe module

    ///
    /// construction of initial setup call in this system:
    ///  1. call to SafeRestriction contract to initialize configuration
    ///  with the timelock address, and allowed time ranges and their
    ///  corresponding allowed days.
    /// 2. call to `setGuard` with the address of the time-restriction contract on the safe
    /// 3. call `enableModule` with the address of the timelock on the safe
    ///
    /// Notes:
    ///   This should be wrapped in a single call to the Safe contract.
    ///   Use multicall to execute the calls in a single transaction.
    ///
    ///
    /// construction of all calls within this system outside of setup:
    ///    safe calls timelock, timelock calls external contracts
    ///    encoding:
    ///       1. gather array of addresses, values and bytes for the calls
    ///       2. encode the array of calls to call the scheduleBatch function on the timelock
    ///       3. encode this data to call the Safe contract
    ///
    ///
    function testInitializeContract() public {
        call3.Call3[] memory calls3 = new call3.Call3[](3);

        calls3[0].target = address(restricted);
        calls3[0].allowFailure = false;

        calls3[1].target = address(safe);
        calls3[1].allowFailure = false;

        calls3[2].target = address(safe);
        calls3[2].allowFailure = false;

        {
            uint8[] memory allowedDays = new uint8[](5);
            allowedDays[0] = 1;
            allowedDays[1] = 2;
            allowedDays[2] = 3;
            allowedDays[3] = 4;
            allowedDays[4] = 5;

            TimeRestricted.TimeRange[] memory ranges =
                new TimeRestricted.TimeRange[](5);

            ranges[0] = TimeRestricted.TimeRange(10, 11);
            ranges[1] = TimeRestricted.TimeRange(10, 11);
            ranges[2] = TimeRestricted.TimeRange(12, 13);
            ranges[3] = TimeRestricted.TimeRange(10, 14);
            ranges[4] = TimeRestricted.TimeRange(11, 13);

            calls3[0].callData = abi.encodeWithSelector(
                restricted.initializeConfiguration.selector,
                address(timelock),
                ranges,
                allowedDays
            );
        }

        calls3[1].callData = abi.encodeWithSelector(
            GuardManager.setGuard.selector, address(restricted)
        );

        calls3[2].callData = abi.encodeWithSelector(
            ModuleManager.enableModule.selector, address(timelock)
        );

        bytes memory safeData =
            abi.encodeWithSelector(call3.aggregate3.selector, calls3);

        bytes32 transactionHash = safe.getTransactionHash(
            multicall,
            0,
            safeData,
            Enum.Operation.DelegateCall,
            0,
            0,
            0,
            address(0),
            address(0),
            safe.nonce()
        );

        bytes memory collatedSignatures = signTxAllOwners(transactionHash);

        safe.checkNSignatures(transactionHash, safeData, collatedSignatures, 3);

        safe.execTransaction(
            multicall,
            0,
            safeData,
            Enum.Operation.DelegateCall,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            collatedSignatures
        );

        bytes memory guardBytes =
            SafeL2(payable(safe)).getStorageAt(GUARD_STORAGE_SLOT, 1);

        address guard = address(uint160(uint256(guardBytes.getFirstWord())));

        assertEq(guard, address(restricted), "guard is not restricted");
        assertTrue(
            safe.isModuleEnabled(address(timelock)), "timelock not a module"
        );

        assertEq(
            restricted.authorizedTimelock(address(safe)),
            address(timelock),
            "timelock not set correctly"
        );
        assertTrue(restricted.safeEnabled(address(safe)), "safe not enabled");

        uint256[] memory daysEnabled = restricted.safeDaysEnabled(address(safe));

        assertEq(
            restricted.numDaysEnabled(address(safe)),
            5,
            "incorrect days enabled length"
        );
        assertEq(daysEnabled.length, 5, "incorrect days enabled length");
        assertEq(daysEnabled[0], 1, "incorrect day 1");
        assertEq(daysEnabled[1], 2, "incorrect day 2");
        assertEq(daysEnabled[2], 3, "incorrect day 3");
        assertEq(daysEnabled[3], 4, "incorrect day 4");
        assertEq(daysEnabled[4], 5, "incorrect day 5");

        {
            (uint8 startHour, uint8 endHour) =
                restricted.dayTimeRanges(address(safe), 1);
            assertEq(startHour, 10, "incorrect start hour");
            assertEq(endHour, 11, "incorrect end hour");
        }

        {
            (uint8 startHour, uint8 endHour) =
                restricted.dayTimeRanges(address(safe), 2);
            assertEq(startHour, 10, "incorrect start hour");
            assertEq(endHour, 11, "incorrect end hour");
        }
        {
            (uint8 startHour, uint8 endHour) =
                restricted.dayTimeRanges(address(safe), 3);
            assertEq(startHour, 12, "incorrect start hour");
            assertEq(endHour, 13, "incorrect end hour");
        }
        {
            (uint8 startHour, uint8 endHour) =
                restricted.dayTimeRanges(address(safe), 4);
            assertEq(startHour, 10, "incorrect start hour");
            assertEq(endHour, 14, "incorrect end hour");
        }
        {
            (uint8 startHour, uint8 endHour) =
                restricted.dayTimeRanges(address(safe), 5);
            assertEq(startHour, 11, "incorrect start hour");
            assertEq(endHour, 13, "incorrect end hour");
        }
    }

    ///
    /// construction of all calls within this system outside of setup:
    ///    safe calls timelock, timelock calls external contracts
    ///    encoding:
    ///       1. gather array of addresses, values and bytes for the calls
    ///       2. encode the array of calls to call the scheduleBatch function on the timelock
    ///       3. encode this data to call the Safe contract
    ///

    function testTransactionAddingWhitelistedCalldataSucced() public {
        testInitializeContract();

        address[] memory calls = new address[](1);
        calls[0] = address(timelock);

        bytes memory innerCalldatas;
        bytes memory contractCall;
        {
            /// each morpho blue function call needs two checks:
            /// 1). check the pool id where funds are being deposited is whitelisted.
            /// 2). check the recipient of the funds is whitelisted whether withdrawing
            /// or depositing.

            uint16[] memory startIndexes = new uint16[](8);
            /// morpho blue supply
            startIndexes[0] = 4;
            /// only grab last twenty bytes of the 7th argument
            startIndexes[1] = 4 + 32 * 7 + 12;
            /// ethena usd approve morpho
            startIndexes[2] = 16;
            /// only check last twenty bytes of the 1st argument
            startIndexes[3] = 4 + 32 * 8 + 12;
            /// only grab last twenty bytes of the 8th argument
            startIndexes[4] = 4 + 32 * 8 + 12;
            /// only grab last twenty bytes of the 8th argument
            startIndexes[5] = 4 + 32 * 8 + 12;
            /// only grab last twenty bytes of the 8th argument
            startIndexes[6] = 4 + 32 * 6 + 12;
            /// only grab last twenty bytes of the 7th argument
            startIndexes[7] = 4 + 32 * 8 + 12;
            /// only grab last twenty bytes of the 8th argument

            uint16[] memory endIndexes = new uint16[](8);
            /// morpho blue supply
            endIndexes[0] = startIndexes[0] + 32 * 5;
            /// last twenty bytes represents who supplying on behalf of
            endIndexes[1] = startIndexes[1] + 20;
            /// ethena usd approve morpho
            endIndexes[2] = startIndexes[2] + 20;
            /// last twenty bytes represents who is approved to spend the tokens
            /// morpho borrow
            endIndexes[3] = startIndexes[3] + 20;
            /// morpho repay
            endIndexes[4] = startIndexes[4] + 20;
            /// morpho withdraw
            endIndexes[5] = startIndexes[5] + 20;
            /// last twenty bytes represents asset receiver
            endIndexes[6] = startIndexes[6] + 20;
            /// last twenty bytes represents asset receiver
            endIndexes[7] = startIndexes[7] + 20;
            /// last twenty bytes represents asset receiver

            bytes4[] memory selectors = new bytes4[](8);
            selectors[0] = IMorphoBase.supply.selector;
            selectors[1] = IMorphoBase.supply.selector;
            selectors[2] = IERC20.approve.selector;
            selectors[3] = IMorphoBase.borrow.selector;
            selectors[4] = IMorphoBase.repay.selector;
            selectors[5] = IMorphoBase.withdraw.selector;
            /// if borrowable assets are supplied to a market where there is bad debt, there is a possibility of loss
            /// so the timelock should be the only one allowed to supply borrowable assets to the whitelisted market
            /// supplying collateral to markets with bad debt should not pose a risk to capital because the
            /// collateral is not borrowed
            selectors[6] = IMorphoBase.supplyCollateral.selector;
            selectors[7] = IMorphoBase.withdrawCollateral.selector;

            bytes[] memory calldatas = new bytes[](8);
            calldatas[0] = abi.encode(dai, ethenaUsd, oracle, irm, lltv);
            /// can only deposit to dai/eusd pool
            calldatas[1] = abi.encodePacked(timelock);
            /// can only deposit to timelock
            calldatas[2] = abi.encodePacked(morphoBlue);
            /// morpho blue address can be approved to spend eUSD
            calldatas[3] = abi.encode(dai, ethenaUsd, oracle, irm, lltv);
            /// not packed because the MarketParams struct is not packed
            calldatas[4] = abi.encodePacked(timelock);
            /// can only deposit to timelock
            calldatas[5] = abi.encodePacked(timelock);
            /// can only repay on behalf of timelock
            calldatas[6] = abi.encodePacked(timelock);
            /// can only supply collateral on behalf of timelock
            calldatas[7] = abi.encodePacked(timelock);
            /// can only withdraw collateral back to timelock

            address[] memory targets = new address[](8);
            targets[0] = morphoBlue;
            targets[1] = morphoBlue;
            targets[2] = ethenaUsd;
            targets[3] = morphoBlue;
            targets[4] = morphoBlue;
            targets[5] = morphoBlue;
            targets[6] = morphoBlue;
            targets[7] = morphoBlue;

            contractCall = abi.encodeWithSelector(
                Timelock.addCalldataChecks.selector,
                targets,
                selectors,
                startIndexes,
                endIndexes,
                calldatas
            );

            /// inner calldata
            innerCalldatas = abi.encodeWithSelector(
                Timelock.schedule.selector,
                address(timelock),
                0,
                contractCall,
                bytes32(0),
                /// salt
                timelock.minDelay()
            );
        }

        bytes32 transactionHash = safe.getTransactionHash(
            address(timelock),
            0,
            innerCalldatas,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            address(0),
            safe.nonce()
        );

        bytes memory collatedSignatures = signTxAllOwners(transactionHash);

        safe.checkNSignatures(
            transactionHash, innerCalldatas, collatedSignatures, 3
        );

        vm.warp(1714565295);

        safe.execTransaction(
            address(timelock),
            0,
            innerCalldatas,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            collatedSignatures
        );

        vm.warp(block.timestamp + timelock.minDelay());

        vm.prank(owners[0]);
        timelock.execute(address(timelock), 0, contractCall, bytes32(0));
    }

    function testExecuteWhitelistedCalldataSucceedsSupplyCollateral() public {
        testTransactionAddingWhitelistedCalldataSucced();

        /// warp to current timestamp to prevent math underflow
        /// with cached timestamp in the future which doesn't work
        vm.warp(startTimestamp);

        address[] memory targets = new address[](2);
        targets[0] = address(ethenaUsd);
        targets[1] = address(morphoBlue);

        uint256[] memory values = new uint256[](2);

        bytes[] memory calldatas = new bytes[](2);

        uint256 supplyAmount = 100000;

        deal(ethenaUsd, address(timelock), supplyAmount);

        calldatas[0] = abi.encodeWithSelector(
            IERC20.approve.selector, morphoBlue, supplyAmount
        );

        calldatas[1] = abi.encodeWithSelector(
            IMorphoBase.supplyCollateral.selector,
            dai,
            ethenaUsd,
            oracle,
            irm,
            lltv,
            supplyAmount,
            /// supply supplyAmount of eUSD
            address(timelock),
            ""
        );

        IMorphoBase(morphoBlue).accrueInterest(
            MarketParams(dai, ethenaUsd, oracle, irm, lltv)
        );

        vm.prank(owners[0]);
        timelock.executeWhitelistedBatch(targets, values, calldatas);

        bytes32 marketId = id(MarketParams(dai, ethenaUsd, oracle, irm, lltv));

        Position memory position =
            IMorpho(morphoBlue).position(marketId, address(timelock));

        assertEq(position.supplyShares, 0, "incorrect supply shares");
        assertEq(position.borrowShares, 0, "incorrect borrow shares");
        assertEq(position.collateral, supplyAmount, "incorrect collateral");
    }

    /// ----------------- HELPERS -----------------

    /// @notice The length of the data used to compute the id of a market.
    /// @dev The length is 5 * 32 because `MarketParams` has 5 variables of 32 bytes each.
    uint256 internal constant MARKET_PARAMS_BYTES_LENGTH = 5 * 32;

    /// @notice Returns the id of the market `marketParams`.
    function id(MarketParams memory marketParams)
        internal
        pure
        returns (bytes32 marketParamsId)
    {
        assembly ("memory-safe") {
            marketParamsId :=
                keccak256(marketParams, MARKET_PARAMS_BYTES_LENGTH)
        }
    }

    function signTxAllOwners(bytes32 transactionHash)
        private
        pure
        returns (bytes memory)
    {
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(pk1, transactionHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(pk2, transactionHash);
        (uint8 v3, bytes32 r3, bytes32 s3) = vm.sign(pk3, transactionHash);

        bytes memory sig1 = abi.encodePacked(r1, s1, v1);
        bytes memory sig2 = abi.encodePacked(r2, s2, v2);
        bytes memory sig3 = abi.encodePacked(r3, s3, v3);

        return abi.encodePacked(sig1, sig2, sig3);
    }
}
