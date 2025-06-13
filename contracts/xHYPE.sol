// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./L1Write.sol";

abstract contract Reader {
    struct SpotBalance {
        uint64 total;
        uint64 hold;
        uint64 entryNtl;
    }

    struct Delegation {
        address validator;
        uint64 amount;
        uint64 lockedUntilTimestamp;
    }

    struct DelegatorSummary {
        uint64 delegated;
        uint64 undelegated;
        uint64 totalPendingWithdrawal;
        uint64 nPendingWithdrawals;
    }

    address constant SPOT_BALANCE_PRECOMPILE_ADDRESS =
        0x0000000000000000000000000000000000000801;
    address constant DELEGATIONS_PRECOMPILE_ADDRESS =
        0x0000000000000000000000000000000000000804;
    address constant DELEGATOR_SUMMARY_PRECOMPILE_ADDRESS =
        0x0000000000000000000000000000000000000805;

    constructor() {}

    function _spotBalance(
        address user,
        uint64 token
    ) internal view returns (SpotBalance memory) {
        bool success;
        bytes memory result;
        (success, result) = SPOT_BALANCE_PRECOMPILE_ADDRESS.staticcall(
            abi.encode(user, token)
        );
        require(success, "SpotBalance precompile call failed");
        return abi.decode(result, (SpotBalance));
    }

    function _delegations(
        address user
    ) internal view returns (Delegation[] memory) {
        bool success;
        bytes memory result;
        (success, result) = DELEGATIONS_PRECOMPILE_ADDRESS.staticcall(
            abi.encode(user)
        );
        require(success, "Delegations precompile call failed");
        return abi.decode(result, (Delegation[]));
    }

    function _delegatorSummary(
        address user
    ) internal view returns (DelegatorSummary memory) {
        bool success;
        bytes memory result;
        (success, result) = DELEGATOR_SUMMARY_PRECOMPILE_ADDRESS.staticcall(
            abi.encode(user)
        );
        require(success, "DelegatorySummary precompile call failed");
        return abi.decode(result, (DelegatorSummary));
    }
}

contract xHYPE is
    L1Write,
    Reader,
    ERC20("xHYPE", "xHYPE"),
    Ownable,
    ReentrancyGuard
{
    uint256 public fee;
    uint256 private constant DENOMINATOR = 10000;
    // uint256 private constant TIMELOCK = 302400; // 7 days // 2s interval // TODO: mainnet
    uint256 private constant TIMELOCK = 300; // 10 minutes // 2s interval // testnet

    // uint256 internal recentBridgeFee;
    uint64 internal BRIDGE_FEE = 20000000; // TODO
    // uint256 private constant STAKE_TIMELOCK = 43200; // 1 days // 2s interval // TODO: mainnet
    uint256 private constant STAKE_TIMELOCK = 60; // 2 minutes // 2s interval // testnet

    address internal constant bridge =
        0x2222222222222222222222222222222222222222;

    address public treasury;

    // TODO: total amount across the all validators
    // TODO: list of validators -> for loop for total amount
    // Now: only one validator available
    address public validator;
    uint256 public principle;
    uint64 internal tokenSpotIdx = 1105;

    // struct Queue {
    //     uint256 amount;
    //     uint256 shareAmount;
    // }
    // mapping(address account => Queue) public queues;

    mapping(address account => uint256) public userStakeTimelock;

    struct WithdrawPending {
        uint256 timelock;
        uint256 amount;
    }
    mapping(address account => uint256) public withdrawStartIdx;
    mapping(address account => WithdrawPending[]) internal _withdrawPendings;

    mapping(address account => uint256) internal _withdrawFinalizePendings;

    event SetFee(uint256 prevFee, uint256 newFee);
    event SetTreasury(address prevTreasure, address newTreasure);
    event SetValidator(address prevValidator, address newValidator);
    event Deposited(
        address indexed sender,
        uint256 hypeAmount,
        uint256 xHypeAmount
    );
    event WithdrawRequest(
        address indexed sender,
        uint256 hypeAmount,
        uint256 xHypeAmount
    );
    event Withdraw(address indexed sender, uint256 hypeAmount);
    event WithdrawFinalize(address indexed sender, uint256 hypeAmount);
    event Fee(address indexed feeTo, uint256 hypeAmount, uint256 xHypeAmount);

    constructor(
        address _treasury,
        address _validator,
        uint256 _fee
    ) Ownable(msg.sender) {
        treasury = _treasury;
        validator = _validator;
        require(_fee <= DENOMINATOR, "INVALID_FEE.");
        fee = _fee;
    }

    /* Owner */

    function treasuryUpdate(address newTreasury) external payable onlyOwner {
        address prevTreasury = treasury;
        treasury = newTreasury;
        emit SetTreasury(prevTreasury, treasury);
    }

    // function validatorUpdate(address newValidator) external payable onlyOwner {
    //     address prevValidator = validator;
    //     validator = newValidator;
    //     emit SetValidator(prevValidator, validator);
    // }

    function feeUpdate(uint256 newFee) external payable onlyOwner {
        require(newFee <= DENOMINATOR, "INVALID_FEE.");
        uint256 prevFee = fee;
        fee = newFee;
        emit SetFee(prevFee, fee);
    }

    function withdrawHype() external payable onlyOwner {
        address msgSender = _msgSender();
        (bool success, ) = msgSender.call{value: address(this).balance}("");
        require(success, "xHYPE::withdrawHype.");
    }

    /* View */

    function pendings(
        address account
    ) public view returns (WithdrawPending[] memory result) {
        WithdrawPending[] storage userPendings = _withdrawPendings[account];
        uint256 start = withdrawStartIdx[account];
        uint256 length = userPendings.length - start;

        result = new WithdrawPending[](length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = userPendings[start + i];
        }
        return result;
    }

    function withdrawFinalizePendings(
        address account
    ) public view returns (uint256) {
        return _withdrawFinalizePendings[account];
    }

    function currentFee() public view returns (uint256) {
        uint256 totalStaked = uint256(
            _delegatorSummary(address(this)).delegated * 1e10
        );
        return ((totalStaked - principle) * fee) / DENOMINATOR;
    }

    function getTotalPooledHYPEWithFee() public view returns (uint256) {
        uint256 totalStaked = uint256(
            _delegatorSummary(address(this)).delegated * 1e10
        );
        uint256 feeHype = ((totalStaked - principle) * fee) / DENOMINATOR;
        return totalStaked - feeHype;
    }

    function internalPrice() public view returns (uint256) {
        uint256 totalStaked = uint256(
            _delegatorSummary(address(this)).delegated * 1e10
        );
        uint256 feeHype = ((totalStaked - principle) * fee) / DENOMINATOR;
        if (totalSupply() == 0) {
            return 1 * 1e18;
        } else {
            return ((totalStaked - feeHype) * 1e18) / totalSupply();
        }
    }

    function rewardOf(address account_) public view returns (uint256) {
        uint256 totalStaked = uint256(
            _delegatorSummary(address(this)).delegated * 1e10
        );
        uint256 reward = ((totalStaked - principle) * (DENOMINATOR - fee)) /
            DENOMINATOR;

        if (totalSupply() == 0) {
            return 0;
        } else {
            return (balanceOf(account_) * reward) / totalSupply();
        }
    }

    /* Functions */

    /**
     * @notice DEPRECATED
     * @dev Users are NOT able to submit their funds by transacting to the fallback function.
     */
    receive() external payable {}

    /**
     * @dev Process user deposit, mints liquid tokens
     * @return shareAmount amount of xHYPE shares generated
     */
    function deposit()
        external
        payable
        nonReentrant
        returns (uint256 shareAmount)
    {
        address msgSender = _msgSender();
        require(
            msg.value > uint256(BRIDGE_FEE * 1e10),
            "xHYPE::deposit:ZERO_DEPOSIT."
        );

        uint64 realAmount = uint64(msg.value / 1e10) - BRIDGE_FEE;
        uint256 realAmount18 = uint256(realAmount) * 1e10;

        // bridging
        {
            (bool success, ) = bridge.call{value: msg.value}("");
            require(success, "xHYPE::deposit.");
        }

        uint256 feeHype;
        uint256 feeXHype;
        {
            uint256 totalStaked = uint256(
                _delegatorSummary(address(this)).delegated * 1e10
            );
            feeHype = ((totalStaked - principle) * fee) / DENOMINATOR;
            uint256 totalPooledEther = totalStaked - feeHype;

            if (totalPooledEther == 0) {
                shareAmount = realAmount18;
            } else {
                shareAmount = (realAmount18 * totalSupply()) / totalPooledEther;
            }

            if (totalPooledEther == 0) {
                feeXHype = feeHype;
            } else {
                feeXHype = (feeHype * totalSupply()) / totalPooledEther;
            }
        }

        // mint
        _mint(msgSender, shareAmount);
        _mint(treasury, feeXHype);

        // staking
        principle += (feeHype + realAmount18);
        // writer
        _sendCDeposit(realAmount);
        // writer
        _sendTokenDelegate(validator, realAmount, false);

        // stake lockup
        userStakeTimelock[msgSender] = block.number + STAKE_TIMELOCK;

        emit Deposited(msgSender, msg.value, shareAmount);
        emit Fee(treasury, feeHype, feeXHype);
    }

    /**
     * @dev Process user withdraw, burns liquid tokens
     * @param shareAmount of xHYPE to withdraw
     * @return amount amount of HYPE burned
     */
    function withdrawRequest(
        uint256 shareAmount
    ) external payable nonReentrant returns (uint256 amount) {
        address msgSender = _msgSender();
        require(shareAmount != 0, "xHYPE::withdrawRequest:ZERO_REQUEST.");
        require(
            shareAmount <= balanceOf(msgSender),
            "xHYPE::withdrawRequest:NOT_ENOUGH_BALANCE."
        );
        require(
            userStakeTimelock[msgSender] <= block.number,
            "xHYPE::withdrawRequest:NOT_ENOUGH_PERIOD."
        );

        uint256 feeHype;
        uint256 feeXHype;
        {
            uint256 totalStaked = uint256(
                _delegatorSummary(address(this)).delegated * 1e10
            );
            feeHype = ((totalStaked - principle) * fee) / DENOMINATOR;
            uint256 totalPooledEther = totalStaked - feeHype;

            if (totalSupply() == 0) {
                revert("xHYPE::withdrawRequest:NEVER HAPPENED.");
            } else {
                amount = (shareAmount * totalPooledEther) / totalSupply();
            }

            if (totalPooledEther == 0) {
                feeXHype = feeHype;
            } else {
                feeXHype = (feeHype * totalSupply()) / totalPooledEther;
            }
        }

        // burn & mint
        _burn(msgSender, shareAmount);
        _mint(treasury, feeXHype);

        // unstaking
        principle += feeHype;
        principle -= amount;
        // writer
        _sendTokenDelegate(validator, uint64(amount / 1e10), true);
        // writer
        _sendCWithdrawal(uint64(amount / 1e10));
        _withdrawPendings[msgSender].push(
            WithdrawPending({
                timelock: block.number + TIMELOCK,
                amount: amount / 1e10
            })
        );

        emit WithdrawRequest(msgSender, amount, shareAmount);
        emit Fee(treasury, feeHype, feeXHype);
    }

    function withdraw() external payable nonReentrant returns (uint256 amount) {
        address msgSender = _msgSender();

        WithdrawPending[] storage requests = _withdrawPendings[msgSender];
        uint256 idx = withdrawStartIdx[msgSender];
        uint256 len = requests.length;

        // iterate from withdrawStartIdx up to the first locked entry
        for (uint256 i = idx; i < len; i++) {
            if (requests[i].timelock <= block.number) {
                amount += requests[i].amount;
                idx++;
            } else {
                break;
            }
        }
        require(amount > 0, "xHYPE::withdraw:NOT_ENOUGH_AMOUNT.");

        // update withdrawStartIdx to skip over processed entries
        withdrawStartIdx[msgSender] = idx;
        // if we've consumed all entries, reset for this user
        if (idx == len) {
            delete _withdrawPendings[msgSender];
            delete withdrawStartIdx[msgSender];
        }

        // bridging
        _sendSpot(bridge, tokenSpotIdx, uint64(amount));
        _withdrawFinalizePendings[msgSender] += amount * 1e10;

        emit Withdraw(msgSender, amount * 1e10);
    }

    function withdrawFinalize(
        address account
    ) external payable nonReentrant returns (uint256 amount) {
        amount = _withdrawFinalizePendings[account];
        // delete _withdrawFinalizePendings[account];
        _withdrawFinalizePendings[account] = 0;

        (bool success, ) = account.call{value: amount}("");
        require(success, "xHYPE::withdraw.");

        emit WithdrawFinalize(account, amount);
    }
}
