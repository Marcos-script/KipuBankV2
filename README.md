# KipuBankV2

Multi-token decentralized banking system with Chainlink oracle integration and USD-based accounting.

## Contract Description

KipuBankV2 is an evolution of the original KipuBank contract that implements advanced Solidity features and best practices:

### Key Features Implemented

**Access Control:**
- Inherits from OpenZeppelin's `Ownable` contract
- Owner-restricted administrative functions
- Secure ownership transfer mechanism

**Multi-Token Support:**
- Native ETH deposits and withdrawals
- ERC-20 token support (MockUSDC)
- Unified USD-based accounting (6 decimals)
- Nested mappings for user balances per token

**Chainlink Oracle Integration:**
- Real-time ETH/USD price feed integration
- Price staleness validation (heartbeat check)
- Decimal conversion handling (18 decimals ETH + 8 decimals Oracle → 6 decimals USD)
- Oracle error handling

**Security Patterns:**
- Check-Effects-Interactions (CEI) pattern
- SafeERC20 for secure token transfers
- Custom errors for gas optimization
- Modifiers for condition validation
- No unchecked arithmetic where overflow is possible

**Gas Optimization:**
- `immutable` variables for deployment parameters
- `constant` variables for fixed values
- Single storage reads/writes per function
- Events for off-chain monitoring

## Improvements Over Original KipuBank

| Feature | KipuBank V1 | KipuBankV2 |
|---------|-------------|------------|
| Token Support | ETH only | ETH + ERC-20 |
| Price Oracle | None | Chainlink |
| Accounting | ETH-based | USD-based |
| Access Control | Basic | OpenZeppelin Ownable |
| Security | Basic | CEI + SafeERC20 |
| Error Handling | require strings | Custom errors |
| Decimal Management | Single | Multi-token conversion |

## Deployed Contracts

### Sepolia Testnet

**MockUSDC (Test Token):**
- Address: `0xb5C570B7d42E8B1fbEc0E638A59db2B7d7b1e35c`
- Verified: [View on Sepolia Etherscan](https://sepolia.etherscan.io/address/0xb5C570B7d42E8B1fbEc0E638A59db2B7d7b1e35c)

**KipuBankV2 (Main Contract):**
- Address: `0xEfF0661209af9c31436517701f85eD25E5188cfb`
- Verified: [View on Sepolia Etherscan](https://sepolia.etherscan.io/address/0xEfF0661209af9c31436517701f85eD25E5188cfb)
- Sourcify: [View Source](https://repo.sourcify.dev/11155111/0xEfF0661209af9c31436517701f85eD25E5188cfb/)

**Deployment Parameters:**
- Chainlink Price Feed: `0x694AA1769357215DE4FAC081bf1f309aDC325306` (ETH/USD Sepolia)
- Withdrawal Threshold: 1,000 USD (with 6 decimals)
- Bank Cap: 10,000 USD (with 6 decimals)
- Owner: Deployer address

## Deployment Instructions

### Prerequisites
- Solidity compiler version: `^0.8.26`
- OpenZeppelin Contracts
- Chainlink Contracts
- Metamask or compatible Web3 wallet
- Sepolia testnet ETH for gas fees

### Step-by-Step Deployment

#### 1. Clone the Repository
```bash
git clone https://github.com/YOUR_USERNAME/kipu-bank.git
cd kipu-bank
```

#### 2. Open Remix IDE
- Navigate to [https://remix.ethereum.org](https://remix.ethereum.org)
- Create a new file: `/contracts/KipuBankV2.sol`
- Copy the complete contract code

#### 3. Compile the Contract
- Select Solidity compiler version: `0.8.26`
- Enable optimization: 200 runs (recommended)
- Click "Compile KipuBankV2.sol"
- Verify no compilation errors

#### 4. Deploy MockUSDC (Test Token)
- Switch environment to "Injected Provider - MetaMask"
- Select "MockUSDC" from contract dropdown
- Click "Deploy"
- Confirm transaction in MetaMask
- **Save the MockUSDC address**

#### 5. Mint Test USDC Tokens
```solidity
// Call mint() function on MockUSDC
_to: x247a443C5d84Acd3FF15163545aFF454451eBC33
_amount: 10000000000  // 10,000 USDC (6 decimals)
```

#### 6. Deploy KipuBankV2 (Main Contract)
- Select "KipuBankV2" from contract dropdown
- Enter constructor parameters:
```
_priceFeed: "0x694AA1769357215DE4FAC081bf1f309aDC325306"
_usdcToken: "0xb5C570B7d42E8B1fbEc0E638A59db2B7d7b1e35c"
_withdrawalThreshold: "1000000000"
_bankCap: "10000000000"
_owner: "0x247a443C5d84Acd3FF15163545aFF454451eBC33"
```

**Example:**
```
"0x694AA1769357215DE4FAC081bf1f309aDC325306",
"0xb5C570B7d42E8B1fbEc0E638A59db2B7d7b1e35c",
"1000000000",
"10000000000",
"0x247a443C5d84Acd3FF15163545aFF454451eBC33"
```

- Click "Deploy & Verify"
- Confirm transaction in MetaMask
- Wait for deployment confirmation (~30 seconds)

#### 7. Verify Deployment
The contract should auto-verify with Sourcify and Routescan. If not, manually verify on Etherscan using:
- Contract source code
- Compiler version: 0.8.26
- Optimization: Enabled (200 runs)
- Constructor arguments (ABI-encoded)

## How to Interact with the Contract

### Reading Contract State

#### Check Your Balance
```solidity
// Get ETH balance (in USD)
getBalance(YOUR_ADDRESS, 0x0000000000000000000000000000000000000000)

// Get USDC balance (in USD)
getBalance(YOUR_ADDRESS, MOCKUSDC_ADDRESS)

// Get total balance across all tokens
getTotalBalance(YOUR_ADDRESS)
```

#### Check Contract Configuration
```solidity
getOwner()                 // Returns contract owner
getBankCap()              // Returns bank capacity limit
getWithdrawalThreshold()  // Returns withdrawal limit per transaction
getCurrentEthUsdPrice()   // Returns current ETH price from Chainlink
getTotalDepositsUsd()     // Returns total deposits in the bank
```

### Depositing Funds

#### Deposit ETH
```solidity
// In Remix:
// 1. Set VALUE field to desired amount (e.g., 0.01)
// 2. Select "Ether" from dropdown
// 3. Click depositEth()
// 4. Confirm in MetaMask
```

Alternative using Wei:
```
VALUE: 10000000000000000
Dropdown: Wei
Function: depositEth()
```

#### Deposit USDC
```solidity
// Step 1: Approve KipuBankV2 to spend your USDC
// On MockUSDC contract:
approve(KIPUBANKV2_ADDRESS, AMOUNT)

// Step 2: Deposit tokens
// On KipuBankV2 contract:
depositToken(AMOUNT)
// Example: 1000000000 for 1,000 USDC
```

### Withdrawing Funds

#### Withdraw ETH
```solidity
// Specify amount in USD (6 decimals)
withdrawEth(USD_AMOUNT)
// Example: 1000000000 to withdraw equivalent to 1,000 USD worth of ETH
```

#### Withdraw USDC
```solidity
// Specify amount in USDC (6 decimals)
withdrawToken(AMOUNT)
// Example: 1000000000 to withdraw 1,000 USDC
```

**Important Notes:**
- Withdrawals are limited by `withdrawalThreshold` (1,000 USD per transaction)
- You cannot withdraw more than your balance
- ETH withdrawals convert USD to ETH using current Chainlink price

## Testing Performed

### Deployment Tests
- MockUSDC successfully deployed
- KipuBankV2 successfully deployed
- Contracts automatically verified on Sourcify and Routescan
- Constructor parameters correctly initialized

### Functionality Tests
- Minted 10,000 USDC test tokens
- Approved KipuBankV2 to spend USDC
- Deposited 1,000 USDC successfully
- Verified USDC balance in USD (returned 1000000000)
- Deposited 0.01 ETH successfully
- Verified ETH balance in USD (returned ~39561400 = ~$39.56)
- Chainlink oracle returning accurate ETH/USD price
- Decimal conversion working correctly

### Security Tests
- Only owner can call restricted functions
- Cannot withdraw more than balance
- Cannot exceed withdrawal threshold
- Cannot exceed bank cap on deposits
- Oracle staleness check functioning
- Zero amount deposits correctly rejected

## Architecture & Design Decisions

### Type Declarations
```solidity
using SafeERC20 for IERC20;
```
- Library usage for secure ERC20 operations
- Prevents common token transfer vulnerabilities

### State Variables Structure
```solidity
// Immutable variables (set once at deployment)
AggregatorV3Interface public immutable i_priceFeed;
IERC20 public immutable i_usdcToken;
uint256 public immutable i_withdrawalThreshold;
uint256 public immutable i_bankCap;

// Constant variables (compile-time)
uint16 private constant ORACLE_HEARTBEAT = 3600;
uint256 private constant DECIMAL_FACTOR = 1e20;
address private constant NATIVE_TOKEN = address(0);

// Storage variables
mapping(address => mapping(address => uint256)) private s_balances;
uint256 private s_depositCount;
uint256 private s_withdrawalCount;
uint256 private s_totalDepositsUsd;
```

### Decimal Conversion Logic
**Challenge:** Handle different decimal places
- ETH: 18 decimals
- Chainlink ETH/USD: 8 decimals
- USDC: 6 decimals

**Solution:**
```solidity
// ETH to USD conversion
function _convertEthToUsd(uint256 _ethAmount) private view returns (uint256) {
    uint256 ethPriceUsd = _getEthUsdPrice(); // 8 decimals
    // (18 decimals * 8 decimals) / 20 decimals = 6 decimals
    return (_ethAmount * ethPriceUsd) / DECIMAL_FACTOR;
}
```

### Using address(0) for Native ETH
**Rationale:**
- Industry standard convention
- Allows uniform handling in nested mappings
- Simplifies balance tracking logic
- Clear distinction between native and ERC-20 tokens

### Check-Effects-Interactions Pattern
**Implementation:**
```solidity
function withdrawEth(uint256 _amountUsd) external {
    // CHECKS
    uint256 currentBalance = s_balances[msg.sender][NATIVE_TOKEN];
    if (_amountUsd > currentBalance) revert InsufficientBalance();
    
    // EFFECTS (state changes)
    s_balances[msg.sender][NATIVE_TOKEN] = currentBalance - _amountUsd;
    s_withdrawalCount++;
    
    // INTERACTIONS (external calls)
    _transferEth(msg.sender, ethAmount);
}
```

### Custom Errors vs Require Strings
**Gas Optimization:**
- Custom errors: ~50 gas
- Require strings: ~200-500 gas

**Implementation:**
```solidity
error KipuBankV2__InsufficientBalance(
    address user,
    address token,
    uint256 available,
    uint256 requested
);
```

### Oracle Security
**Validations Implemented:**
1. Price must be > 0
2. Price must be fresh (< heartbeat)
3. Proper error handling
```solidity
function _getEthUsdPrice() private view returns (uint256) {
    (, int256 answer, , uint256 updatedAt, ) = i_priceFeed.latestRoundData();
    
    if (answer <= 0) revert KipuBankV2__OracleInvalidPrice();
    
    uint256 timeSinceUpdate = block.timestamp - updatedAt;
    if (timeSinceUpdate > ORACLE_HEARTBEAT) {
        revert KipuBankV2__OracleStalePrice(timeSinceUpdate, ORACLE_HEARTBEAT);
    }
    
    return uint256(answer);
}
```

## Security Considerations

### Implemented Security Measures
1. **Access Control:** OpenZeppelin Ownable for privileged operations
2. **Reentrancy Protection:** CEI pattern consistently applied
3. **Safe Transfers:** SafeERC20 library for token operations
4. **Input Validation:** Comprehensive checks before state changes
5. **Oracle Security:** Staleness and validity checks
6. **Integer Overflow:** Solidity 0.8.x built-in protection
7. **Gas Optimization:** Minimized storage operations

### Potential Improvements
- Add ReentrancyGuard from OpenZeppelin for additional protection
- Implement pause mechanism for emergency stops
- Add multi-signature for owner operations
- Implement withdrawal delays for large amounts
- Add events for all state changes

## Technology Stack

- **Language:** Solidity ^0.8.26
- **Framework:** Remix IDE
- **Libraries:** 
  - OpenZeppelin Contracts v5.0.0
  - Chainlink Contracts
- **Oracle:** Chainlink Price Feeds
- **Network:** Ethereum Sepolia Testnet
- **Verification:** Sourcify & Routescan

## NatSpec Documentation

The contract includes comprehensive NatSpec comments:
- Contract-level documentation
- Function descriptions with `@notice`, `@dev`, `@param`, `@return`
- Custom error documentation
- Event documentation
- Complex logic explanations

## Learning Outcomes

This project demonstrates:
- Advanced Solidity patterns and best practices
- Oracle integration for real-world data
- Multi-token accounting systems
- Security-first development approach
- Gas optimization techniques
- Professional code documentation
- Smart contract verification
- Testnet deployment workflow

## Author

**[Marcos del Río]**
- GitHub: [https://github.com/Marcos-script/]
- Project: Ethereum Developer Pack - Module 3

## License

MIT License - Educational purposes

---

**Deployment Date:** October 2024  
**Network:** Ethereum Sepolia Testnet  
**Compiler Version:** 0.8.26  
**Optimization:** Enabled (200 runs)
