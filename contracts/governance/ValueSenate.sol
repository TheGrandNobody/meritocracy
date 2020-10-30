pragma solidity 0.7.0;


/**
 * @title A contract for the Value Senate
 * @author Nobody (that's me!)
 * @notice The value senate is the voting module of the Value Feed
 */
contract ValueSenate{

    /// @notice Info of Value Feed trade proposals.
    struct TradeProposal {
        uint256 id;         // ID of the trade proposal
        address proposer;   // Address of the proposer


    }

    /// @notice Info of Value Feed trade proposals.
    struct UpdateProposal {
        uint256 id;       // ID of the update proposal
        address proposer; // Address of the proposer
    }
}