pragma solidity 0.7.0;


/**
 * @title An interface for the Value token
 * @author Nobody (that's me!)
 */
interface IValueToken {

    function viewDelegate(address _user) external view returns (address);

    function viewDelegateVotes(address _delegator) external view returns (uint256);

}