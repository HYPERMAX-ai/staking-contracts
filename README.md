# xHYPE Liquid-Staking

A Solidity contract that implements a liquid-staking vault on HyperEVM with seamless bridging to HyperCore.

The key idea is to hide the raw L1 precompile calls behind `L1Write`, making cross-chain interactions feel like ordinary Solidity calls.

### `xHYPE.sol`

A vault contract that accepts the native tokens (HYPE) and mints liquid-staking tokens.
- `deposit()`: stakes the sent HYPE on L1 and issues xHYPE shares  ￼
- `withdrawRequest()`: queues a withdrawal; shares are burned and the request is recorded  ￼
- `withdraw()`: pulls completed requests back to L2 once the L1 lock-up has passed  ￼
- `withdrawFinalize()`: final step that releases the HYPE to the user

---

# Steps

1. Deploy contracts (`deploy.js`).
2. Stake by sending HYPE to xHYPE.deposit() on HyperEVM (`1_deposit.js`).
3. After the minimum bonding period, call `withdrawRequest()` to start un-staking (`2_withdrawRequest.js`).
4. When the unbonding period on L1 ends, call `withdraw()` to bridge funds back (`3_withdraw.js`).
5. Finally, invoke `withdrawFinalize()` to receive HYPE on L2 and close the request (`4_withdrawFinalize.js`).
