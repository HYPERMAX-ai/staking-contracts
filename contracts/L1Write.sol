// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICoreWriter {
    function sendRawAction(bytes calldata data) external;
}

contract L1Write {
    ICoreWriter public constant coreWriter =
        ICoreWriter(0x3333333333333333333333333333333333333333);

    function _encode(
        uint24 actionId,
        bytes memory payload
    ) internal pure returns (bytes memory) {
        bytes1 version = bytes1(uint8(1));
        bytes3 aid = bytes3(actionId);
        return abi.encodePacked(version, aid, payload);
    }

    /**
     * Tif encoding: 1 for Alo , 2 for Gtc , 3 for Ioc .
     * Cloid encoding: 0 means no cloid, otherwise uses the number as the cloid.
     */
    function _sendLimitOrder(
        uint32 asset,
        bool isBuy,
        uint64 limitPx,
        uint64 sz,
        bool reduceOnly,
        uint8 encodedTif,
        uint128 cloid
    ) internal {
        bytes memory payload = abi.encode(
            asset,
            isBuy,
            limitPx,
            sz,
            reduceOnly,
            encodedTif,
            cloid
        );
        coreWriter.sendRawAction(_encode(1, payload));
    }

    function _sendVaultTransfer(
        address vault,
        bool isDeposit,
        uint64 usd
    ) internal {
        bytes memory payload = abi.encode(vault, isDeposit, usd);
        coreWriter.sendRawAction(_encode(2, payload));
    }

    function _sendTokenDelegate(
        address validator,
        uint64 _wei,
        bool isUndelegate
    ) internal {
        bytes memory payload = abi.encode(validator, _wei, isUndelegate);
        coreWriter.sendRawAction(_encode(3, payload));
    }

    function _sendCDeposit(uint64 _wei) internal {
        bytes memory payload = abi.encode(_wei);
        coreWriter.sendRawAction(_encode(4, payload));
    }

    function _sendCWithdrawal(uint64 _wei) internal {
        bytes memory payload = abi.encode(_wei);
        coreWriter.sendRawAction(_encode(5, payload));
    }

    function _sendSpot(
        address destination,
        uint64 token,
        uint64 _wei
    ) internal {
        bytes memory payload = abi.encode(destination, token, _wei);
        coreWriter.sendRawAction(_encode(6, payload));
    }

    function _sendUsdClassTransfer(uint64 ntl, bool toPerp) internal {
        bytes memory payload = abi.encode(ntl, toPerp);
        coreWriter.sendRawAction(_encode(7, payload));
    }
}
