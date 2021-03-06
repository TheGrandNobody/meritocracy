// SPDX-License-Identifier: MIT
// Copyright (c) <2020> <Open Zeppelin>
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
/*Copyright 2020 Compound Labs, Inc.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IValueFeed.sol";


/**
 * @title A contract for the Value token
 * @author Nobody (that's me!)
 * @notice The value token is the governance token of the value feed, an economic regulating tool,
 * and a means of rewarding users for positive performance. 
 * Some code is taken and changed from the "Comp.sol" contract, available at
 * https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol.
 * Credits are given/written accordingly.
 */
contract ValueToken is ERC20("Value", "VALUE"), Ownable {

    using SafeMath for uint256;

    IValueFeed valueFeed;

    /**
     * @notice Constructor: Initializes the Value Senate contract
     * @param _valueFeed Address of the Value Feed contract
     */
    constructor(address _valueFeed) {
        valueFeed = IValueFeed(_valueFeed);
    }

    /**
     * @notice A record of all additional votes (owned by delegates)
     */
    mapping (address => uint256) public additionalVoteBalances;

    /**
     * @notice A record of all delegates
     */
    mapping (address => address) public delegates;

    /**
     * A record of all contract states specifically for validating signatures
     */
    mapping (address => uint) public nonces;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant EIP_DOMAIN_TYPEHASH = keccak256("EIPDomain(string contractName, uint256 chainId, address contractAddress)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_STRUCT_TYPEHASH = keccak256("Delegation(address delegatee, uint256 nonce, uint256 expiryTime)");

    event DelegateUpdated(address indexed delegator, address indexed oldDelegatee, address indexed newDelegatee);

    /**
     * @notice (Intermediary) Delegates a user's (msg.sender) votes to a given user
     * @param _newDelegatee The specified user
     * @dev Taken and changed from Comp.sol
     */
    function delegate(address _newDelegatee) public {
        _delegate(msg.sender, _newDelegatee);
    }

    /**
     * @notice (Intermediary) Delegates votes for a signee to a given user
     * @param _newDelegatee The specified user
     * @param _nonce The contract state required to match the signature
     * @param _expiryTime The time at which the signature expires
     * @param _r Half of the ECDSA signature pair
     * @param _s Half of the ECDSA signature pair
     * @param _v The recovery byte of the signature
     * @dev Taken and changed from Comp.sol
     */
    function delegateBySignature(address _newDelegatee, uint256 _nonce, uint256 _expiryTime, bytes32 _r, bytes32 _s, uint8 _v) public {
        bytes32 domain = keccak256(abi.encode(EIP_DOMAIN_TYPEHASH, keccak256(bytes("Value")), getChainId(), address(this)));
        bytes32 delegationHash = keccak256(abi.encode(DELEGATION_STRUCT_TYPEHASH, _newDelegatee, _nonce, _expiryTime));
        bytes32 msgDigest = keccak256(abi.encodePacked("\x19\x01", domain, delegationHash));
        address signee = ecrecover(msgDigest, _v, _r, _s);

        require(signee != address(0), "ValueToken::delegateBySignature: invalid address");
        require(_nonce == nonces[signee]++, "ValueToken::delegateBySignature: nonces are not equal");
        require(block.timestamp <= _expiryTime, "ValueToken::delegateBySignature: signature expired");

        _delegate(signee, _newDelegatee);
    }

    /**
     * @notice Delegates a given user's votes to another given user
     * @param _delegator The specified user whose votes are being transferred
     * @param _delegatee The specified user who is acquiring additional votes
     * @dev Taken and changed from Comp.sol
     */
    function _delegate(address _delegator, address _delegatee) internal {
        address oldDelegatee = delegates[_delegator];
        additionalVoteBalances[oldDelegatee] = additionalVoteBalances[oldDelegatee].sub(valueFeed.viewMeritScore(_delegator));
        delegates[_delegator] = _delegatee;

        emit DelegateUpdated(_delegator, oldDelegatee, _delegatee);

        additionalVoteBalances[_delegatee] = additionalVoteBalances[_delegatee].add(valueFeed.viewMeritScore(_delegator));
    }

    /**
     * @notice Creates a specific sum of tokens to an owner address.
     * @param _to The specified owner address
     * @param _amount Amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    /**
     * @notice Retrieves the address of a delegate for a given user
     * @param _user The address of the specified user
     * @return The address of the delegate for this address (self if none)
     */
    function viewDelegate(address _user) external view returns (address) {
        return delegates[_user] != address(0) ? delegates[_user] : _user;
    }

    /**
     * @notice Retrieves the additional amount of votes for a given delegate
     * @param _delegator The address of the specified delegate
     * @return The additional vote balance of the specified delegate
     */
    function viewDelegateVotes(address _delegator) external view returns (uint256) {
        return additionalVoteBalances[_delegator];
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