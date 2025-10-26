// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*///////////////////////////////////////////////////////////////
                            IMPORTS
//////////////////////////////////////////////////////////////*/

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/*///////////////////////////////////////////////////////////////
                        MOCK USDC CONTRACT
//////////////////////////////////////////////////////////////*/

/**
 * @title MockUSDC
 * @author Ethereum Developer Pack - Module 3
 * @notice Mock ERC-20 token for testing purposes with 6 decimals (like real USDC)
 * @dev This is a simple ERC-20 implementation for educational purposes only
 */
contract MockUSDC {
    /// @notice Token name
    string public constant name = "Mock USDC";
    
    /// @notice Token symbol
    string public constant symbol = "mUSDC";
    
    /// @notice Token decimals (same as real USDC)
    uint8 public constant decimals = 6;
    
    /// @notice Total supply of tokens
    uint256 public totalSupply;
    
    /// @notice Mapping of balances
    mapping(address account => uint256 balance) public balanceOf;
    
    /// @notice Mapping of allowances
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;
    
    /// @notice Emitted when tokens are transferred
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    /// @notice Emitted when an allowance is set
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    /**
     * @notice Transfers tokens to a recipient
     * @param _to Recipient address
     * @param _value Amount to transfer
     * @return success True if transfer succeeded
     */
    function transfer(address _to, uint256 _value) external returns (bool success) {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        
        unchecked {
            balanceOf[msg.sender] -= _value;
            balanceOf[_to] += _value;
        }
        
        emit Transfer(msg.sender, _to, _value);
        return true;
    }
    
    /**
     * @notice Approves spender to spend tokens
     * @param _spender Spender address
     * @param _value Amount to approve
     * @return success True if approval succeeded
     */
    function approve(address _spender, uint256 _value) external returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    /**
     * @notice Transfers tokens from one address to another
     * @param _from Sender address
     * @param _to Recipient address
     * @param _value Amount to transfer
     * @return success True if transfer succeeded
     */
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success) {
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Insufficient allowance");
        
        unchecked {
            balanceOf[_from] -= _value;
            balanceOf[_to] += _value;
            allowance[_from][msg.sender] -= _value;
        }
        
        emit Transfer(_from, _to, _value);
        return true;
    }
    
    /**
     * @notice Mints tokens to any address (for testing only)
     * @param _to Recipient address
     * @param _amount Amount to mint
     */
    function mint(address _to, uint256 _amount) external {
        unchecked {
            totalSupply += _amount;
            balanceOf[_to] += _amount;
        }
        emit Transfer(address(0), _to, _amount);
    }
}

/*///////////////////////////////////////////////////////////////
                    KIPUBANK V2 CONTRACT
//////////////////////////////////////////////////////////////*/

/**
 * @title KipuBankV2
 * @author Ethereum Developer Pack - Module 3
 * @notice Advanced multi-token vault system with Chainlink price feeds and USD accounting
 * @dev Implements security patterns: Check-Effects-Interactions, custom errors, and modifiers
 * @custom:security This contract uses Chainlink oracles and supports both native ETH and ERC-20 tokens
 */
contract KipuBankV2 is Ownable {
    /*///////////////////////////////////////////////////////////////
                        TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/
    
    using SafeERC20 for IERC20;
    
    /*///////////////////////////////////////////////////////////////
                        STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Chainlink ETH/USD price feed interface
    /// @dev Sepolia: 0x694AA1769357215DE4FAC081bf1f309aDC325306
    AggregatorV3Interface public immutable i_priceFeed;
    
    /// @notice Mock USDC token interface for multi-token support
    IERC20 public immutable i_usdcToken;
    
    /// @notice Maximum withdrawal amount per transaction in USD (6 decimals)
    /// @dev Immutable for security and gas optimization
    uint256 public immutable i_withdrawalThreshold;
    
    /// @notice Global deposit cap in USD (6 decimals)
    /// @dev Total deposits across all users cannot exceed this amount
    uint256 public immutable i_bankCap;
    
    /// @notice Chainlink price feed heartbeat in seconds
    /// @dev If price is older than this, it's considered stale
    uint16 private constant ORACLE_HEARTBEAT = 3600;
    
    /// @notice Decimal conversion factor for ETH to USD calculations
    /// @dev Used to convert from 18 decimals (ETH) + 8 decimals (Chainlink) to 6 decimals (USD)
    uint256 private constant DECIMAL_FACTOR = 1e20;
    
    /// @notice Address representing native ETH in the balances mapping
    /// @dev Using address(0) as convention for native token
    address private constant NATIVE_TOKEN = address(0);
    
    /// @notice Nested mapping to store user balances by token
    /// @dev mapping(user => mapping(token => balance in USD with 6 decimals))
    /// @dev address(0) represents native ETH
    mapping(address user => mapping(address token => uint256 balance)) private s_balances;
    
    /// @notice Total number of deposits made to the contract
    uint256 private s_depositCount;
    
    /// @notice Total number of withdrawals made from the contract
    uint256 private s_withdrawalCount;
    
    /// @notice Total value deposited in USD across all tokens (6 decimals)
    uint256 private s_totalDepositsUsd;
    
    /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Emitted when a user successfully deposits tokens
    /// @param user Address of the user making the deposit
    /// @param token Address of the token deposited (address(0) for ETH)
    /// @param amountInToken Amount deposited in token's native decimals
    /// @param valueInUsd Value in USD with 6 decimals
    event KipuBankV2__DepositSuccessful(
        address indexed user,
        address indexed token,
        uint256 amountInToken,
        uint256 valueInUsd
    );
    
    /// @notice Emitted when a user successfully withdraws tokens
    /// @param user Address of the user making the withdrawal
    /// @param token Address of the token withdrawn (address(0) for ETH)
    /// @param amountInToken Amount withdrawn in token's native decimals
    /// @param valueInUsd Value in USD with 6 decimals
    event KipuBankV2__WithdrawalSuccessful(
        address indexed user,
        address indexed token,
        uint256 amountInToken,
        uint256 valueInUsd
    );
    
    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Error thrown when deposit would exceed the bank cap
    /// @param currentTotal Current total deposits in USD
    /// @param attemptedDeposit Amount user is trying to deposit in USD
    /// @param bankCap Maximum allowed total deposits in USD
    error KipuBankV2__BankCapExceeded(uint256 currentTotal, uint256 attemptedDeposit, uint256 bankCap);
    
    /// @notice Error thrown when user has insufficient balance for withdrawal
    /// @param user Address of the user
    /// @param token Token address
    /// @param available Available balance in USD
    /// @param requested Requested withdrawal amount in USD
    error KipuBankV2__InsufficientBalance(address user, address token, uint256 available, uint256 requested);
    
    /// @notice Error thrown when withdrawal amount exceeds the threshold
    /// @param requested Requested withdrawal amount in USD
    /// @param threshold Maximum allowed per transaction in USD
    error KipuBankV2__WithdrawalThresholdExceeded(uint256 requested, uint256 threshold);
    
    /// @notice Error thrown when ETH transfer fails
    /// @param recipient Address that should have received ETH
    error KipuBankV2__TransferFailed(address recipient);
    
    /// @notice Error thrown when deposit amount is zero
    error KipuBankV2__DepositAmountZero();
    
    /// @notice Error thrown when Chainlink oracle returns invalid price
    error KipuBankV2__OracleInvalidPrice();
    
    /// @notice Error thrown when Chainlink price data is stale
    /// @param timeSinceUpdate Time since last update in seconds
    /// @param heartbeat Maximum allowed time in seconds
    error KipuBankV2__OracleStalePrice(uint256 timeSinceUpdate, uint256 heartbeat);
    
    /// @notice Error thrown when token address is invalid
    error KipuBankV2__InvalidToken();
    
    /*///////////////////////////////////////////////////////////////
                        MODIFIERS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Validates that withdrawal amount doesn't exceed threshold
    /// @param _amountUsd Amount to validate in USD (6 decimals)
    /// @dev Reverts with KipuBankV2__WithdrawalThresholdExceeded if amount exceeds threshold
    modifier withinThreshold(uint256 _amountUsd) {
        if (_amountUsd > i_withdrawalThreshold) {
            revert KipuBankV2__WithdrawalThresholdExceeded(_amountUsd, i_withdrawalThreshold);
        }
        _;
    }
    
    /*///////////////////////////////////////////////////////////////
                        FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Initializes the KipuBankV2 contract
     * @param _priceFeed Chainlink ETH/USD price feed address
     * @param _usdcToken Mock USDC token address
     * @param _withdrawalThreshold Maximum amount that can be withdrawn per transaction in USD (6 decimals)
     * @param _bankCap Maximum total deposits allowed in the bank in USD (6 decimals)
     * @param _owner Address of the contract owner
     * @dev Sets immutable values and assigns contract owner
     */
    constructor(
        address _priceFeed,
        address _usdcToken,
        uint256 _withdrawalThreshold,
        uint256 _bankCap,
        address _owner
    ) Ownable(_owner) {
        i_priceFeed = AggregatorV3Interface(_priceFeed);
        i_usdcToken = IERC20(_usdcToken);
        i_withdrawalThreshold = _withdrawalThreshold;
        i_bankCap = _bankCap;
    }
    
    /*//////////////////////////////////////////////////////////////
                    EXTERNAL PAYABLE
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Allows users to deposit native ETH into their vault
     * @dev Converts ETH to USD using Chainlink oracle and stores value in USD
     * @dev Implements Check-Effects-Interactions pattern for security
     * @dev Uses single read and single write to state variable for gas optimization
     */
    function depositEth() external payable {
        // CHECKS
        if (msg.value == 0) {
            revert KipuBankV2__DepositAmountZero();
        }
        
        uint256 valueInUsd = _convertEthToUsd(msg.value);
        uint256 currentBalance = s_balances[msg.sender][NATIVE_TOKEN];
        uint256 newTotalDeposits = s_totalDepositsUsd + valueInUsd;
        
        if (newTotalDeposits > i_bankCap) {
            revert KipuBankV2__BankCapExceeded(s_totalDepositsUsd, valueInUsd, i_bankCap);
        }
        
        // EFFECTS
        uint256 newBalance;
        unchecked {
            newBalance = currentBalance + valueInUsd;
            s_depositCount++;
            s_totalDepositsUsd = newTotalDeposits;
        }
        
        s_balances[msg.sender][NATIVE_TOKEN] = newBalance;
        
        emit KipuBankV2__DepositSuccessful(msg.sender, NATIVE_TOKEN, msg.value, valueInUsd);
        
        // INTERACTIONS - None in this function
    }
    
    /*//////////////////////////////////////////////////////////////
                        EXTERNAL
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Allows users to deposit ERC-20 tokens (Mock USDC) into their vault
     * @param _amount Amount of tokens to deposit (6 decimals for USDC)
     * @dev Token must be approved before calling this function
     * @dev Implements Check-Effects-Interactions pattern for security
     */
    function depositToken(uint256 _amount) external {
        // CHECKS
        if (_amount == 0) {
            revert KipuBankV2__DepositAmountZero();
        }
        
        uint256 currentBalance = s_balances[msg.sender][address(i_usdcToken)];
        uint256 newTotalDeposits = s_totalDepositsUsd + _amount;
        
        if (newTotalDeposits > i_bankCap) {
            revert KipuBankV2__BankCapExceeded(s_totalDepositsUsd, _amount, i_bankCap);
        }
        
        // EFFECTS
        uint256 newBalance;
        unchecked {
            newBalance = currentBalance + _amount;
            s_depositCount++;
            s_totalDepositsUsd = newTotalDeposits;
        }
        
        s_balances[msg.sender][address(i_usdcToken)] = newBalance;
        
        emit KipuBankV2__DepositSuccessful(msg.sender, address(i_usdcToken), _amount, _amount);
        
        // INTERACTIONS
        i_usdcToken.safeTransferFrom(msg.sender, address(this), _amount);
    }
    
    /**
     * @notice Allows users to withdraw native ETH from their vault
     * @param _amountUsd Amount to withdraw in USD (6 decimals)
     * @dev Converts USD to ETH using Chainlink oracle
     * @dev Implements Check-Effects-Interactions pattern
     * @dev Only allows withdrawal up to the threshold defined at deployment
     */
    function withdrawEth(uint256 _amountUsd) external withinThreshold(_amountUsd) {
        // CHECKS
        uint256 currentBalance = s_balances[msg.sender][NATIVE_TOKEN];
        
        if (_amountUsd > currentBalance) {
            revert KipuBankV2__InsufficientBalance(msg.sender, NATIVE_TOKEN, currentBalance, _amountUsd);
        }
        
        uint256 ethAmount = _convertUsdToEth(_amountUsd);
        
        // EFFECTS
        uint256 newBalance;
        unchecked {
            newBalance = currentBalance - _amountUsd;
            s_withdrawalCount++;
            s_totalDepositsUsd -= _amountUsd;
        }
        
        s_balances[msg.sender][NATIVE_TOKEN] = newBalance;
        
        emit KipuBankV2__WithdrawalSuccessful(msg.sender, NATIVE_TOKEN, ethAmount, _amountUsd);
        
        // INTERACTIONS
        _transferEth(msg.sender, ethAmount);
    }
    
    /**
     * @notice Allows users to withdraw ERC-20 tokens (Mock USDC) from their vault
     * @param _amount Amount to withdraw (6 decimals for USDC)
     * @dev Implements Check-Effects-Interactions pattern
     * @dev Only allows withdrawal up to the threshold defined at deployment
     */
    function withdrawToken(uint256 _amount) external withinThreshold(_amount) {
        // CHECKS
        address tokenAddress = address(i_usdcToken);
        uint256 currentBalance = s_balances[msg.sender][tokenAddress];
        
        if (_amount > currentBalance) {
            revert KipuBankV2__InsufficientBalance(msg.sender, tokenAddress, currentBalance, _amount);
        }
        
        // EFFECTS
        uint256 newBalance;
        unchecked {
            newBalance = currentBalance - _amount;
            s_withdrawalCount++;
            s_totalDepositsUsd -= _amount;
        }
        
        s_balances[msg.sender][tokenAddress] = newBalance;
        
        emit KipuBankV2__WithdrawalSuccessful(msg.sender, tokenAddress, _amount, _amount);
        
        // INTERACTIONS
        i_usdcToken.safeTransfer(msg.sender, _amount);
    }
    
    /*//////////////////////////////////////////////////////////////
                        PRIVATE
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Internal function to safely transfer ETH
     * @param _to Recipient address
     * @param _amount Amount to transfer in wei
     * @dev Uses call() for secure ETH transfers
     * @dev Reverts if transfer fails
     */
    function _transferEth(address _to, uint256 _amount) private {
        (bool success, ) = _to.call{value: _amount}("");
        if (!success) {
            revert KipuBankV2__TransferFailed(_to);
        }
    }
    
    /**
     * @notice Converts ETH amount to USD using Chainlink price feed
     * @param _ethAmount Amount of ETH in wei (18 decimals)
     * @return usdAmount Amount in USD (6 decimals)
     * @dev Uses DECIMAL_FACTOR to convert from 18+8 decimals to 6 decimals
     */
    function _convertEthToUsd(uint256 _ethAmount) private view returns (uint256 usdAmount) {
        uint256 ethPriceUsd = _getEthUsdPrice();
        usdAmount = (_ethAmount * ethPriceUsd) / DECIMAL_FACTOR;
    }
    
    /**
     * @notice Converts USD amount to ETH using Chainlink price feed
     * @param _usdAmount Amount in USD (6 decimals)
     * @return ethAmount Amount of ETH in wei (18 decimals)
     * @dev Uses DECIMAL_FACTOR to convert from 6 decimals to 18 decimals
     */
    function _convertUsdToEth(uint256 _usdAmount) private view returns (uint256 ethAmount) {
        uint256 ethPriceUsd = _getEthUsdPrice();
        ethAmount = (_usdAmount * DECIMAL_FACTOR) / ethPriceUsd;
    }
    
    /**
     * @notice Gets current ETH/USD price from Chainlink oracle
     * @return price Current ETH price in USD (8 decimals)
     * @dev Implements security checks for oracle data validity
     * @dev Reverts if price is invalid or stale
     */
    function _getEthUsdPrice() private view returns (uint256 price) {
        (, int256 answer, , uint256 updatedAt, ) = i_priceFeed.latestRoundData();
        
        if (answer <= 0) {
            revert KipuBankV2__OracleInvalidPrice();
        }
        
        uint256 timeSinceUpdate;
        unchecked {
            timeSinceUpdate = block.timestamp - updatedAt;
        }
        
        if (timeSinceUpdate > ORACLE_HEARTBEAT) {
            revert KipuBankV2__OracleStalePrice(timeSinceUpdate, ORACLE_HEARTBEAT);
        }
        
        price = uint256(answer);
    }
    
    /*//////////////////////////////////////////////////////////////
                    EXTERNAL VIEW
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Returns the vault balance of a specific user for a specific token
     * @param _user Address of the user to query
     * @param _token Address of the token (address(0) for ETH)
     * @return balance The user's balance in USD (6 decimals)
     */
    function getBalance(address _user, address _token) external view returns (uint256 balance) {
        balance = s_balances[_user][_token];
    }
    
    /**
     * @notice Returns the total vault balance of a user across all tokens
     * @param _user Address of the user to query
     * @return totalBalance Total balance in USD (6 decimals)
     */
    function getTotalBalance(address _user) external view returns (uint256 totalBalance) {
        totalBalance = s_balances[_user][NATIVE_TOKEN] + s_balances[_user][address(i_usdcToken)];
    }
    
    /**
     * @notice Returns the total number of deposits made
     * @return count Total deposit count
     */
    function getDepositCount() external view returns (uint256 count) {
        count = s_depositCount;
    }
    
    /**
     * @notice Returns the total number of withdrawals made
     * @return count Total withdrawal count
     */
    function getWithdrawalCount() external view returns (uint256 count) {
        count = s_withdrawalCount;
    }
    
    /**
     * @notice Returns the withdrawal threshold
     * @return threshold Maximum amount that can be withdrawn per transaction in USD (6 decimals)
     */
    function getWithdrawalThreshold() external view returns (uint256 threshold) {
        threshold = i_withdrawalThreshold;
    }
    
    /**
     * @notice Returns the bank cap
     * @return cap Maximum total deposits allowed in USD (6 decimals)
     */
    function getBankCap() external view returns (uint256 cap) {
        cap = i_bankCap;
    }
    
    /**
     * @notice Returns the contract owner address
     * @return ownerAddress Address of the contract owner
     */
    function getOwner() external view returns (address ownerAddress) {
        ownerAddress = owner();
    }
    
    /**
     * @notice Returns the total value deposited in USD
     * @return total Total deposits in USD (6 decimals)
     */
    function getTotalDepositsUsd() external view returns (uint256 total) {
        total = s_totalDepositsUsd;
    }
    
    /**
     * @notice Returns the total ETH held in the contract
     * @return total Total ETH balance in wei
     */
    function getTotalEthBalance() external view returns (uint256 total) {
        total = address(this).balance;
    }
    
    /**
     * @notice Returns the current ETH/USD price from Chainlink
     * @return price Current price (8 decimals)
     */
    function getCurrentEthUsdPrice() external view returns (uint256 price) {
        price = _getEthUsdPrice();
    }
    
    /**
     * @notice Returns the Mock USDC token address
     * @return token Address of the Mock USDC token
     */
    function getUsdcTokenAddress() external view returns (address token) {
        token = address(i_usdcToken);
    }
    
    /**
     * @notice Returns the Chainlink price feed address
     * @return feed Address of the Chainlink ETH/USD price feed
     */
    function getPriceFeedAddress() external view returns (address feed) {
        feed = address(i_priceFeed);
    }
}
