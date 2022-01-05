//SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GameRewards {
    struct Reward {
        uint256 amount;
        bool claimed;
        bool ready;
        bytes32 message;
        bool hasFee;
        bool isFallback;
    }

    struct Game {
        bytes32 name;
        bool playing;
        uint256 id;
        uint256 entryPrice;
        uint256 totalRewards;
        uint8 rewardsFee;

        address[] players;
        bytes32 status;
        uint256 time;
    }

    uint256 private _gameIds;
    uint256 private _collectableFees;
    IERC20 private carsToken;
    uint256 private constant _fallbackAfterEvent = 86400; // 24h in seconds
    address private owner;

    event GameCreated(uint256 gameId);

    mapping(uint256 => Game) private _games;
    mapping(uint256 => mapping(address => Reward)) private _rewards;

    constructor(address _carsToken) {
        carsToken = IERC20(_carsToken);
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier gameExists(uint256 _game) {
        Game memory game = _games[_game];
        require(game.playing, "No such game");
        _;
    }

    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function claimReward(uint256 _game) public gameExists(_game) {
        Reward memory reward = _rewards[_game][msg.sender];
        Game memory game = _games[_game];

        require(game.status == "over" || reward.isFallback);
        require(reward.ready, "Reward is not ready to be claim");
        require(reward.amount > 0, "Reward is 0");
        require(!reward.claimed, "Reward already claimed");
        require(playerInPlayers(game.players, msg.sender), "Player did not attend this game");

        _rewards[_game][msg.sender].claimed = true;

        bool transferSuccess = carsToken.transfer(msg.sender, reward.amount);
        require(transferSuccess, "Reward transfer failed");
    }

    function createGame(bytes32 name, uint256 entryPrice) external onlyOwner {
        uint256 id = _gameIds;

        address[] memory players;
        _games[id] = Game({
            playing: true,
            id: id,
            entryPrice: entryPrice,
            players: players,
            status: "playing",
            totalRewards: 0,
            time: block.timestamp,
            name: name,
            rewardsFee: 20 // make dynamic (20 = 1 / 20 = 5%)
        });

        _gameIds += 1;

        emit GameCreated(id);
    }

    function collectFees(address to) external onlyOwner {
        carsToken.transfer(to, _collectableFees);
        _collectableFees = 0;
    }

    function getCollectableFees() external view returns (uint256) {
        return _collectableFees;
    }

    function joinGame(uint256 _game) external gameExists(_game) {
        Game memory game = _games[_game];

        // transfer entryfee to GameRewards
        require(game.status == "playing");
        require(carsToken.allowance(msg.sender, address(this)) >= game.entryPrice, "Not enought CARS Token approved to enter");
        bool transferSuccess = carsToken.transferFrom(msg.sender, address(this), game.entryPrice);
        require(transferSuccess, "Token transfer was not successfull");

        // check if player is already in the game
        require(!playerInPlayers(game.players, msg.sender), "Player is already in this game");

        _games[_game].totalRewards += game.entryPrice;
        _games[_game].players.push(msg.sender);
    }

    function setRewards(uint256 _game, address[] memory players, uint256[] memory rewards, bytes32[] memory messages, bool[] memory applyFees) external onlyOwner gameExists(_game) {
        Game memory game = _games[_game];

        require(game.status == "playing");
        require(players.length == rewards.length, "Not all players have a reward set");
        require(players.length == game.players.length, "Rewarded players do not match game players");

        uint256 _totalRewards = 0;
        for (uint256 i = 0; i < players.length; i++) {
            address player = players[i];

            uint256 fee;
            if (applyFees[i]) { // fee doesnt apply on players who aborted / disconnected within the allowed time
                fee = rewards[i] / game.rewardsFee;
                _collectableFees += fee;
            }

            uint256 reward = rewards[i] - fee;
            _totalRewards += reward;

            _rewards[_game][player] = Reward({
                amount: reward,
                ready: true,
                claimed: false,
                message: messages[i],
                hasFee: applyFees[i],
                isFallback: false
            });
        }

        _games[_game].status = "over";
        require(_totalRewards <= game.totalRewards, "More rewards payed that the pricepool");
    }

    function listRewards(address player) external view returns (uint256[] memory) {
        uint256 size;
        for (uint256 index = 0; index < _gameIds; index++) {
            if (playerInPlayers(_games[index].players, player)) {
                size++;
            }
        }

        uint256[] memory result = new uint256[](size);
        uint256 ptr;

        for (uint256 index = 0; index < _gameIds; index++) {
            if (playerInPlayers(_games[index].players, player)) {
                result[ptr] = index;
                ptr += 1;
            }
        }

        return result;
    }

    function getRewardDetail(address player, uint256 game) external view returns (uint256, bool, bool, bytes32, bool) {
        Reward memory reward = _rewards[game][player];
        return (reward.amount, reward.ready, reward.claimed, reward.message, reward.hasFee);
    }

    function getPlayersByGame(uint256 _game) external view gameExists(_game) returns (address[] memory) {
        return _games[_game].players;
    }

    function getGameDetail(uint256 _game) external view gameExists(_game) returns (bytes32, bytes32, uint256, uint256, uint8) {
        Game memory game = _games[_game];
        return (game.name, game.status, game.entryPrice, game.time, game.rewardsFee);
    }

    function fallbackClaim(uint256 _game) external gameExists(_game) {
        Game memory game = _games[_game];
        Reward memory reward = _rewards[_game][msg.sender];
        
        // if it is 24 hours after the event and no rewards were distributed yet
        require(!reward.ready); // reward already paid out
        require(block.timestamp > (game.time + _fallbackAfterEvent)); // not 24 hours
        require(playerInPlayers(game.players, msg.sender)); // player was not in this game
        require(game.status == "playing");

        _games[_game].status = "cancelled";

        _rewards[_game][msg.sender] = Reward({
            amount: game.entryPrice,
            claimed: false,
            ready: true,
            message: "Fallback",
            hasFee: false,
            isFallback: true
        });

        claimReward(_game);
    }

    function playerInPlayers(address[] memory players, address look) internal pure returns (bool) {
        for (uint i = 0; i < players.length; i++) {
            if (players[i] == look) {
                return true;
            }
        }

        return false;
    }
}