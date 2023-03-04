// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/EcoWallets.sol";

contract EcoWalletsTest is Test {
    EcoWalletsEntryPoint wep = new EcoWalletsEntryPoint();

    event HelloWorld();
    event Foo();

    function test_canExec() external {
        vm.expectEmit(true, true, true, true, wep.getWallet(address(this), 0));
        emit HelloWorld();
        wep.exec(type(RuntimeWithEvent).runtimeCode, "", 0);
    }

    function test_canExecWithDifferentAccount() external {
        assertTrue(wep.getWallet(address(this), 0) != wep.getWallet(address(this), 1));
        vm.expectEmit(true, true, true, true, wep.getWallet(address(this), 1));
        emit HelloWorld();
        wep.exec(type(RuntimeWithEvent).runtimeCode, "", 1);
    }

    function test_callerDeterminesAccount() external {
        assertTrue(wep.getWallet(address(1), 0) != wep.getWallet(address(2), 0));
    }

    function test_canExecWithValue() external {
        wep.exec{value: 1337}(type(RuntimeWantsMoney).runtimeCode, "", 0);
        // This is actually an indirect way to detect that the selfdestruct
        // occurred.
        assertEq(address(123).balance, 1337);
    }

    function test_canExecWithValue_KeptByAccount() external {
        wep.exec{value: 1337}(type(RuntimeWantsMoneyForSelf).runtimeCode, "", 0);
        // This is actually an indirect way to detect that the selfdestruct
        // occurred.
        assertEq(wep.getWallet(address(this), 0).balance, 1337);
    }

    function test_canExecWithReturn() external {
        // foundry can't seem to pick up the runner's log0 with regular
        // expectEmit().
        vm.recordLogs();
        wep.exec(type(RuntimeWithReturn).runtimeCode, "", 0);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(keccak256(logs[0].data), keccak256(hex"6869207468657265"));
    }

    function test_canExecWithFunction() external {
        vm.expectEmit(true, true, true, true, wep.getWallet(address(this), 0));
        emit Foo();
        wep.exec(type(RuntimeWithFunction).runtimeCode, abi.encodeCall(RuntimeWithFunction.foo, ()), 0);
    }

    function test_execRevertsIfCallReverts() external {
        vm.expectRevert();
        wep.exec(type(RuntimeWithRevert).runtimeCode, "", 0);
    }

    function test_execRevertsIfCallTriesToDirectCallRuntime() external {
        RuntimeCallsLogic logic = RuntimeCallsLogic(
            wep.getRuntimeByRuntimeCode(type(RuntimeCallsLogic).runtimeCode)
        );
        vm.expectRevert();
        wep.exec(
            type(RuntimeCallsLogic).runtimeCode,
            abi.encodeCall(RuntimeCallsLogic.foo, (logic)),
            0
        );
    }
}

contract EcoWalletsPostExecTest is Test {
    EcoWalletsEntryPoint wep = new EcoWalletsEntryPoint();
    address setupRuntime;

    event HelloWorld();
    event Foo();

    // setUp() occurs in a separate tx so this will allow selfdestruct() side effects
    // to be observable.
    function setUp() external {
        wep.exec(type(RuntimeWithEvent).runtimeCode, "", 0);
        setupRuntime = wep.getRuntimeByRuntimeCode(type(RuntimeWithEvent).runtimeCode);
        assertGt(setupRuntime.code.length, 0);
    }

    function test_canExecAgain() external {
        vm.expectEmit(true, true, true, true, wep.getWallet(address(this), 0));
        emit HelloWorld();
        wep.exec(type(RuntimeWithEvent).runtimeCode, "", 0);
    }

    function test_runtimeIsDestroyed() external {
        assertEq(setupRuntime.code.length, 0);
    }
}

contract RuntimeWithEvent {
    event HelloWorld();

    fallback() external payable {
        emit HelloWorld();
    }
}

contract RuntimeWantsMoney {
    fallback() external payable {
        payable(address(123)).transfer(1337);
    }
}

contract RuntimeWantsMoneyForSelf {
    fallback() external payable {
    }
}

contract RuntimeWithReturn {
    fallback() external payable {
        bytes memory message = "hi there";
        assembly {
            return(add(message, 0x20), mload(message))
        }
    }
}

contract RuntimeWithRevert {
    fallback() external payable {
        bytes memory message = "hi there";
        assembly {
            revert(add(message, 0x20), mload(message))
        }
    }
}

contract RuntimeWithFunction {
    event Foo();

    function foo() external payable {
        emit Foo();
    }
}

contract RuntimeCallsLogic {
    function foo(RuntimeCallsLogic logic) external {
        logic.bar();
    }

    function bar() external pure {}
}