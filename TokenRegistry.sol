// SPDX-License-Identifier: BSL-1.1
/*
Recent Changes:
- 2025-08-03: Removed BalanceUpdateFailed emissions from view functions to resolve TypeError; kept in initialize functions.
- 2025-08-03: Removed rTransfer, rTransferFrom; adjusted initialize functions to store only token addresses; made mappings private; updated view functions to use IERC20.balanceOf.
- 2025-07-24: Renamed users parameter in initializeBalances to userAddresses.
- 2025-05-20: Added initializeTokens, modified initializeBalances, added BalanceUpdateFailed event.
- 2025-05-19: Added getAllTokens, getAllUsers, getTopHolders, getTokenSummary, tokenExists, users array.
*/

pragma solidity ^0.8.2;

// Interface for ERC20 standard functions
interface IERC20 {
    function balanceOf(address account) external view returns (uint256 balance);
}

contract TokenRegistry {
    // Mapping of user address to token address to existence flag
    mapping(address user => mapping(address token => bool exists)) private userTokenExists;
    // Mapping of user address to list of token addresses
    mapping(address user => address[] tokens) private userTokens;
    // Mapping to track unique tokens
    mapping(address token => bool exists) private tokenExists;
    // Array of all users with registered tokens
    address[] private users;

    // Events for token registration
    event TokenRegistered(address indexed user, address indexed token);
    event BalanceUpdateFailed(address indexed user, address indexed token);

    // Initialize token addresses for a single token and multiple users
    function initializeBalances(address token, address[] memory userAddresses) external {
        require(token != address(0), "Invalid token address");
        require(userAddresses.length > 0, "Empty users array");

        for (uint256 i = 0; i < userAddresses.length; i++) {
            address user = userAddresses[i];
            require(user != address(0), "Invalid user address");
            if (!userTokenExists[user][token]) {
                userTokenExists[user][token] = true;
                userTokens[user].push(token);
                emit TokenRegistered(user, token);
                if (!tokenExists[token]) {
                    tokenExists[token] = true;
                }
                bool userExists = false;
                for (uint256 j = 0; j < users.length; j++) {
                    if (users[j] == user) {
                        userExists = true;
                        break;
                    }
                }
                if (!userExists) {
                    users.push(user);
                }
                // Check balance to ensure token validity
                try IERC20(token).balanceOf(user) {} catch {
                    emit BalanceUpdateFailed(user, token);
                }
            }
        }
    }

    // Initialize token addresses for a single user and multiple tokens
    function initializeTokens(address user, address[] memory tokens) external {
        require(user != address(0), "Invalid user address");
        require(tokens.length > 0, "Empty tokens array");

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            require(token != address(0), "Invalid token address");
            if (!userTokenExists[user][token]) {
                userTokenExists[user][token] = true;
                userTokens[user].push(token);
                emit TokenRegistered(user, token);
                if (!tokenExists[token]) {
                    tokenExists[token] = true;
                }
                bool userExists = false;
                for (uint256 j = 0; j < users.length; j++) {
                    if (users[j] == user) {
                        userExists = true;
                        break;
                    }
                }
                if (!userExists) {
                    users.push(user);
                }
                // Check balance to ensure token validity
                try IERC20(token).balanceOf(user) {} catch {
                    emit BalanceUpdateFailed(user, token);
                }
            }
        }
    }

    // View function to get list of tokens for a user
    function getTokens(address user) external view returns (address[] memory tokens) {
        require(user != address(0), "Invalid user address");
        return userTokens[user];
    }

    // View function to get real-time balance of a specific token for a user
    function getBalance(address user, address token) external view returns (uint256 balance) {
        require(user != address(0), "Invalid user address");
        require(token != address(0), "Invalid token address");
        try IERC20(token).balanceOf(user) returns (uint256 result) {
            return result;
        } catch {
            return 0;
        }
    }

    // View function to get all tokens and real-time balances for a user
    function getAllBalances(address user) external view returns (address[] memory tokens, uint256[] memory balances) {
        require(user != address(0), "Invalid user address");
        address[] memory userTokenList = userTokens[user];
        uint256 length = userTokenList.length;

        tokens = new address[](length);
        balances = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            tokens[i] = userTokenList[i];
            try IERC20(userTokenList[i]).balanceOf(user) returns (uint256 result) {
                balances[i] = result;
            } catch {
                balances[i] = 0;
            }
        }
    }

    // View function to get all unique token addresses, limited by maxIterations
    function getAllTokens(uint256 maxIterations) external view returns (address[] memory tokens) {
        if (maxIterations == 0 || users.length == 0) {
            return new address[](0);
        }

        address[] memory tempTokens = new address[](users.length * 10);
        uint256 tokenCount = 0;
        uint256 iterations = maxIterations < users.length ? maxIterations : users.length;

        for (uint256 i = 0; i < iterations; i++) {
            address user = users[i];
            address[] memory userTokenList = userTokens[user];
            for (uint256 j = 0; j < userTokenList.length; j++) {
                address token = userTokenList[j];
                bool exists = false;
                for (uint256 k = 0; k < tokenCount; k++) {
                    if (tempTokens[k] == token) {
                        exists = true;
                        break;
                    }
                }
                if (!exists && tokenExists[token]) {
                    tempTokens[tokenCount] = token;
                    tokenCount++;
                }
            }
        }

        tokens = new address[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokens[i] = tempTokens[i];
        }
        return tokens;
    }

    // View function to get all user addresses, limited by maxIterations
    function getAllUsers(uint256 maxIterations) external view returns (address[] memory userAddresses) {
        if (maxIterations == 0 || users.length == 0) {
            return new address[](0);
        }

        uint256 iterations = maxIterations < users.length ? maxIterations : users.length;
        userAddresses = new address[](iterations);
        for (uint256 i = 0; i < iterations; i++) {
            userAddresses[i] = users[i];
        }
        return userAddresses;
    }

    // View function to get top n holders for a token, using real-time balances
    function getTopHolders(address token, uint256 n, uint256 maxIterations) external view returns (address[] memory holders, uint256[] memory balances) {
        require(token != address(0), "Invalid token address");
        require(n > 0, "Invalid n");
        if (maxIterations == 0 || users.length == 0) {
            return (new address[](0), new uint256[](0));
        }

        uint256 iterations = maxIterations < users.length ? maxIterations : users.length;
        uint256 resultSize = n < iterations ? n : iterations;

        address[] memory tempHolders = new address[](iterations);
        uint256[] memory tempBalances = new uint256[](iterations);
        uint256 count = 0;

        for (uint256 i = 0; i < iterations; i++) {
            address user = users[i];
            uint256 balance;
            try IERC20(token).balanceOf(user) returns (uint256 result) {
                balance = result;
            } catch {
                balance = 0;
            }
            if (balance > 0) {
                tempHolders[count] = user;
                tempBalances[count] = balance;
                count++;
            }
        }

        for (uint256 i = 0; i < count && i < resultSize; i++) {
            for (uint256 j = i + 1; j < count; j++) {
                if (tempBalances[j] > tempBalances[i]) {
                    (tempBalances[i], tempBalances[j]) = (tempBalances[j], tempBalances[i]);
                    (tempHolders[i], tempHolders[j]) = (tempHolders[j], tempHolders[i]);
                }
            }
        }

        holders = new address[](resultSize < count ? resultSize : count);
        balances = new uint256[](resultSize < count ? resultSize : count);
        for (uint256 i = 0; i < holders.length; i++) {
            holders[i] = tempHolders[i];
            balances[i] = tempBalances[i];
        }
        return (holders, balances);
    }

    // View function to get total balance and holder count for a token
    function getTokenSummary(address token, uint256 maxIterations) external view returns (uint256 totalBalance, uint256 holderCount) {
        require(token != address(0), "Invalid token address");
        if (maxIterations == 0 || users.length == 0) {
            return (0, 0);
        }

        uint256 iterations = maxIterations < users.length ? maxIterations : users.length;
        for (uint256 i = 0; i < iterations; i++) {
            address user = users[i];
            uint256 balance;
            try IERC20(token).balanceOf(user) returns (uint256 result) {
                balance = result;
            } catch {
                balance = 0;
            }
            if (balance > 0) {
                totalBalance += balance;
                holderCount++;
            }
        }
        return (totalBalance, holderCount);
    }
}