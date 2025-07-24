// SPDX-License-Identifier: BSD-3-Clause
/*
Recent Changes:
- 2025-07-24: The parameter users In the initializeBalances function was renamed to userAddresses to avoid shadowing the contract's state variable users.
- 2025-05-20: Modified initializeBalances to accept single token with multiple users, added initializeTokens for single user with multiple tokens.
- 2025-05-20: Added BalanceUpdateFailed event for failed balanceOf calls.
- 2025-05-19: Added getAllTokens, getAllUsers, getTopHolders, getTokenSummary with maxIterations.
- 2025-05-19: Added tokenExists mapping and users array, updated updateBalance.
- 2025-05-19: Renamed transfer to rTransfer, transferFrom to rTransferFrom, setRegistry to initializeBalances.
- 2025-05-19: Initial contract implementation with proxy transfer and balance tracking.
*/

pragma solidity ^0.8.2;

// Interface for ERC20 standard functions
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenRegistry {
    // Mapping of user address to token address to balance
    mapping(address => mapping(address => uint256)) public userBalances;
    // Mapping of user address to list of token addresses
    mapping(address => address[]) public userTokens;
    // Mapping to track unique tokens
    mapping(address => bool) public tokenExists;
    // Array of all users with registered tokens
    address[] public users;

    // Events for balance updates and token registration
    event BalanceUpdated(address indexed user, address indexed token, uint256 balance);
    event TokenRegistered(address indexed user, address indexed token);
    event BalanceUpdateFailed(address indexed user, address indexed token);

    // Proxy transfer for ERC20 token, updates registry balances
    function rTransfer(address token, address to, uint256 amount) external {
        require(token != address(0), "Invalid token address");
        require(to != address(0), "Invalid recipient address");
        require(amount > 0, "Invalid amount");

        // Call ERC20 transfer
        bool success = IERC20(token).transfer(to, amount);
        require(success, "Transfer failed");

        // Update balances for sender and recipient
        updateBalance(token, msg.sender);
        updateBalance(token, to);
    }

    // Proxy transferFrom for ERC20 token, updates registry balances
    function rTransferFrom(address token, address from, address to, uint256 amount) external {
        require(token != address(0), "Invalid token address");
        require(from != address(0), "Invalid from address");
        require(to != address(0), "Invalid to address");
        require(amount > 0, "Invalid amount");

        // Call ERC20 transferFrom
        bool success = IERC20(token).transferFrom(from, to, amount);
        require(success, "TransferFrom failed");

        // Update balances for from and to addresses
        updateBalance(token, from);
        updateBalance(token, to);
    }

    // Initialize or update balances for a single token and multiple users
    function initializeBalances(address token, address[] memory userAddresses) external {
        require(token != address(0), "Invalid token address");
        require(userAddresses.length > 0, "Empty users array");

        for (uint256 i = 0; i < userAddresses.length; i++) {
            address user = userAddresses[i];
            require(user != address(0), "Invalid user address");
            updateBalance(token, user);
        }
    }

    // Initialize or update balances for a single user and multiple tokens
    function initializeTokens(address user, address[] memory tokens) external {
        require(user != address(0), "Invalid user address");
        require(tokens.length > 0, "Empty tokens array");

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            require(token != address(0), "Invalid token address");
            updateBalance(token, user);
        }
    }

    // Internal function to update balance and token list
    function updateBalance(address token, address user) internal {
        // Get current balance from ERC20 contract
        uint256 balance;
        try IERC20(token).balanceOf(user) returns (uint256 result) {
            balance = result;
        } catch {
            emit BalanceUpdateFailed(user, token);
            balance = 0; // Graceful degradation for invalid tokens
        }

        // Update balance in registry
        userBalances[user][token] = balance;
        emit BalanceUpdated(user, token, balance);

        // Check if token is already in user's token list
        bool tokenInUserList = false;
        for (uint256 i = 0; i < userTokens[user].length; i++) {
            if (userTokens[user][i] == token) {
                tokenInUserList = true;
                break;
            }
        }

        // Add token to user's token list and global token list if new
        if (!tokenInUserList) {
            userTokens[user].push(token);
            emit TokenRegistered(user, token);
            if (!tokenExists[token]) {
                tokenExists[token] = true;
            }
        }

        // Add user to users array if new
        bool userExists = false;
        for (uint256 i = 0; i < users.length; i++) {
            if (users[i] == user) {
                userExists = true;
                break;
            }
        }
        if (!userExists) {
            users.push(user);
        }
    }

    // View function to get list of tokens for a user
    function getTokens(address user) external view returns (address[] memory) {
        require(user != address(0), "Invalid user address");
        return userTokens[user];
    }

    // View function to get balance of a specific token for a user
    function getBalance(address user, address token) external view returns (uint256) {
        require(user != address(0), "Invalid user address");
        require(token != address(0), "Invalid token address");
        return userBalances[user][token];
    }

    // View function to get all tokens and balances for a user
    function getAllBalances(address user) external view returns (address[] memory tokens, uint256[] memory balances) {
        require(user != address(0), "Invalid user address");
        address[] memory userTokenList = userTokens[user];
        uint256 length = userTokenList.length;

        tokens = new address[](length);
        balances = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            tokens[i] = userTokenList[i];
            balances[i] = userBalances[user][tokens[i]];
        }
    }

    // View function to get all unique token addresses, limited by maxIterations
    function getAllTokens(uint256 maxIterations) external view returns (address[] memory) {
        if (maxIterations == 0 || users.length == 0) {
            return new address[](0);
        }

        // Use dynamic array to collect unique tokens
        address[] memory tempTokens = new address[](users.length * 10); // Overestimate size
        uint256 tokenCount = 0;

        // Iterate over users up to maxIterations
        uint256 iterations = maxIterations < users.length ? maxIterations : users.length;
        for (uint256 i = 0; i < iterations; i++) {
            address user = users[i];
            address[] memory userTokenList = userTokens[user];
            for (uint256 j = 0; j < userTokenList.length; j++) {
                address token = userTokenList[j];
                // Check if token is already in tempTokens
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

        // Copy to correctly sized array
        address[] memory result = new address[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            result[i] = tempTokens[i];
        }
        return result;
    }

    // View function to get all user addresses, limited by maxIterations
    function getAllUsers(uint256 maxIterations) external view returns (address[] memory) {
        if (maxIterations == 0 || users.length == 0) {
            return new address[](0);
        }

        uint256 iterations = maxIterations < users.length ? maxIterations : users.length;
        address[] memory result = new address[](iterations);
        for (uint256 i = 0; i < iterations; i++) {
            result[i] = users[i];
        }
        return result;
    }

    // View function to get top n holders for a token, limited by maxIterations
    function getTopHolders(address token, uint256 n, uint256 maxIterations) external view returns (address[] memory holders, uint256[] memory balances) {
        require(token != address(0), "Invalid token address");
        require(n > 0, "Invalid n");
        if (maxIterations == 0 || users.length == 0) {
            return (new address[](0), new uint256[](0));
        }

        uint256 iterations = maxIterations < users.length ? maxIterations : users.length;
        uint256 resultSize = n < iterations ? n : iterations;

        // Temporary arrays for sorting
        address[] memory tempHolders = new address[](iterations);
        uint256[] memory tempBalances = new uint256[](iterations);
        uint256 count = 0;

        // Collect balances
        for (uint256 i = 0; i < iterations; i++) {
            address user = users[i];
            uint256 balance = userBalances[user][token];
            if (balance > 0) {
                tempHolders[count] = user;
                tempBalances[count] = balance;
                count++;
            }
        }

        // Sort top n by balance (bubble sort for simplicity, limited by n)
        for (uint256 i = 0; i < count && i < resultSize; i++) {
            for (uint256 j = i + 1; j < count; j++) {
                if (tempBalances[j] > tempBalances[i]) {
                    (tempBalances[i], tempBalances[j]) = (tempBalances[j], tempBalances[i]);
                    (tempHolders[i], tempHolders[j]) = (tempHolders[j], tempHolders[i]);
                }
            }
        }

        // Resize result arrays
        holders = new address[](resultSize < count ? resultSize : count);
        balances = new uint256[](resultSize < count ? resultSize : count);
        for (uint256 i = 0; i < holders.length; i++) {
            holders[i] = tempHolders[i];
            balances[i] = tempBalances[i];
        }
        return (holders, balances);
    }

    // View function to get total balance and holder count for a token, limited by maxIterations
    function getTokenSummary(address token, uint256 maxIterations) external view returns (uint256 totalBalance, uint256 holderCount) {
        require(token != address(0), "Invalid token address");
        if (maxIterations == 0 || users.length == 0) {
            return (0, 0);
        }

        uint256 iterations = maxIterations < users.length ? maxIterations : users.length;
        for (uint256 i = 0; i < iterations; i++) {
            address user = users[i];
            uint256 balance = userBalances[user][token];
            if (balance > 0) {
                totalBalance += balance;
                holderCount++;
            }
        }
        return (totalBalance, holderCount);
    }
}