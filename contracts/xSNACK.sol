// SPDX-License-Identifier: MIT

pragma solidity 0.8.14;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "./libraries/FixedPointMath.sol";
import "./interfaces/ISingleAssetStake.sol";

// solhint-disable check-send-result
contract AutoCompoundingPicniqToken is ERC777 {
    using FixedPointMath for uint256;

    IERC1820Registry internal constant ERC1820_REGISTRY =
        IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    IERC777 private _asset;
    ISingleAssetStake private _staking;

    constructor(address staking_, address[] memory defaultOperators)
        ERC777 ("Auto Compounding Picniq Token", "xSNACK", defaultOperators) {
            ERC1820_REGISTRY.setInterfaceImplementer(
                address(this),
                keccak256("ERC777TokensRecipient"),
                address(this)
            );
            _staking = ISingleAssetStake(staking_);
            _asset = IERC777(_staking.stakingToken());
    }

    function asset() external view returns (address)
    {
        return address(_asset);
    }

    function totalAssets() public view returns (uint256)
    {
        return _staking.balanceOf(address(this)) + _staking.earned(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256)
    {
        uint256 supply = totalSupply();

        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
    }

    function convertToAssets(uint256 shares) public view returns (uint256)
    {
        uint256 supply = totalSupply();

        return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
    }

    function previewDeposit(uint256 assets) public view returns (uint256)
    {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view returns (uint256)
    {
        uint256 supply = totalSupply();

        return supply == 0 ? shares : shares.mulDivUp(totalAssets(), supply);
    }

    function previewWithdraw(uint256 assets) public view returns (uint256)
    {
        uint256 supply = totalSupply();

        return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
    }

    function previewRedeem(uint256 shares) public view returns (uint256)
    {
        return convertToAssets(shares);
    }

    function maxDeposit(address) external pure returns (uint256)
    {
        return type(uint256).max;
    }

    function maxMint(address) external pure returns (uint256)
    {
        return type(uint256).max;
    }

    function maxWithdrawal(address owner) external view returns (uint256)
    {
        return convertToAssets(balanceOf(owner));
    }

    function maxRedemption(address owner) external view returns (uint256)
    {
        return balanceOf(owner);
    }

    function deposit(uint256 assets, address receiver) public returns (uint256)
    {
        _staking.getReward();
        uint256 shares = previewDeposit(assets);
        
        require(shares != 0, "Zero shares");
        
        uint256 balance = _asset.balanceOf(address(this));
        bytes memory data = abi.encodePacked(uint256(2));

        _asset.send(address(_staking), balance, data);

        _mint(receiver, shares, "", "", false);

        emit Deposit(msg.sender, receiver, assets, shares);

        return shares;
    }

    function withdraw(uint256 assets, address receiver, address owner) external runHarvest returns (uint256)
    {
        uint256 shares = previewWithdraw(assets);

        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);
            if (allowed != type(uint256).max) {
                _spendAllowance(owner, msg.sender, shares);
            }
        }

        _burn(owner, shares, "", "");

        _staking.withdraw(assets);
        _asset.send(receiver, assets, "");

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) external runHarvest returns (uint256)
    {
        uint256 assets = previewRedeem(shares);

        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);
            if (allowed != type(uint256).max) {
                _spendAllowance(owner, msg.sender, assets);
            }
        }

        require(assets != 0, "No assets");

        _burn(owner, shares, "", "");

        _staking.withdraw(assets);
        _asset.send(receiver, assets, "");

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        return assets;
    }

    function mint(uint256 shares, address receiver) public runHarvest returns (uint256)
    {
        uint256 assets = previewMint(shares);
        
        IERC20(address(_asset)).transferFrom(msg.sender, address(this), assets);

        emit Deposit(msg.sender, receiver, assets, shares);

        return assets;
    }

    function tokensReceived(
        address,
        address from,
        address,
        uint256 amount,
        bytes calldata,
        bytes calldata
    ) external {
        _tokensReceived(IERC777(msg.sender), from, amount);
    }

    function _tokensReceived(
        IERC777 token,
        address from,
        uint256 amount
    ) private {
        require(token == _asset, "Wrong token sent");
        require(amount > 0, "Must be greater than 0");

        if (from != address(_staking)) {
            deposit(amount, from);
        }
    }

    function harvest() external
    {
        _staking.getReward();
        bytes memory data = abi.encodePacked(uint256(2));
        uint256 balance = _asset.balanceOf(address(this));
        _asset.send(address(_staking), balance, data);
    }

    modifier runHarvest()
    {
        _staking.getReward();
        _;
        bytes memory data = abi.encodePacked(uint256(2));
        uint256 balance = _asset.balanceOf(address(this));
        if (balance > 0) {
            _asset.send(address(_staking), balance, data);    
        }
        
    }

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);
}