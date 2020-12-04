// SPDX-License-Identifier: MIT

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

    function viewSwapped(address _tokenAddress) external view returns (bool);

    function swapTokensForToken(address[] memory _path, bool _swapBack) external;

    function swapTokensForETH(address _tokenAddress, bool _swapBack) external;

    function swapETHForToken(address _tokenAddress, bool _swapBack) external;

}