pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import "../interfaces/IValueFeed.sol";
import "../interfaces/IValueToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


/**
 * @title A contract for the Value Senate
 * @author Nobody (that's me!)
 * @notice The value senate is the voting module of the Value Feed
 * Some code is taken and changed from the "Comp.sol" contract, available at
 * https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol.
 * Credits are given/written accordingly.
 */
contract ValueSenateV0 is Ownable {

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
     * @notice All possible proposals that can be made
     */
    enum Proposal {
        Trade,
        Success,
        Update
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

        address proposer;                // Address of the "trade for" proposer
        address sourceToken;             // Address of the token held by a given value pool (to exchange with)
        address targetAsset;             // Address of the target token's contract (to exchange for)

        bool withdrawal;                 // Determines whether this is a withdrawal trade proposal

        mapping (address => bool) voted; // Record of users who have voted

        State state;                     // The state of the proposal
    }

    /**
     * @notice Info of Value Feed update proposals.
     */
    struct UpdateProposal {
        uint256 id;       // ID of the update proposal
        uint256 startTime;               // The unix time at which the voting period for this proposal starts
        uint256 endTime;                 // The unix time at which the voting period for this proposal ends
        uint256 votesFor;                // The number of votes for the proposal
        uint256 votesAgainst;            // The number of votes against the proposal

        address proposer; // Address of the proposer

        mapping (address => bool) voted;

        State state;      // The state of the proposal
    }

    struct SuccessProposal {
        uint256 id;                      // ID of the success proposal
        uint256 tradeId;                 // ID of the initial trade proposal
        uint256 withdrawalId;            // ID of the withdrawal trade proposal
        uint256 startTime;               // The unix time at which the voting period for this proposal starts
        uint256 endTime;                 // The unix time at which the voting period for this proposal ends
        uint256 votesFor;                // The number of votes for the proposal
        uint256 votesAgainst;            // The number of votes against the proposal
        
        bool aiVote;                     // The vote of the AI;

        mapping (address => bool) voted; // Record of users who have voted

        State state;                     // The state of the proposal
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
     * @notice A record of all success proposals
     */
    mapping (uint256 => SuccessProposal) public successProposals;

    /**
     * @notice Integer for atomic increase (keeps tracks of the latest trade proposal ID)
     */
    uint256 public lastTradeId;

    /**
     * @notice Keeps track of the total amount of trade proposals for the current quadri-weekly period of trading
     */
    uint256 public tradeProposalCount;

    /**
     * @notice Integer for atomic increase (keeps tracks of the latest success proposal ID)
     */
    uint256 public lastSuccessId;

    event Voted(address indexed voter, uint256 id, bool pro);
    event TradeProposalRequested(address proposer, address valuePool, address targetAsset, bool second);
    event TradeProposalInitiated(uint256 id, address indexed proposer, address indexed valuePool, address indexed targetAsset, uint256 startTime, uint256 endTime, bool second);
    event TradeProposalFinalized(uint256 id, uint256 time, bool passed);
    event TradeWithdrawal(uint256 id);
    event SuccessProposalInitiated(uint256 id, uint256 startTime, uint256 endTime);
    event SuccessProposalFinalized(uint256 degreeOfSuccess, bool aiVote, bool success);

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant EIP_DOMAIN_TYPEHASH = keccak256("EIPDomain(string contractName, uint256 chainId, address contractAddress)");

    /// @notice The EIP-712 typehash for the voting struct used by the contract
    bytes32 public constant VOTE_STRUCT_TYPEHASH = keccak256("Vote(address voter, uint256 id, bool pro, Proposal type)");

    /**
     * @notice Initiates a trade proposal request to the A.I to check whether the limit is reached or not
     * @param _proposer The ETH address of the specified user making the proposal
     * @param _valuePool The ERC20 address of the asset belonging to the specified value pool
     * @param _targetAsset The ERC20 address of the specified target token for which the value pool's contents will be traded
     * @param _second Determines whether this is the first (trade for) or second (trade back for) round of the proposal
     */
    function proposeTrade(address _proposer, address _valuePool, address _targetAsset, bool _second) public {
        emit TradeProposalRequested(_proposer, _valuePool, _targetAsset, _second);
    }

    /**
     * @notice Initiates a trade proposal by a given user so as to trade the asset of a value pool for a target asset
     * @param _proposer The ETH address of the specified user making the proposal
     * @param _valuePool The ERC20 address of the asset belonging to the specified value pool
     * @param _targetAsset The ERC20 address of the specified target token for which the value pool's contents will be traded
     * @param _second Determines whether this is the first (trade for) or second (trade back for) round of the proposal
     * @param _limitReached Determines whether the limit of trade proposals has been reached or not
     */
    function _proposeTrade(address _proposer, address _valuePool, address _targetAsset, bool _second, bool _limitReached) external onlyOwner  {
        require(!_limitReached, "ValueSenate::_proposeTrade:The total limit of proposals allowed this month is reached");
        require(valueFeed.viewMeritScore(_proposer) + value.viewDelegateVotes(_proposer) >= 4e5, "ValueSenate::_proposeTrade: User is not competent enough to propose"); 
        require(valueFeed.viewSwapped(_valuePool) == _second, "ValueSenate::_proposeTrade: Value Pool is not in the right state");

        TradeProposal storage proposal = tradeProposals[lastTradeId];
        proposal.id = lastTradeId;
        lastTradeId = lastTradeId.add(1);
    
        proposal.startTime = block.timestamp;
        proposal.endTime = proposal.startTime.add(86400);
        proposal.proposer = _proposer;
        proposal.votesFor = valueFeed.viewMeritScore(_proposer) + value.viewDelegateVotes(_proposer);
        proposal.voted[_proposer] = true;
        proposal.sourceToken = _valuePool;
        proposal.targetAsset = _targetAsset;

        proposal.withdrawal = _second;
        
        proposal.state = State.InProgress;   

        emit TradeProposalInitiated(proposal.id, _proposer, _valuePool, _targetAsset, proposal.startTime, proposal.endTime, _second);
    }

    /**
     * @notice Initiates a success proposal for a given trade proposal and its corresponding withdrawal proposal
     * @param _tradeId The specified id of the trade proposal
     * @param _withdrawalId The specified id of the withdrawal proposal
     * @param _internalEval The A.I's ruling on whether this was a successful proposal or not
     */
    function proposeEvaluation(uint256 _tradeId, uint256 _withdrawalId, bool _internalEval) public onlyOwner {
        SuccessProposal storage proposal = successProposals[lastSuccessId];

        proposal.id = lastSuccessId;
        lastSuccessId = lastSuccessId.add(1);
        proposal.startTime = block.timestamp;
        proposal.endTime = proposal.startTime.add(86400);
        proposal.aiVote = _internalEval;
        proposal.tradeId = _tradeId;
        proposal.withdrawalId = _withdrawalId;

        proposal.state = State.InProgress;

        emit SuccessProposalInitiated(proposal.id, proposal.startTime, proposal.endTime);
    }

    /**
     * Resets the count of trade proposals
     */
    function resetProposalCount() external onlyOwner {
        tradeProposalCount = 0;
    }

    /**
     * @notice (Intermediary) votes on a given proposal for a user
     * @param _id The ID of the specified trade proposal
     * @param _pro Whether the user is for (true) or against (false) the trade proposal
     */
    function voteOnProposal(uint256 _id, bool _pro, Proposal _type) public {
        _voteOnProposal(_id, msg.sender, _pro, _type);
    }

    /**
     * @notice (Intermediary) votes on a given proposal for a signee
     * @param _id The ID of the specified trade proposal
     * @param _pro Whether the user is for (true) or against (false) the trade proposal
     * @param _r Half of the ECDSA signature pair
     * @param _s Half of the ECDSA signature pair
     * @param _v The recovery byte of the signature
     * @dev Taken and changed from Comp.sol
     */
    function voteOnProposalBySignature(uint _id, bool _pro, Proposal _type, bytes32 _r, bytes32 _s, uint8 _v) public {
        bytes32 domain = keccak256(abi.encode(EIP_DOMAIN_TYPEHASH, keccak256(bytes("Value")), getChainId(), address(this)));
        bytes32 delegationHash = keccak256(abi.encode(VOTE_STRUCT_TYPEHASH, _id, _pro, _type));
        bytes32 msgDigest = keccak256(abi.encodePacked("\x19\x01", domain, delegationHash));
        address signee = ecrecover(msgDigest, _v, _r, _s);

        require(signee != address(0), "ValueToken::voteOnProposalBySignature: invalid address");
        

        _voteOnProposal(_id, signee, _pro, _type);
    }

    /**
     * @notice Votes on a given proposal for a given user
     * @param _id The ID of the specified trade proposal
     * @param _voter The ETH address of the specified user
     * @param _pro Whether the user is for (true) or against (false) the trade proposal
     * @dev Inspired from Comp.sol
     */
    function _voteOnProposal(uint256 _id, address _voter, bool _pro, Proposal _type) private {
        State state;
        uint256 startTime;
        uint256 endTime;
        uint256 votesFor;
        uint256 votesAgainst;
        bool voted;

        if (_type == Proposal.Trade) {
            TradeProposal storage proposal = tradeProposals[_id];
            state = proposal.state;
            startTime = proposal.startTime;
            endTime = proposal.endTime;
            voted = proposal.voted[_voter];
            votesFor = proposal.votesFor;
            votesAgainst = proposal.votesAgainst;
        } else if (_type == Proposal.Update) {
            UpdateProposal storage proposal = updateProposals[_id];
            state = proposal.state;
            startTime = proposal.startTime;
            endTime = proposal.endTime;
            voted = proposal.voted[_voter];
            votesFor = proposal.votesFor;
            votesAgainst = proposal.votesAgainst;
        } else if (_type == Proposal.Success) {
            SuccessProposal storage proposal = successProposals[_id];
            state = proposal.state;
            startTime = proposal.startTime;
            endTime = proposal.endTime;
            voted = proposal.voted[_voter];
            votesFor = proposal.votesFor;
            votesAgainst = proposal.votesAgainst;
        }

        require((state == State.InProgress)
             && (startTime <= block.timestamp) 
             && (endTime > block.timestamp), "ValueSenate::_voteOnTradeProposal: Proposal is not in state for voting");
        require(valueFeed.viewTotalAmount(_voter) > 0, "ValueSenate::_voteOnTradeProposal: User is not a contributor to the Value Feed");
        require(!voted, "ValueSenate::_voteOnTradeProposal: User has already voted");
        require(value.viewDelegate(_voter) == _voter, "ValueSenate::_voteOnTradeProposal");

        uint256 numberOfVotes = valueFeed.viewMeritScore(_voter).add(value.viewDelegateVotes(_voter));

        if (_pro) {
            votesFor = votesFor.add(numberOfVotes);
        } else {
            votesAgainst = votesAgainst.add(numberOfVotes);
        }

        if (_type == Proposal.Trade) {
            TradeProposal storage proposal = tradeProposals[_id];
            proposal.voted[_voter] = true;
            proposal.votesFor = votesFor;
            proposal.votesAgainst = votesAgainst;
        } else if (_type == Proposal.Update) {
            UpdateProposal storage proposal = updateProposals[_id];
            proposal.voted[_voter] = true;
            proposal.votesFor = votesFor;
            proposal.votesAgainst = votesAgainst;          
        } else if (_type == Proposal.Success) {
            SuccessProposal storage proposal = successProposals[_id];
            proposal.voted[_voter] = true;
            proposal.votesFor = votesFor;
            proposal.votesAgainst = votesAgainst;
        }

        emit Voted(_voter, _id, _pro);
    }
    
    /**
     * @notice Tallies all trade votes for a given proposal
     * @param _id The id of the specified trade proposal
     */
    function tallyTradeVote(uint256 _id) external {
        TradeProposal storage proposal = tradeProposals[_id];
        require(proposal.endTime <= block.timestamp, "ValueSenate::tallyTradeVote: Proposal still under voting period");
        require(proposal.state == State.InProgress, "ValueSenate::tallyTradeVote: Proposal is not in a state for tallying");

        uint256 total = proposal.votesAgainst.add(proposal.votesFor);
        uint256 percentageFor = proposal.votesFor.mul(100).div(total);
        uint256 percentageAgainst = proposal.votesAgainst.mul(100).div(total);
        uint256 timeOfExecution = block.timestamp;

        proposal.timeOfExecution = proposal.withdrawal ? timeOfExecution : timeOfExecution.add(2592000);
        proposal.state = percentageFor > percentageAgainst ? State.Passed : State.Failed;
        emit TradeProposalFinalized(_id, timeOfExecution, percentageFor > percentageAgainst);
    }

    /**
     * @notice Executes a given trade proposal
     * @param _id The id of the specified trade proposal
     * @param _path The path the token must take for this swap (only contains the target asset contract for ETH trades)
     * @param _swap Determines the type of swap to perform
     */
    function executeTradeProposal(uint256 _id, address[] memory _path, uint8 _swap) public {
        TradeProposal storage proposal = tradeProposals[_id];
        require(proposal.state == State.Passed, "ValueSenate::executeTradeProposal: Proposal was not passed");
        require(proposal.timeOfExecution <= block.timestamp, "ValueSenate::executeTradeProposal: Timelock time has not passed yet");
        
        if (_swap == 1) {
            valueFeed.swapTokensForToken(_path, proposal.withdrawal);
        } else if (_swap == 2) {
            valueFeed.swapTokensForETH(_path[0], proposal.withdrawal);
        } else {
            valueFeed.swapETHForToken(_path[0], proposal.withdrawal);
        }

        proposal.state = State.Executed;

        if (proposal.withdrawal) {
            TradeWithdrawal(_id);
        }
    }

    /**
     * @notice Tallies the votes for a given success proposal (counts the voters' degree of success)
     * @param _id The id of the specified success proposal
     */
    function evaluate(uint256 _id) public onlyOwner {
        SuccessProposal storage proposal = successProposals[_id];
        require(proposal.endTime <= block.timestamp, "ValueSenate::evaluate: Success evaluation still ongoing");
        require(proposal.state == State.InProgress, "ValueSenate::evaluate: Not in state for tallying");

        uint256 total = proposal.votesAgainst.add(proposal.votesFor);
        uint256 percentageFor = proposal.votesFor.mul(100).div(total);
        uint256 percentageAgainst = proposal.votesAgainst.mul(100).div(total);
        uint256 successDegree = percentageFor > percentageAgainst ? percentageFor : percentageAgainst;

        emit SuccessProposalFinalized(successDegree, proposal.aiVote ,percentageFor > percentageAgainst);

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