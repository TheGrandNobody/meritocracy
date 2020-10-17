pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


// ValueToken with Governance.
contract TestToken is ERC20("test", "TEST"), Ownable {

    /**
     * @notice Creates a specific sum of tokens to an owner address.
     * @param _to The specified owner address
     * @param _amount Amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

}
