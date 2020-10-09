pragma solidity 0.7.0;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
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
    // The dev address.
    address public owner;
    // The maximum rate at which VALUE is minted every day.
    // At the maximum rate, supply lasts 10 years. Note: we operate on a base of 1 = 1e18 (account for decimals)
    uint256 public constant MAX_DISTRIBUTION_RATE = 2.46575342465753e22;
    uint256 public constant MAX_COLLECTION_RATE = 4.93150684931506e21;
    // The rate at which part of the rewards are taken from users in case consecutive ill behavior.
    uint256 public rateOfCollection;
    // VALUE tokens created per block, initially starts at the mid point of its max and min.
    uint256 public rateOfDistribution;
    // A numerical representation of the entire behavioral state of the Value Feed
    uint8 public ebState;
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
     * Constructor: initiates the value feed smart contract.
     * @param _value The value token
     * @param _owner The dev address
     * @param _ebState The current economical-behavioral state of the Value Feed
     */
    constructor(ValueToken _value, address _owner) {
        value = _value;
        owner = _owner;
        startTime = block.timestamp;
        rateOfDistribution = MAX_DISTRIBUTION_RATE / 2;
        ebState = 100;
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
     */
    function deposit(address _tokenAddress) public {
        emit Deposit(msg.sender, msg.value);

        valuePools[_tokenAddress].totalValue += msg.value;
        valuePools[_tokenAddress].userValue[msg.sender] += msg.value;

    }

    /**
     * @notice Returns the reward rate, to view it on the frontend
     * @param _user ETH address of the specified user
     */
    function viewRate(address _user) external view returns (uint256) {
        UserData storage user = userData[_user];
        return user.rewardRate;
    }

    /**
     * @notice Calculates the (total) reward for a given user address.
     * @param _user ETH address of the specified user
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
        emit Withdrawal(msg.sender, _amount);

        valuePools[_tokenAddress].totalValue -= _amount;
        valuePools[_tokenAddress].userValue[msg.sender] -= _amount;
    }

    /**
     * @notice Withdraws all tokens owned by a user from their respective value pools
     * @param _user The ETH address of the specified user
     */
    function withdrawAllOwned(address _user) public {
        for (i = 0; i < tokens.length; i++) {
            if (valuePools[tokens[i]].userValue[_user] != 0) {
                withdrawFromPool(tokens[i], valuePools[tokens[i]].userValue[_user]);
            }
        }
    }

    /**
     * @notice An incentive against ill behavior based on the economical-behavioral state of the Value Feed
     */
    function discourageDistribution() internal {
        if (ebState > 0) {
            ebState -= 1;
        }

        if (ebState == 90) {

        } else if (ebState == 80) {

        } else if (ebState == 70) {

        } else if (ebState == 60) {

        } else if (ebState == 50) {

        } else if (ebState == 40) {

        } else if (ebState == 30) {

        } else if (ebState == 20) {

        } else if (ebState == 10) {

        } else if (ebState == 0) {

        }
    }

    //function encourageDistribution

    //function 

}
