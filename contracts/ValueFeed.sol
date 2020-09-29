pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ValueToken.sol";

/**
 * Allows a value pool asset migration from one value pool to another.
 */
interface TokenMigrator {
    /**
     * @param token The current value pool's token address.
     * @return The new value pool's token address
     * @dev Migrator should have full access to the caller's value pool token.
     */
    function migrate(IERC20 token) external returns (IERC20);
}
/**
 * @title A contract for the Value Feed
 * @author Nobody (that's me)
 * @notice The value feed is the emergent body made up of all value pools,
 * and all the assets stored in them as well as their holders themselves.
 * @dev Ownable so that later on it can be sent to a governance smart contract.
 * (This will only be done once VALUE has enough holders, so much so that an ecosystem has been created (>1000 users)
 */
contract ValueFeed is Ownable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // The amount of tokens in the value feed belonging to a specific user.
        uint256 inProgress; // The amount of tokens owed by the value feed to the user (rewarded every four weeks).
        uint256 meritScore; // The score which determines the value that the user brings to the system.
        uint256 lastReward; // The amount of points last awarded to the user.
        uint256 streak;     // The number of consecutive successful proposals made by the user (if applicable).
        uint256 rewardRate; // The cumulative reward rate used to calculate the amount of VALUE earned every four weeks.
    }



    // Info of each pool.
    struct PoolInfo {
        IERC20 token;        // Address of the specific token contract stored in the current value pool.
        uint256 value;       // The total monetary value (not the token) in this pool.
        mapping (uint256 => address) addresses; // Each address in this pool
    }

    // The VALUE token
    ValueToken public value;
    // The dev address.
    address public owner;
    TokenMigrator public migrator;
    // The maximum rate at which VALUE is minted every day.
    // At the maximum rate, supply lasts 10 years. Note: we operate on a base of 1 = 1e18 (account for decimals)
    uint256 public constant MAX_MINT_RATE = 2.46575342465753e22;
    // The minimum rate at which VALUE is minted every day.
    // At the minimum rate, supply lasts 20 years.
    uint256 public constant MIN_MINT_RATE = 1.23287671232877e22;
    // VALUE tokens created per block.
    uint256 public rateOfDistribution;
    // The time in seconds at which the value feed is first put up. Used in order to know when to distribute rewards.
    uint256 public startTime;
    // The total amount of monetary value in the entire value feed
    uint256 public totalValue = 0;


    // Info of each value pool in the feed.
    FeedInfo[] public feedInfo;
    // Info of each user that provides tokens to the feed.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;


    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    /**
     * Constructor: initiates the value feed smart contract.
     * @param _value The value token
     * @param _devaddr The dev address
     * @param _valuePerBlock The amount of VALUE tokens minted each block
     */
    constructor(ValueToken _value, address _owner, uint256 _valuePerBlock) {
        value = _value;
        owner = _owner;
        valuePerBlock = _valuePerBlock;
        startTime = block.timestamp;
    }

    /**
     * @notice Adds a new value pool to the feed (Owner only)
     * @param _allocationShare The percentage that this pool occupies in relation to the entire value feed.
     * @param _poolToken The specified token for the new value pool
     * @dev Adding the same token twice will screw things up
     */
    function add(address[]  _addresses, IERC20 _poolToken) public onlyOwner {
        feedInfo.push(FeedInfo({poolToken: _poolToken, addresses: _addresses}));
    }



    /**
     *
     *
     *
     */
    function calculateRate(uint256 _pid, address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_pid][_user];
        uint256 rate = user.meritScore * ;
        return rate;
    }

    /**
     * @notice Calculates the reward for a given user address.
     * @param _pid UserInfo index of the specified user
     * @param _user ETH address of the specified user
     */
    function calculateReward(uint256 _pid, address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_pid][_user];
        if (user.meritScore == 0) {
            amount = user.amount * ;
        }
        uint256 amount = (calculateRate(_pid, _user) * user.amount) / 1e18;
        return amount;
    }

    /**
     * @notice Calculates the total reward for a given user address at the end of the month.
     * @param _pid UserInfo index of the specified user
     * @param _user ETH address of the specified user
     */
    function calculateTotalReward(uint256 _pid, address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_pid][_user];
        uint256 amount = (calculateRate(_pid, _user) * user.amount) / 1e18;
        return amount + user.inProgress;
    }

}
