pragma solidity 0.7.0;


/**
 * @title An interface for the Value Feed 
 * @author Nobody (that's me!)
 */
interface IValueFeed {

    function viewTotalAmount(address _user) external view returns (uint256);

    function viewMeritScore(address _user) external view returns (uint256);

    function viewRate(address _user) external view returns (uint256);

    function calculateReward(address _user) external view returns (uint256);
    
    function viewAllocatedValue(address _user, address _tokenAddress) external view returns (uint256);

}