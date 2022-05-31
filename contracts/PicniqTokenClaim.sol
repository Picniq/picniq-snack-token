// SPDX-License-Identifier: MIT

pragma solidity 0.8.14;

import "./libraries/MerkleProof.sol";

abstract contract PicniqTokenClaim {
    using MerkleProof for bytes32[];

    bytes32 internal _merkleRoot;
    mapping(address => bool) internal _claims;

    struct MerkleItem {
        address account;
        uint256 amount;
    }

    constructor(bytes32 merkleRoot_) {
        _merkleRoot = merkleRoot_;
    }

    function checkClaimed(address account) public view returns (bool)
    {
        return _claims[account];
    }

    function checkProof(address account, bytes32[] calldata proof, uint256 amount) internal returns (bool)
    {
        require(!checkClaimed(account), "Already claimed");

        bytes32 leaf = keccak256(abi.encodePacked(account, amount));
        require(MerkleProof.verify(proof, _merkleRoot, leaf), "Proof failed");

        _claims[account] = true;
        
        return true;
    }
}