// SPDX-License-Identifier: MIT

pragma solidity 0.8.14;

import "./PicniqTokenClaim.sol";
import "./interfaces/IERC2612Permit.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC777/ERC777.sol";

// solhint-disable no-inline-assembly, not-rely-on-time 
contract PicniqToken is PicniqTokenClaim, ERC777, IERC2612Permit {
    using Counters for Counters.Counter;

    mapping(address => Counters.Counter) private _nonces;

    // Mapping of ChainID to domain separators. This is a very gas efficient way
    // to not recalculate the domain separator on every call, while still
    // automatically detecting ChainID changes.
    mapping(uint256 => bytes32) public domainSeparators;

    mapping (address => UserVest) private _vesting;
    uint256 private _totalVested;
    ClaimDecay private _decayData;
    
    struct ClaimDecay {
        uint64 decayTime;
        uint64 decayRate;
    }

    struct UserVest {
        uint8 length;
        uint64 endTime;
        uint256 amount;
    }

    constructor(uint256 initialSupply, address treasury, address team, address[] memory defaultOperators, bytes32 merkleRoot_)
        PicniqTokenClaim(merkleRoot_)
        ERC777("Picniq Finance", "SNACK", defaultOperators)
    {
        _updateDomainSeparator();

        uint256 teamAmount = initialSupply * 15 / 100;
        uint256 treasuryAmount = initialSupply * 35 / 100;

        _mint(team, teamAmount, "", "");
        _mint(treasury, treasuryAmount, "", "");
        _mint(address(this), initialSupply - treasuryAmount - teamAmount, "", "");

        _decayData.decayTime = uint64(block.timestamp * (2628000 * 6));
        _decayData.decayRate = 5e15;
    }

    function totalVested() external view returns (uint256)
    {
        return _totalVested;
    }

    function vestedOfDetails(address account) external view returns (UserVest memory)
    {
        return _vesting[account];
    }

    function vestedOf(address account) public view returns (uint256)
    {
        UserVest memory userVest = _vesting[account];

        if (userVest.endTime > block.timestamp) {
            return userVest.amount;    
        } else {
            uint256 percent = block.timestamp * 1e18 / userVest.endTime;
            return userVest.amount * percent / 1e18;
        }
    }

    function unvest() external
    {
        uint256 vested = vestedOf(msg.sender);
        _vesting[msg.sender].amount -= vested;
        _send(address(this), msg.sender, vested, "", "", false);
        _totalVested -= vested;
    }

    function claimTokens(bytes32[] calldata proof, uint256 amount) external
    {
        require(checkProof(msg.sender, proof, amount), "Proof failed");
        uint256 decay = 1e18;
        if (block.timestamp > _decayData.decayTime) {
            decay -= ((block.timestamp - _decayData.decayTime) / 86400) * _decayData.decayRate;
        }
        _send(address(this), msg.sender, amount * 20 * decay / 1e18, "", "", false);
    }

    function claimAndVest(bytes32[] calldata proof, uint256 amount, uint8 length) external
    {
        require(length == 6 || length == 12, "Length must be 6 or 12 months");
        require(checkProof(msg.sender, proof, amount), "Proof failed");

        uint256 decay = 1e18;
        if (block.timestamp > _decayData.decayTime) {
            decay -= ((block.timestamp - _decayData.decayTime) / 86400) * _decayData.decayRate;
        }

        uint256 bonus = length == 6 ? 15 : 35;
        uint256 total = (amount * 20 * decay / 1e18) * bonus;
        uint256 vested = total / 2;

        _vesting[msg.sender] = UserVest({
            length: length,
            endTime: uint64(block.timestamp) * length,
            amount: vested
        });

        _send(address(this), msg.sender, total - vested, "", "", false);
        _totalVested += vested;
    }

    /**
     * @dev See {IERC2612Permit-permit}.
     *
     * If https://eips.ethereum.org/EIPS/eip-1344[ChainID] ever changes, the
     * EIP712 Domain Separator is automatically recalculated.
     */
    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override {
        require(block.timestamp <= deadline, "ERC20Permit: expired deadline");

        bytes32 hashStruct;
        uint256 nonce = _nonces[owner].current();

        assembly {
            // Load free memory pointer
            let memPtr := mload(64)
            mstore(memPtr, 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9)
            mstore(add(memPtr, 32), owner)
            mstore(add(memPtr, 64), spender)
            mstore(add(memPtr, 96), amount)
            mstore(add(memPtr, 128), nonce)
            mstore(add(memPtr, 160), deadline)

            hashStruct := keccak256(memPtr, 192)
        }

        bytes32 eip712DomainHash = _domainSeparator();
        bytes32 hash;

        assembly {
            // Load free memory pointer
            let memPtr := mload(64)

            mstore(memPtr, 0x1901000000000000000000000000000000000000000000000000000000000000)  // EIP191 header
            mstore(add(memPtr, 2), eip712DomainHash)                                            // EIP712 domain hash
            mstore(add(memPtr, 34), hashStruct)                                                 // Hash of struct

            hash := keccak256(memPtr, 66)
        }

        address signer = _recover(hash, v, r, s);

        require(signer == owner, "ERC20Permit: invalid signature");

        _nonces[owner].increment();
        _approve(owner, spender, amount);
    }

    /**
     * @dev See {IERC2612Permit-nonces}.
     */
    function nonces(address owner) public override view returns (uint256) {
        return _nonces[owner].current();
    }

    function _updateDomainSeparator() private returns (bytes32) {
        uint256 chainID = _chainID();

        // no need for assembly, running very rarely
        bytes32 newDomainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name())), // ERC-20 Name
                keccak256(bytes("1")),    // Version
                chainID,
                address(this)
            )
        );

        domainSeparators[chainID] = newDomainSeparator;

        return newDomainSeparator;
    }

    // Returns the domain separator, updating it if chainID changes
    function _domainSeparator() private returns (bytes32) {
        bytes32 domainSeparator = domainSeparators[_chainID()];

        if (domainSeparator != 0x00) {
            return domainSeparator;
        }

        return _updateDomainSeparator();
    }

    function _chainID() private view returns (uint256) {
        uint256 chainID;
        assembly {
            chainID := chainid()
        }

        return chainID;
    }

    function _recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (281): 0 < s < secp256k1n ÷ 2 + 1, and for v in (282): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (
            uint256(s) >
            0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
        ) {
            revert("ECDSA: invalid sig 's' value");
        }

        if (v != 27 && v != 28) {
            revert("ECDSA: invalid sig 'v' value");
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0), "ECDSA: invalid signature");

        return signer;
    }
}