pragma solidity 0.7.0;


/**
 * @title A contract for the Value Senate
 * @author Nobody (that's me!)
 * @notice The value senate is the voting module of the Value Feed
 * @dev Some inspiration from Compound's Governor Alpha
 */
contract ValueSenate {

    /**
     * @notice All states a proposal can possess
     */
    enum State {
        Awaiting,
        Active,
        Passed,
        Failed,
        Executed,
        Canceled
    }

    /**
     * @notice Info of Value Feed trade proposals.
     */
    struct TradeProposal {
        uint256 id;              // ID of the trade proposal
        uint256 timeOfExecution; // The time at which the proposal will be executed (if it is successful)
        uint256 startTime;      // The unix time at which the voting period for this proposal starts
        uint256 endTime;        // The unix time at which the voting period for this proposal ends
        uint256 votesFor;        // The number of votes for the proposal
        uint256 votesAgainst;    // The number of votes against the proposal

        address proposer;        // Address of the proposer
        address sourceToken;     // Address of the token held by a given value pool (to exchange with)
        address targetAsset;     // Address of the target token's contract (to exchange for)

        State state;
    }

    /**
     * @notice Info of Value Feed update proposals.
     */
    struct UpdateProposal {
        uint256 id;       // ID of the update proposal

        address proposer; // Address of the proposer
    }

    /**
     * @notice A record of all trade proposals
     */
    mapping (uint256 => TradeProposal) public tradeProposals;

    /**
     * @notice A record of all update proposals
     */
    mapping (uint256 => UpdateProposal) public updateProposals;

    
}