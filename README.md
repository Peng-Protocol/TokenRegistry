# Token Registry System Documentation
This document specifies the system comprising `TokenRegistry.sol`. Built for Solidity ^0.8.2 with BSL-1.1 license, the contract manages onchain token address tracking for ERC20 tokens. This specification details data structures, operations, and design considerations, aligning with the provided contract.

## TokenRegistry.sol

`TokenRegistry.sol` tracks user-token associations for ERC20 tokens, enabling onchain holder queries using real-time balance checks.

### 1. Data Structures
- **Mappings** (private):
  - `userTokenExists[user][token]`: Boolean indicating if `user` holds `token`.
  - `userTokens[user]`: Array of token addresses for `user`.
  - `tokenExists[token]`: Tracks unique tokens.
- **Arrays** (private):
  - `users`: All users with registered tokens.
- **Events**:
  - `TokenRegistered(user, token)`: Emitted on new token registration.
  - `TokenRemoved(user, token)`: Emitted when a token is removed due to zero balance.
  - `BalanceUpdateFailed(user, token)`: Emitted on failed balance queries during initialization.

### 2. Core Functions
- **initializeBalances(token, userAddresses)**: Registers a token for multiple users or removes it if the balance is zero, storing token addresses and validating via `balanceOf`. Emits `TokenRegistered` or `TokenRemoved` accordingly.
- **initializeTokens(user, tokens)**: Registers multiple tokens for a user or removes them if the balance is zero, storing token addresses and validating via `balanceOf`. Emits `TokenRegistered` or `TokenRemoved` accordingly. Both emit `BalanceUpdateFailed` on failed `balanceOf` calls.

### 3. View Functions
- **getTokens(user)**: Returns user’s token list.
- **getBalance(user, token)**: Returns real-time `balanceOf` for a user’s token.
- **getAllBalances(user)**: Returns user’s tokens and real-time `balanceOf` results.
- **getAllTokens(maxIterations)**: Returns unique tokens, limited by `maxIterations`.
- **getAllUsers(maxIterations)**: Returns users, limited by `maxIterations`.
- **getTopHolders(token, n, maxIterations)**: Returns top `n` holders and real-time `balanceOf` results for a token, sorted descending, limited by `maxIterations`.
- **getTokenSummary(token, maxIterations)**: Returns total real-time balance and holder count for a token, limited by `maxIterations`.

### 4. Design Notes
- **Decimal Handling**: Relies on ERC20 contract for decimals, no normalization.
- **Gas Efficiency**: Sparse storage with dynamic arrays; `maxIterations` limits gas-intensive loops. Token removal increases gas due to array manipulation.
- **Error Handling**: `try/catch` in view functions returns 0 on failure; `BalanceUpdateFailed` emitted only in initialization functions.
- **Access Control**: Public functions, no ownership.
- **Privacy**: Mappings and arrays are private to prevent direct access, relying on view functions for queries.
