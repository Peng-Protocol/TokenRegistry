# Token Registry System Specification

This document specifies the system comprising `TokenRegistry.sol`. Built for Solidity 0.8.2 with BSD-3-Clause license, the contract manages onchain balance and token tracking. This specification details data structures, operations, and design considerations, aligning with the provided contracts.

## TokenRegistry.sol

`TokenRegistry.sol` tracks user balances and token metadata for ERC20 tokens, allowing onchain holder queries. 

### 1. Data Structures
- **Mappings**:
  - `userBalances[user][token]`: Balance of `token` for `user`.
  - `userTokens[user]`: Array of token addresses for `user`.
  - `tokenExists[token]`: Tracks unique tokens.
- **Arrays**:
  - `users`: All users with registered tokens.
- **Events**:
  - `BalanceUpdated(user, token, balance)`: Emitted on balance updates.
  - `TokenRegistered(user, token)`: Emitted on new token registration.
  - `BalanceUpdateFailed(user, token)`: Emitted on failed balance queries.

### 2. Core Functions
- **rTransfer(token, to, amount)**: Proxy for ERC20 `transfer`. Updates balances for sender and recipient via `updateBalance`.
- **rTransferFrom(token, from, to, amount)**: Proxy for ERC20 `transferFrom`. Updates balances for `from` and `to`.
- **initializeBalances(token, users)**: Updates balances for a token across multiple users.
- **initializeTokens(user, tokens)**: Updates balances for a user across multiple tokens.
- **updateBalance(token, user)**: Internal. Queries ERC20 `balanceOf`, updates `userBalances`, and registers tokens/users. Uses `try/catch` for graceful degradation (sets balance to 0 on failure).

### 3. View Functions
- **getTokens(user)**: Returns user’s token list.
- **getBalance(user, token)**: Returns user’s balance for a token.
- **getAllBalances(user)**: Returns user’s tokens and balances.
- **getAllTokens(maxIterations)**: Returns unique tokens, limited by `maxIterations`.
- **getAllUsers(maxIterations)**: Returns users, limited by `maxIterations`.
- **getTopHolders(token, n, maxIterations)**: Returns top `n` holders and balances for a token, sorted descending, limited by `maxIterations`.
- **getTokenSummary(token, maxIterations)**: Returns total balance and holder count for a token, limited by `maxIterations`.

### 4. Design Notes
- **Decimal Handling**: Relies on ERC20 contract for decimals, no normalization.
- **Gas Efficiency**: Sparse storage with dynamic arrays; `maxIterations` limits gas-intensive loops.
- **Error Handling**: `try/catch` in `updateBalance` ensures graceful degradation.
- **Access Control**: Public functions, no ownership.
