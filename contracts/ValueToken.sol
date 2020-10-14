pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


// ValueToken with Governance.
contract ValueToken is ERC20("Value", "VALUE"), Ownable {

    /// @notice Creates a specific sum of tokens (_amount) to an owner address (_to).
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

}