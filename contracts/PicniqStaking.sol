// SPDX-License-Identifier: MIT

pragma solidity 0.8.14;

import "./libraries/Math.sol";
import "@openzeppelin/contracts/interfaces/IERC1820Registry.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";

contract PicniqSingleStake is IERC777Recipient {
    IERC1820Registry internal constant ERC1820_REGISTRY =
        IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    RewardState private _state;

    uint256 private _totalSupply;
    mapping(address => uint256) private _userRewardPerTokenPaid;
    mapping(address => uint256) private _rewards;
    mapping(address => uint256) private _balances;

    struct RewardState {
        uint64 periodFinish;
        uint64 rewardsDuration;
        uint64 lastUpdateTime;
        uint160 token;
        uint160 distributor;
        uint256 rewardRate;
        uint256 rewardPerTokenStored;
    }

    constructor(
        address token,
        address distributor,
        uint64 duration
    ) {
        ERC1820_REGISTRY.setInterfaceImplementer(
            address(this),
            keccak256("ERC777TokensRecipient"),
            address(this)
        );

        _state.rewardsDuration = duration;
        _state.token = uint160(token);
        _state.distributor = uint160(distributor);
    }

    function rewardToken() external view returns (address) {
        return address(_state.token);
    }

    function stakingToken() external view returns (address) {
        return address(_state.token);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, _state.periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        uint256 supply = _totalSupply;

        if (supply == 0) {
            return _state.rewardPerTokenStored;
        }

        return
            _state.rewardPerTokenStored +
            (((lastTimeRewardApplicable() - _state.lastUpdateTime) *
                _state.rewardRate *
                1e18) / supply);
    }

    function earned(address account) public view returns (uint256) {
        return
            (_balances[account] *
                (rewardPerToken() - _userRewardPerTokenPaid[account])) /
            1e18 +
            _rewards[account];
    }

    function getRewardForDuration() external view returns (uint256) {
        return _state.rewardRate * _state.rewardsDuration;
    }

    function tokensReceived(
        address,
        address from,
        address,
        uint256 amount,
        bytes calldata data,
        bytes calldata
    ) external {
        _tokensReceived(IERC777(msg.sender), from, amount, data);
    }

    function _tokensReceived(
        IERC777 token,
        address from,
        uint256 amount,
        bytes calldata data
    ) private {
        require(token == IERC777(address(_state.token)), "Wrong token sent");
        require(amount > 0, "Must be greater than 0");

        bytes32 decode = bytes32(abi.decode(data, (uint256)));
        bytes32 reward = keccak256(abi.encodePacked(uint256(1)));

        if (decode == reward) {
            require(from == address(_state.distributor), "Must be distributor");

            _notifyRewardAmount(amount, address(0));
        } else {
            _updateReward(from);

            _totalSupply += amount;
            _balances[from] += amount;

            emit Staked(from, amount);
        }
    }

    function withdraw(uint256 amount) public payable updateReward(msg.sender) {
        require(amount > 0, "Must be greater than 0");

        _totalSupply -= amount;
        _balances[msg.sender] -= amount;
        IERC777(address(_state.token)).send(msg.sender, amount, "");

        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public payable updateReward(msg.sender) {
        uint256 reward = _rewards[msg.sender];

        if (reward > 0) {
            _rewards[msg.sender] = 0;
            IERC777(address(_state.token)).send(msg.sender, reward, "");

            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external payable {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    function notifyRewardAmount(uint256 reward)
        public
        payable
        onlyDistributor
        updateReward(address(0))
    {
        if (block.timestamp >= _state.periodFinish) {
            _state.rewardRate = reward / _state.rewardsDuration;
        } else {
            uint256 remaining = _state.periodFinish - block.timestamp;
            uint256 leftover = remaining * _state.rewardRate;
            _state.rewardRate =
                (_state.rewardRate + leftover) /
                _state.rewardsDuration;
        }

        uint256 balance = IERC777(address(_state.token)).balanceOf(
            address(this)
        ) - _totalSupply;

        require(
            _state.rewardRate <= balance / _state.rewardsDuration,
            "Reward too high"
        );

        _state.lastUpdateTime = uint64(block.timestamp);
        _state.periodFinish = uint64(block.timestamp + _state.rewardsDuration);

        emit RewardAdded(reward);
    }

    function _notifyRewardAmount(uint256 reward, address account) private {
        _updateReward(account);

        if (block.timestamp >= _state.periodFinish) {
            _state.rewardRate = reward / _state.rewardsDuration;
        } else {
            uint256 remaining = _state.periodFinish - block.timestamp;
            uint256 leftover = remaining * _state.rewardRate;
            _state.rewardRate =
                (_state.rewardRate + leftover) /
                _state.rewardsDuration;
        }

        uint256 balance = IERC777(address(_state.token)).balanceOf(
            address(this)
        ) - _totalSupply;

        require(
            _state.rewardRate <= balance / _state.rewardsDuration,
            "Reward too high"
        );

        _state.lastUpdateTime = uint64(block.timestamp);
        _state.periodFinish = uint64(block.timestamp + _state.rewardsDuration);

        emit RewardAdded(reward);
    }

    function _updateReward(address account) private {
        _state.rewardPerTokenStored = rewardPerToken();
        _state.lastUpdateTime = uint64(lastTimeRewardApplicable());

        if (account != address(0)) {
            _rewards[account] = earned(account);
            _userRewardPerTokenPaid[account] = _state.rewardPerTokenStored;
        }
    }

    function withdrawRewardTokens() external onlyDistributor
    {
        require(block.timestamp > _state.periodFinish, "Rewards still active");

        IERC777 token = IERC777(address(_state.token));
        uint256 supply = _totalSupply;
        uint256 balance = token.balanceOf(address(this));

        token.send(address(_state.distributor), balance - supply, "");
        
        _notifyRewardAmount(0, address(0));
    }

    modifier updateReward(address account) {
        _updateReward(account);
        _;
    }

    modifier onlyDistributor() {
        require(
            msg.sender == address(_state.distributor),
            "Must be distributor"
        );
        _;
    }

    /* === EVENTS === */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
}
