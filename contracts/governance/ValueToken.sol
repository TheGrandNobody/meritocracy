pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/**
 * @title A contract for the Value Token
 * @author Nobody (that's me!)
 * @notice The value token is the governance token of the value feed, an economic regulating tool,
 * and a means of rewarding users for positive performance
 * @dev Ownable so that later on it can be sent to a governance smart contract.
 */
contract ValueToken is ERC20("Value", "VALUE"), Ownable {

    /**
     * @notice A record of all 
     */
    mapping (address => uint256) public voteBalances;

    /**
     * @notice A record of all delegates
     */
    mapping (address => address) public delegates;

    
    bytes32 public constant EIP_DOMAIN_TYPEHASH = keccak256("EIPDomain(string ))

    bytes32 public constant DELEGATION_STRUCT_TYPEHASH = 

    event DelegateUpdated(address indexed delegator, address indexed oldDelegatee, address indexed newDelegatee);

    /**
     * @notice Delegates a user's (msg.sender) votes to a given user
     * @param _newDelegatee The specified user
     */
    function delegate(address _newDelegatee) public {
        address oldDelegatee = delegates[msg.sender];
        delegates[msg.sender] = _newDelegatee;

        emit DelegateUpdated(msg.sender, oldDelegatee, _newDelegatee);
        
    }

    /**
     * @notice Creates a specific sum of tokens to an owner address.
     * @param _to The specified owner address
     * @param _amount Amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
    
}