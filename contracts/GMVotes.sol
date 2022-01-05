pragma solidity >= 0.8.10;

contract GMVotes {
    event PollStarted(uint256 id);

    struct Poll {
        uint256 end;
        uint256 id;
        bool active;
        address[] voters;
        bytes32[] votes;
    }

    address private owner;
    uint256 private pollId;
    mapping(uint256 => Poll) private _polls;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    function addPoll(uint256 time) external onlyOwner {
        uint256 id = pollId++;

        address[] memory voters;
        bytes32[] memory votes;

        _polls[id] = Poll({
            id: id,
            end: block.timestamp + time,
            active: true,
            voters: voters,
            votes: votes
        });

        emit PollStarted(id);
    }

    function vote(uint256 _poll, bytes32 _vote) external {
        Poll memory poll = _polls[_poll];

        require(poll.active, "poll is not active");
        require(block.timestamp < poll.end, "Poll has already ended");

        bool _hasVoted = hasVoted(_poll, msg.sender);
        require(!_hasVoted, "user has already voted");

        _polls[_poll].voters.push(msg.sender);
        _polls[_poll].votes.push(_vote);
    }

    function hasVoted(uint256 _poll, address user) public view returns (bool) {
        Poll memory poll = _polls[_poll];
        
        for (uint256 index; index < poll.voters.length; index++) {
            address voter = poll.voters[index];
            if (voter == user) {
                return true;
            }
        }

        return false;
    }

    function getResults(uint256 _poll) external view returns (bytes32[] memory, uint256) {
        Poll memory poll = _polls[_poll];
        return (poll.votes, poll.end);
    }

    function getOpenPolls() external view returns (uint256[] memory) {
        uint256 size;
        uint256[] memory polls = new uint256[](pollId);

        for (uint256 index; index < pollId; index++) {
            Poll memory poll = _polls[index];
            if (poll.active && block.timestamp < poll.end) {
                polls[size++] = index;
            }
        }

        uint256[] memory available = new uint256[](size);
        for (uint256 index; index < size; index++) {
            available[index] = polls[index];
        }

        return available;
    }
}