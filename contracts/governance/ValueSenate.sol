pragma solidity 0.7.0;

import "../interfaces/IValueFeed.sol";
import "../interfaces/IValueToken.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


/**
 * @title A contract for the Value Senate
 * @author Nobody (that's me!)
 * @notice The value senate is the voting module of the Value Feed
 * Some code is taken and changed from the "Comp.sol" contract, available at
 * https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol.
 * Credits are given/written accordingly.
 */
contract ValueSenate {

    using SafeMath for uint256;

    IValueFeed public valueFeed;
    IValueToken public value;

    /**
     * @notice Constructor: Initializes the Value Senate contract
     * @param _valueFeed Address of the Value Feed contract
     * @param _valueToken Address of the Value token contract
     */
    constructor(address _valueFeed, address _valueToken) {
        valueFeed = IValueFeed(_valueFeed);
        value = IValueToken(_valueToken);
    }

    /**
     * @notice All states a proposal can possess
     */
    enum State {
        InProgress,
        Passed,
        Failed,
        Executed,
        Canceled
    }

    /**
     * @notice Info of Value Feed trade proposals.
     */
    struct TradeProposal {
        uint256 id;                      // ID of the trade proposal
        uint256 startTime;               // The unix time at which the voting period for this proposal starts
        uint256 endTime;                 // The unix time at which the voting period for this proposal ends
        uint256 timeOfExecution;         // The unix time at which the proposal is executed (if passed)
        uint256 votesFor;                // The number of votes for the proposal
        uint256 votesAgainst;            // The number of votes against the proposal

        address proposer;                // Address of the proposer
        address sourceToken;             // Address of the token held by a given value pool (to exchange with)
        address targetAsset;             // Address of the target token's contract (to exchange for)

        mapping (address => bool) voted; // Record of users who have voted

        State state;                     // The state of the proposal
    }

    /**
     * @notice Info of Value Feed update proposals.
     */
    struct UpdateProposal {
        uint256 id;       // ID of the update proposal

        address proposer; // Address of the proposer

        mapping (address => bool) voted;

        State state;      // The state of the proposal
    }

    /**
     * @notice A record of all trade proposals
     */
    mapping (uint256 => TradeProposal) public tradeProposals;

    /**
     * @notice A record of all update proposals
     */
    mapping (uint256 => UpdateProposal) public updateProposals;

    /**
     * @notice Integer for atomic increase (keeps tracks of the latest trade proposal ID)
     */
    uint256 public lastTradeId;

    event Voted(address indexed voter, uint256 id, bool pro);
    event TradeProposalInitiated(uint256 id, address indexed proposer, address valuePool, address targetAsset);
    event TradeProposalFinalized(uint256 id, uint256 time, bool passed);

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant EIP_DOMAIN_TYPEHASH = keccak256("EIPDomain(string contractName, uint256 chainId, address contractAddress)");

    /// @notice The EIP-712 typehash for the voting struct used by the contract
    bytes32 public constant VOTE_STRUCT_TYPEHASH = keccak256("Vote(address voter, uint256 id, bool pro)");

    function proposeTrade(address proposer, address valuePool, address targetAsset) public  {
        require(valueFeed.viewMeritScore(proposer) + value.viewDelegateVotes(proposer) >= 4e5, "ValueSenate::proposeTrade: User is not competent enough to propose"); 
        require(!valueFeed.viewSwapped(valuePool), "ValueSenate::proposeTrade: Value Pool is already in use");

        TradeProposal storage proposal = tradeProposals[lastTradeId];
        proposal.id = lastTradeId;
        lastTradeId = lastTradeId.add(1);
    
        proposal.startTime = block.timestamp;
        proposal.endTime = proposal.startTime.add(86400);
        proposal.proposer = proposer;
        proposal.votesFor = valueFeed.viewMeritScore(proposer) + value.viewDelegateVotes(proposer);
        proposal.voted[proposer] = true;
        proposal.sourceToken = valuePool;
        proposal.targetAsset = targetAsset;
        proposal.state = State.InProgress;

        emit TradeProposalInitiated(proposal.id, proposer, valuePool, targetAsset);
    }

    /**
     * @notice (Intermediary) votes on a given trade proposal for a user
     * @param _id The ID of the specified trade proposal
     * @param _pro Whether the user is for (true) or against (false) the trade proposal
     */
    function voteOnTradeProposal(uint256 _id, bool _pro) public {
        _voteOnTradeProposal(_id, msg.sender, _pro);
    }

    /**
     * @notice (Intermediary) votes on a given trade proposal for a signee
     * @param _id The ID of the specified trade proposal
     * @param _pro Whether the user is for (true) or against (false) the trade proposal
     * @param _r Half of the ECDSA signature pair
     * @param _s Half of the ECDSA signature pair
     * @param _v The recovery byte of the signature
     * @dev Taken and changed from Comp.sol
     */
    function voteOnTradeProposalBySignature(uint _id, bool _pro, bytes32 _r, bytes32 _s, uint8 _v) public {
        bytes32 domain = keccak256(abi.encode(EIP_DOMAIN_TYPEHASH, keccak256(bytes("Value")), getChainId(), address(this)));
        bytes32 delegationHash = keccak256(abi.encode(VOTE_STRUCT_TYPEHASH, _id, _pro));
        bytes32 msgDigest = keccak256(abi.encodePacked("\x19\x01", domain, delegationHash));
        address signee = ecrecover(msgDigest, _v, _r, _s);

        require(signee != address(0), "ValueToken::voteOnTradeProposalBySignature: invalid address");
        
        _voteOnTradeProposal(_id, signee, _pro);
    }

    /**
     * @notice Votes on a given trade proposal for a given user
     * @param _id The ID of the specified trade proposal
     * @param _voter The ETH address of the specified user
     * @param _pro Whether the user is for (true) or against (false) the trade proposal
     * @dev Inspired from Comp.sol
     */
    function _voteOnTradeProposal(uint256 _id, address _voter, bool _pro) private {
        TradeProposal storage proposal = tradeProposals[_id];
        require((proposal.state == State.InProgress)
             && (proposal.startTime <= block.timestamp) 
             && (proposal.endTime > block.timestamp), "ValueSenate::_voteOnTradeProposal: Proposal is not in state for voting");
        require(valueFeed.viewTotalAmount(_voter) > 0, "ValueSenate::_voteOnTradeProposal: User is not a contributor to the Value Feed");
        require(!proposal.voted[_voter], "ValueSenate::_voteOnTradeProposal: User has already voted");
        require(value.viewDelegate(_voter) == _voter, "ValueSenate::_voteOnTradeProposal");

        uint256 numberOfVotes = valueFeed.viewMeritScore(_voter).add(value.viewDelegateVotes(_voter));

        if (_pro) {
            proposal.votesFor = proposal.votesFor.add(numberOfVotes);
        } else {
            proposal.votesAgainst = proposal.votesAgainst.add(numberOfVotes);
        }

        proposal.voted[_voter] = true;

        emit Voted(_voter, _id, _pro);
    }
    
    function tallyFirstTradeVote(uint256 _id) external {
        TradeProposal storage proposal = tradeProposals[_id];
        require(proposal.endTime <= block.timestamp, "ValueSenate::tallyFirstTradeVote: Proposal still under voting period");
        require(proposal.state == State.InProgress, "ValueSenate::tallyFirstTradeVote: Proposal is not in a state for tallying");

        uint256 total = proposal.votesAgainst.add(proposal.votesFor);
        uint256 percentageFor = proposal.votesFor.mul(100).div(total);
        uint256 percentageAgainst = proposal.votesAgainst.mul(100).div(total);
        uint256 timeOfExecution = block.timestamp;

        if (percentageFor > percentageAgainst) {
            proposal.state = State.Passed;
            proposal.timeOfExecution = timeOfExecution.add(2592000);
            emit TradeProposalFinalized(_id, timeOfExecution, true);
        } else {
            proposal.state = State.Failed;
            emit TradeProposalFinalized(_id, timeOfExecution, false);
        }
    }

    function executeTradeProposal(uint256 _id, address[] memory _path, bool _ethTrade, bool _tokenForEth) public {
        TradeProposal storage proposal = tradeProposals[_id];
        require(proposal.state == State.Passed, "ValueSenate::executeTradeProposal: Proposal was not passed");
        require(proposal.timeOfExecution <= block.timestamp, "ValueSenate::executeTradeProposal: Timelock time has not passed yet");
        
        if (!_ethTrade) {
            valueFeed.swapTokensForToken(_path, false);
        } else if (_tokenForEth) {
            valueFeed.swapTokensForETH(_path[0], false);
        } else {
            valueFeed.swapETHForToken(_path, false);
        }

        proposal.state = State.Executed;
    }

    
    /**
     * @notice Obtains the CHAIN_ID variable corresponding to the network the contract is deployed at
     * @return The chain ID for the current network this contract is deployed at
     * @dev Taken and changed from Comp.sol
     */
    function getChainId() internal pure returns (uint256) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}