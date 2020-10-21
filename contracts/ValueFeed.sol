pragma solidity 0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./ValueToken.sol";

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

    // Info of each user.
    struct UserData {
        uint256 inProgress; // The amount of tokens owed by the value feed to the user (rewarded every four weeks).
        uint256 meritScore; // The score which determines the value that the user brings to the system.
        uint256 lastReward; // The amount of points last awarded to the user.
        uint256 streak;     // The number of consecutive successful proposals made by the user (if applicable).
        uint256 rewardRate; // The cumulative reward rate used to calculate the amount of VALUE earned every four weeks.
    }

    // Info of each pool.
    struct ValuePool {
        uint256 totalValue;                     // The total monetary value (not the token) in this pool.
        mapping (address => uint256) userValue; // Each address in this pool
    }

    // The VALUE token
    ValueToken public value;
    // The dev address
    address public dev;
    // The Uniswap Router
    IUniswapV2Router02 private UniswapV2Router02;
    // The maximum rate at which VALUE is minted every day.
    address private constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    // At the maximum rate, supply lasts 10 years. Note: we operate on a base of 1 = 1e18 (account for decimals)
    uint256 public constant MAX_DISTRIBUTION_RATE = 2.46575342465753e22;
    // The maximum rate at which VALUE is collected.
    uint256 public constant MAX_COLLECTION_RATE = 4.93150684931506e21;
    // The rate at which part of the rewards are taken from users in case of consecutive ill behavior
    uint256 public rateOfCollection;
    // VALUE tokens created per block, initially starts at the mid point of its max and min.
    uint256 public rateOfDistribution;
    // A numerical representation of the entire behavioral state of the Value Feed
    uint16 public ebState = 150;
    // The time in seconds at which the value feed is first put up. Used in order to know when to distribute rewards.
    uint256 public startTime;
    // The total amount of monetary value in the entire value feed.
    uint256 public totalValue;

    // Info of each user that provides tokens to the feed.
    mapping (address => UserData) public userData;
    // Each value pool is mapped to its respective token address
    mapping (address => ValuePool) public valuePools;
    // Contains each token address for which a value pool was created
    address[] tokens;


    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Swap(address[] indexed tokens, uint256 amount);

    /**
     * Constructor: initiates the value feed smart contract
     * @param _value The value token
     */
    constructor(ValueToken _value) {
        value = _value;
        dev = msg.sender;
        startTime = block.timestamp;
        rateOfDistribution = MAX_DISTRIBUTION_RATE / 2;
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
     * @notice Deposits a given amount to a value pool
     * @param _tokenAddress The address of the value pool's token's contract
     * @param _amount The specified amount of tokens being deposited
     */
    function deposit(address _tokenAddress, uint256 _amount) public payable {
        ValuePool storage p = valuePools[_tokenAddress];
        emit Deposit(msg.sender, _amount);

        p.totalValue += _amount;
        p.userValue[msg.sender] += _amount;
        totalValue += _amount;
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
        return (user.rewardRate * user.meritScore);
    }

    /**
     * @notice Withdraws a given amount from a value pool
     * @param _tokenAddress The address of the token contract who's value pool
     * @param _amount The amount of tokens being withdrawn
     */
    function withdrawFromPool(address _tokenAddress, uint256 _amount) public {
        require(valuePools[_tokenAddress].userValue[msg.sender] >= _amount, "Insufficient funds");
        emit Withdraw(msg.sender, _amount);

        valuePools[_tokenAddress].totalValue -= _amount;
        valuePools[_tokenAddress].userValue[msg.sender] -= _amount;
        totalValue -= _amount;
    }

    /**
     * @notice Withdraws all tokens owned by a user from their respective value pools
     * @param _user The ETH address of the specified user
     */
    function withdrawAllOwned(address _user) public {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (valuePools[tokens[i]].userValue[_user] != 0) {
                withdrawFromPool(tokens[i], valuePools[tokens[i]].userValue[_user]);
            }
        }
    }

    /**
     * @notice Updates the rate of collection and distribution in an encouraging or discouraging way
     * @dev Only called by the E.A.I
     * @param encourage The manner by which the E.A.I wishes to influence the rates
     */
    function _updateRates(bool encourage) internal onlyOwner {
        uint256 _ebState = ebState;
        if (encourage && _ebState < 200) {
            ebState++;
        } else if (!encourage && _ebState > 0) {
            ebState--;
        }
        if (ebState % 3 == 0) {
            rateOfDistribution = _calculateSafeRate(!encourage, ebState, rateOfDistribution, MAX_DISTRIBUTION_RATE);
            rateOfCollection = _calculateSafeRate(encourage, ebState, rateOfCollection, MAX_COLLECTION_RATE);
        }
    }

    /**
     * @notice Safely recalculates a given rate (without allowing it to go below 0 or go above the set maximum),
     * based on the economical behavioral state of the value feed
     * @dev Helper function (works for any rate which is equally or inversely influenced by the ebState)
     * @param encourage The manner by which the E.A.I wishes to influence the rates
     * @param _ebState The economical-behavioral state of the value feed
     * @param _currentRate The specified current rate
     * @param _maxRate The specified limit of the rate
     * @return The newly recalculated rate
     */
    function _calculateSafeRate(bool encourage, uint16 _ebState, uint256 _currentRate, uint256 _maxRate) internal pure
    returns (uint256) {
        uint256 newRate;

        if (!encourage && _currentRate < _maxRate) {
            newRate = (_currentRate * (1e4 + abs(150 - _ebState))) / 1e4;
            if (newRate >= _maxRate) {
                newRate = _maxRate;
            }
        } else if (encourage && _currentRate > 0) {
            newRate = (_currentRate / (1e4 + abs(75 - _ebState))) / 1e4;
            if (newRate <= 0) {
                newRate = 0;
            }
        }
        return newRate;
    }

    /**
     * @notice Takes the absolute value of a given number
     * @dev Helper function
     * @param _number The specified number
     * @return The absolute value of the number
     */
    function abs(int256 _number) private pure returns (uint256) {
        return _number < 0 ? uint256(_number * -1) : uint256(_number);
    }

    /**
     * @notice Approves withdrawal of a given amount of a given ERC20 token by the Uniswap Router
     * @dev Necessary for any Uniswap-related value pool operations
     * @param _tokenAddress The specified address of the ERC20 token
     * @param _amount The specified maximum amount of tokens allowed to be withdrawn by the Router
     */
    function approve(address _tokenAddress, uint256 _amount) private {
        ERC20(_tokenAddress).approve(UNISWAP_ROUTER_ADDRESS, _amount);
    }

}