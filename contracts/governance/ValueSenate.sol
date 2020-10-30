pragma solidity 0.7.0;


/**
 * @title A contract for the Value Senate
 * @author Nobody (that's me!)
 * @notice The value senate is the voting module of the Value Feed
 */
contract ValueSenate {


    /// @notice Info of Value Feed trade proposals.
    struct TradeProposal {
        uint256 id;              // ID of the trade proposal
        uint256 timeOfExecution; // The time at which the proposal will be executed (if it is successful)
        address proposer;        // Address of the proposer
        address sourceToken;     // Address of the token held by a given value pool (to exchange with)
        address targetAsset;     // Address of the target token's contract (to exchange for)
    }

    /// @notice Info of Value Feed update proposals.
    struct UpdateProposal {
        uint256 id;       // ID of the update proposal
        address proposer; // Address of the proposer
    }
}