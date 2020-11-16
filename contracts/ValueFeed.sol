pragma solidity 0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./governance/ValueToken.sol";

/**
 * @title A contract for the Value Feed
 * @author Nobody (that's me!)
 * @notice The value feed is the emergent body made up of all value pools,
 * and all the assets stored in them as well as their holders themselves.
 * @dev Ownable so that later on it can be sent to a governance smart contract.
 * (This will only be done once VALUE has enough holders, so much so that an ecosystem has been created (>1000 users)
 */
contract ValueFeed is Ownable {

    using SafeMath for uint256;

    /**
     * @notice Info of each user
     */
    struct UserData {
        uint256 inProgress;   // The amount of tokens owed by the value feed to the user (rewarded every four weeks)
        uint256 meritScore;   // The score which determines the value that the user brings to the system
        uint256 lastReward;   // The amount of points last awarded to the user
        uint256 streak;       // The number of consecutive successful proposals made by the user (if applicable)
        uint256 rewardRate;   // The cumulative reward rate used to calculate the amount of VALUE earned every four weeks
        uint256 totalAmount;  // The numerical total amount of tokens owned by a user (not the total value)
    }

    
    /**
     * @notice Info of each pool
     */
    struct ValuePool {
        uint256 totalValue;                     // The total monetary value (not the token) in this pool
        bool swapped;
        mapping (address => uint256) userValue; // Each address in this pool
    }

    /// @notice The VALUE token
    ValueToken public value;
    /// @notice The dev address
    address public dev;
    /// @notice The Uniswap Router
    IUniswapV2Router02 public UniswapV2Router02;
    /// @notice The maximum rate at which VALUE is minted every day.
    address public constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    /// @notice At the maximum rate, supply lasts 10 years. Note: we operate on a base of 1 = 1e18 (account for decimals)
    uint256 public constant MAX_DISTRIBUTION_RATE = 2.46575342465753e22;
    /// @notice The maximum rate at which VALUE is collected.
    uint256 public constant MAX_COLLECTION_RATE = 4.93150684931506e21;
    /// @notice The rate at which part of the rewards are taken from users in case of consecutive ill behavior
    uint256 public rateOfCollection;
    /// @notice VALUE tokens created per block, initially starts at the mid point of its max and min
    uint256 public rateOfDistribution;
    /// @notice A numerical representation of the entire behavioral state of the Value Feed
    uint16 public ebState = 150;
    /// @notice The time in seconds at which the value feed is first put up. Used in order to know when to distribute rewards
    uint256 public startTime;
    /// @notice The total amount of monetary value in the entire value feed
    uint256 public totalValue;

    /// @notice Info of each user that provides tokens to the feed
    mapping (address => UserData) public userData;
    /// @notice Each value pool is mapped to its respective token address
    mapping (address => ValuePool) public valuePools;
    /// @notice Contains each token address for which a value pool was created
    address[] public tokens;


    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event Swap(address[] indexed tokens, uint256 amount);

    /**
     * @notice Constructor: initiates the value feed smart contract
     * @param _value The value token
     */
    constructor(ValueToken _value) {
        value = _value;
        dev = msg.sender;
        startTime = block.timestamp;
        rateOfDistribution = MAX_DISTRIBUTION_RATE.div(2);
        UniswapV2Router02 = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);
    }

    /**
    * @notice Adds a token address for which a value pool was created
    * @param _tokenAddress The address of the value pool's token's contract
    * @dev Owner only to prevent any DoS attacks
    */
    function addToken(address _tokenAddress) public onlyOwner {
        tokens.push(_tokenAddress);
    }

    /**
     * @notice Deposits a given amount of tokens to a value pool
     * @param _tokenAddress The address of the value pool's token's contract
     * @param _amount The specified amount of tokens being deposited
     */
    function deposit(address _tokenAddress, uint256 _amount) public payable {
        ValuePool storage valuePool = valuePools[_tokenAddress];
        UserData storage user = userData[msg.sender];
        emit Deposit(msg.sender, _tokenAddress, _amount);

        user.totalAmount = user.totalAmount.add(_amount);
        valuePool.totalValue = valuePool.totalValue.add(_amount);
        valuePool.userValue[msg.sender] = valuePool.userValue[msg.sender].add(_amount);
        
    }

    /**
     * @notice Retrives the total numerical amount of tokens allocated by a given user
     * @dev Does not return the value of these tokens, just the numerical sum total
     * @param _user ETH address of the specified user 
     * @return The total numerical amount of tokens allocated by the user
     */
    function viewTotalAmount(address _user) external view returns (uint256) {
        UserData storage user = userData[_user];
        return user.totalAmount;
    }
    /**
     * @notice Retrieves the merit score of a given user
     * @dev For vote weight calculations/frontend
     * @param _user ETH address of the specified user
     * @return The merit score of the user
     */
    function viewMeritScore(address _user) external view returns (uint256) {
        UserData storage user = userData[_user];
        return user.meritScore;
    }

    /**
     * @notice Retrieves the quadri-weekly reward rate of a given user
     * @dev Mainly for frontend usage
     * @param _user ETH address of the specified user
     * @return The cumulative reward rate of the user
     */
    function viewRate(address _user) external view returns (uint256) {
        UserData storage user = userData[_user];
        return user.rewardRate;
    }

    /**
     * @notice Calculates the (total) reward for a given user address
     * @param _user ETH address of the specified user
     * @return The total reward in VALUE owed to the user
     */
    function calculateReward(address _user) external view returns (uint256) {
        UserData storage user = userData[_user];
        return user.rewardRate.mul(user.meritScore);
    }

    /**
     * @notice Retrieves the amount of tokens belonging to a given user in a given value pool
     * @param _user ETH address of the specified user
     * @param _tokenAddress The address of the specified ERC20 token contract of this value pool
     * @return The amount of the specified tokens allocated in the value pool by the user
     */
    function viewAllocatedValue(address _user, address _tokenAddress) external view returns (uint256) {
        ValuePool storage valuePool = valuePools[_tokenAddress];
        return valuePool.userValue[_user];
    }

    /**
     * @notice Retrieves whether the value pool is currently swapped for another token or not
     * @param _tokenAddress The address of the specified ERC20 token contract of this value pool
     */
    function viewSwapped(address _tokenAddress) external view returns (bool) {
        ValuePool storage valuePool = valuePools[_tokenAddress];
        return valuePool.swapped;
    }

    /**
     * @notice Withdraws a given amount from a given value pool
     * @param _tokenAddress The address of the specified token contract
     * @param _amount The amount of tokens being withdrawn
     */
    function withdrawFromPool(address _tokenAddress, uint256 _amount) public {
        ValuePool storage valuePool = valuePools[_tokenAddress];
        UserData storage user = userData[msg.sender];
        require(valuePool.swapped, "ValueFeed::withdrawFromPool: Original assets currently in use");
        require(valuePool.userValue[msg.sender] >= _amount, "ValueFeed::withdrawFromPool:Insufficient funds.");
        emit Withdraw(msg.sender, _tokenAddress, _amount);

        user.totalAmount = user.totalAmount.sub(_amount);
        valuePool.totalValue = valuePool.totalValue.sub(_amount);
        valuePool.userValue[msg.sender] = valuePool.userValue[msg.sender].sub(_amount);
    }

    /**
     * @notice Withdraws all tokens owned by a user from their respective value pools
     */
    function withdrawAllOwned() public {
        for (uint256 i = 0; i < tokens.length; i++) {
            ValuePool storage valuePool = valuePools[tokens[i]];
            if (valuePool.userValue[msg.sender] > 0) {
                withdrawFromPool(tokens[i], valuePool.userValue[msg.sender]);
            }
        }
    }

    /**
     * @notice Updates the rate of collection and distribution in an encouraging or discouraging way
     * @dev Only called by the E.A.I
     * @param _encourage The manner by which the E.A.I wishes to influence the rates
     */
    function _updateRates(bool _encourage) internal onlyOwner {
        uint256 _ebState = ebState;
        if (_encourage && _ebState < 200) {
            ebState++;
        } else if (!_encourage && _ebState > 0) {
            ebState--;
        }
        if (ebState % 3 == 0) {
            rateOfDistribution = _calculateSafeRate(!_encourage, ebState, rateOfDistribution, MAX_DISTRIBUTION_RATE);
            rateOfCollection = _calculateSafeRate(_encourage, ebState, rateOfCollection, MAX_COLLECTION_RATE);
        }
    }

    /**
     * @notice Safely recalculates a given rate (without allowing it to go below 0 or go above the set maximum),
     * based on the economical behavioral state of the value feed
     * @dev Helper function (works for any rate which is equally or inversely influenced by the ebState)
     * @param _encourage The manner by which the E.A.I wishes to influence the rates
     * @param _ebState The economical-behavioral state of the value feed
     * @param _currentRate The specified current rate
     * @param _maxRate The specified limit of the rate
     * @return The newly recalculated rate
     */
    function _calculateSafeRate(bool _encourage, uint16 _ebState, uint256 _currentRate, uint256 _maxRate) internal pure
    returns (uint256) {
        uint256 newRate;

        if (!_encourage && _currentRate < _maxRate) {
            newRate = _currentRate.mul(1e4 + abs(150 - _ebState)).div(1e4);
            if (newRate >= _maxRate) {
                newRate = _maxRate;
            }
        } else if (_encourage && _currentRate > 0) {
            newRate = _currentRate.div(1e4 + abs(75 - _ebState)).div(1e4);
            if (newRate <= 0) {
                newRate = 0;
            }
        }
        return newRate;
    }

    /**
     * @notice Swaps a value pool's reserves for a given token
     * @param _tokenAddress The specified token address for the UniSwapV2Router02 to use for swapping
     * @param _swapBack Boolean specifying whether the reserves are being swapped back to their original asset
     */
    function swapTokensForETH(address _tokenAddress, bool _swapBack) external onlyOwner {
        address[] memory path = new address[](2);
        path[0] = _tokenAddress;
        path[1] = UniswapV2Router02.WETH();

        ValuePool storage valuePool = valuePools[_tokenAddress];
        uint256 _amount = valuePool.totalValue;
        require(IERC20(_tokenAddress).approve(UNISWAP_ROUTER_ADDRESS, _amount), 'Approve failed.');
        if (_swapBack) {
            require(valuePool.swapped, "ValueFeed::swapTokensforETH: Reserves intact; swapping not necessary");
        } else {
            require(!valuePool.swapped, "ValueFeed::swapTokensforETH: Reserves already in use");
        }

        emit Swap(path, _amount);

        UniswapV2Router02.swapExactTokensForETH(_amount, UniswapV2Router02.getAmountsOut(_amount, path)[1], path, address(this),
                                                block.timestamp.add(15));
        valuePool.swapped = !_swapBack;
    }

    /**
     * @notice Swaps a value pool's reserves for a given token
     * @param _path The specified array of token addresses for the UniSwapV2Router02 to use for swapping
     * @param _swapBack Boolean specifying whether the reserves are being swapped back to their original asset
     */
    function swapTokensForToken(address[] memory _path, bool _swapBack) external onlyOwner {
        ValuePool storage valuePool = valuePools[_path[0]];
        uint256 _amount = valuePool.totalValue;
        require(IERC20(_path[0]).approve(UNISWAP_ROUTER_ADDRESS, _amount), 'Approve failed.');
        if (_swapBack) {
            require(valuePool.swapped, "ValueFeed::swapTokensforToken: Reserves intact; swapping not necessary");
        } else {
            require(!valuePool.swapped, "ValueFeed::swapTokensforToken: Reserves already in use");
        }
        emit Swap(_path, _amount);

        UniswapV2Router02.swapExactTokensForTokens(_amount, UniswapV2Router02.getAmountsOut(_amount, _path)[_path.length.sub(1)], 
                                                  _path, address(this),block.timestamp.add(15));
        valuePool.swapped = !_swapBack;
    }

    /**
     * @notice Approves withdrawal of a given amount of a given ERC20 token by the Uniswap Router
     * @dev Necessary for any Uniswap-related value pool operations
     * @param _tokenAddress The specified address of the ERC20 token
     * @param _amount The specified maximum amount of tokens allowed to be withdrawn by the Router
     */
    function approve(address _tokenAddress, uint256 _amount) private {
        IERC20(_tokenAddress).approve(UNISWAP_ROUTER_ADDRESS, _amount);
    }

    /**
     * @notice Takes the absolute value of a given number
     * @dev Helper function
     * @param _number The specified number
     * @return The absolute value of the number
     */
    function abs(int256 _number) private pure returns (uint256) {
        return _number < 0 ? uint256(_number * (-1)) : uint256(_number);
    }
    
}