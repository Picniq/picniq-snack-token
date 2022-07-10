// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./PicniqTokenClaim.sol";
import "./utils/ERC20Permit.sol";

// solhint-disable no-inline-assembly, not-rely-on-time 
contract PicniqToken is PicniqTokenClaim, ERC20Permit {

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
        uint256 withdrawn;
    }

    constructor(uint256 initialSupply, address treasury, address team, bytes32 merkleRoot_)
        PicniqTokenClaim(merkleRoot_)
        ERC20("Picniq Finance", "SNACK")
    {
        uint256 teamAmount = initialSupply * 15 / 100;
        uint256 treasuryAmount = initialSupply * 35 / 100;

        _mint(team, teamAmount);
        _mint(treasury, treasuryAmount);
        _mint(address(this), initialSupply - treasuryAmount - teamAmount);

        _decayData.decayTime = uint64(block.timestamp + (2628000 * 6));
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

        if (userVest.endTime <= block.timestamp) {
            return userVest.amount - userVest.withdrawn;    
        } else {
            uint256 percent = block.timestamp * 1e18 / userVest.endTime;
            return userVest.amount - (userVest.amount * percent / 1e18) - userVest.withdrawn;
        }
    }

    function unvest() external
    {
        uint256 vested = vestedOf(msg.sender);
        require(vested > 0, "No tokens to unvest");
        _vesting[msg.sender].withdrawn += vested;
        _totalVested -= vested;
        transfer(msg.sender, vested);
    }

    function claimTokens(bytes32[] calldata proof, uint256 amount) external
    {
        require(checkProof(msg.sender, proof, amount), "Proof failed");

        uint256 decay = 1e18;
        if (block.timestamp > _decayData.decayTime) {
            uint256 delta = block.timestamp - _decayData.decayTime;
            if (delta > 86400) {
                uint256 newRate = (delta / 86400) * 1e18 / _decayData.decayRate;
                if (newRate > (1e18 / 2)) {
                    decay = newRate;
                } else {
                    decay = 1e18 / 2;
                }
            }
        }

        transfer(msg.sender, amount * 10 * decay / 1e18);
    }

    function claimAndVest(bytes32[] calldata proof, uint256 amount, uint8 length) external
    {
        require(length == 6 || length == 12, "Length must be 6 or 12 months");
        require(checkProof(msg.sender, proof, amount), "Proof failed");

        uint256 decay = 1e18;
        if (block.timestamp > _decayData.decayTime) {
            uint256 delta = block.timestamp - _decayData.decayTime;
            if (delta > 86400) {
                uint256 newRate = (delta / 86400) * 1e18 / _decayData.decayRate;
                if (newRate > (1e18 / 2)) {
                    decay = newRate;
                } else {
                    decay = 1e18 / 2;
                }
            }
        }

        uint256 bonus = length == 6 ? 1.10e18 : 1.25e18;
        uint256 total = (amount * 10 * decay / 1e18) * bonus / 1e18;
        uint256 vested = total / 2;

        _vesting[msg.sender] = UserVest({
            length: length,
            endTime: uint64(block.timestamp) + (2628000 * length),
            amount: vested,
            withdrawn: 0
        });

        _totalVested += vested;

        transfer(msg.sender, total - vested);
    }
}