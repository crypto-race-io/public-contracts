//SPDX-License-Identifier: MIT

pragma solidity >= 0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CarAsset is Ownable, ERC721 {
    struct Car {
        uint256 id;
        string name;
        uint8 itemType;
        bool minted;
        uint256 mintPrice;
        string image;
    }

    struct Trade {
        uint256 id;
        address poster;
        address buyer;
        uint256 item;
        uint256 price;
        bytes32 status; // Open, Executed, Cancelled
        bool payWithCars;
    }

    event TradeExecuted(uint256 trade, uint256 item, uint256 timestamp);
    event TradeOpened(uint256 trade);

    IERC20 private carsToken;
    uint256 private tradeCounter;
    uint256 private itemIds = 1; // start at 0 to prevent the check the id against 0
    uint256 private constant feeDenominator = 20; // (1 / 20) => 5% fees

    mapping(uint256 => Car) public cars;
    mapping(uint256 => Trade) private _tradesByTradeId;
    mapping(uint256 => Trade) private _tradesByItemId;
    mapping(uint256 => bool) private _tradesLocked;

    constructor(address _carsToken) ERC721("CRR Car Asset", "CRRCarAsset") {
        carsToken = IERC20(_carsToken);
        tradeCounter = 0;
    }

    modifier canExecuteTrade(uint256 _trade) {
        require(!_tradesLocked[_trade]);
        
        Trade memory trade = _tradesByTradeId[_trade];
        require(trade.status == "Open");
        require(ownerOf(trade.item) == trade.poster);

        // only for security to prevent any sneaky edit => should never actually trigger
        require(getApproved(trade.item) == address(this));
        _;
    }

    // mints an item
    function mintItem(uint item) external payable {
        Car memory car = cars[item];
        require(car.mintPrice != 0);
        require(!car.minted);

        payable(owner()).transfer(car.mintPrice);
        _mint(msg.sender, item);

        cars[item].minted = true;
        cars[item].mintPrice = 0; // does not need to be visible after buying
    }

    // adds an item to the mintung pool
    function addToMint(string memory name, uint8 itemType, uint price, string memory image) public onlyOwner {
        addToMint(name, itemType, price, image, address(0));
    }
    function addToMint(string memory name, uint8 itemType, uint price, string memory image, address to) public onlyOwner {
        uint256 id = itemIds++;

        cars[id] = Car({
            id: id,
            minted: false,
            name: name,
            itemType: itemType,
            mintPrice: price,
            image: image
        });

        if (to != address(0)) {
            _mint(to, id);
            cars[id].minted = true;
        }
    }

    // gets the details of an item by id
    function getItemDetail(uint item) external view returns (string memory, uint8, uint256, bool, string memory) {
        require(item < itemIds);
        
        Car memory car = cars[item];
        return (car.name, car.itemType, car.mintPrice, car.minted, car.image);
    }

    // returns all the itemIds of the items that are currently available for minting
    function getAvailableForMint() external view returns (uint256[] memory) {
        // get the size off all available
        uint256[] memory available = new uint256[](itemIds - 1);
        uint256 size;

        for (uint256 item = 1; item < itemIds; item++) {
            Car memory car = cars[item];
            if (!car.minted) {
                available[size++] = item;
            }
        }

        return slice(available, size);
    }

    // check if an item is listed for sale
    function isApprovedForSale(uint item) external view returns (bool) {
        return getApproved(item) == address(this);
    }

    // get the collection of a user
    function getCollection(address user) external view returns (uint256[] memory) {
        // get the size off all available
        uint256 size;
        uint256[] memory available = new uint256[](itemIds - 1);

        for (uint256 item = 1; item < itemIds; item++) {
            Car memory car = cars[item];
            if (car.minted && ownerOf(item) == user) {
                available[size++] = item;
            }
        }

        return slice(available, size);
    }

    // open a new trade 
    function openTrade(uint256 _item, uint256 _price, bool _useCarsToken) external {
        require(ownerOf(_item) == msg.sender);
        require(getApproved(_item) == address(this));
        require(_tradesByItemId[_item].poster == address(0));

        uint256 id = tradeCounter++;

        Trade memory trade = Trade({
            id: id,
            poster: msg.sender,
            item: _item,
            price: _price,
            status: "Open",
            buyer: address(0),
            payWithCars: _useCarsToken
        });

        // always overwrides when an item is traded multiple times
        _tradesByItemId[_item] = trade;
        _tradesByTradeId[id] = trade;

        emit TradeOpened(id);
    }

    // execure the trade with BNB
    function executeTradeBNB(uint256 _trade) external payable canExecuteTrade(_trade) {
        Trade memory trade = _tradesByTradeId[_trade];
        require(msg.value == trade.price);
        require(!trade.payWithCars);

        _tradesLocked[_trade] = true;
        uint256 fees = SafeMath.div(trade.price, feeDenominator);
        (bool feePaid, ) = payable(owner()).call{ value: fees }("");
        (bool posterPaid, ) = payable(trade.poster).call{ value: trade.price - fees }("");
        _tradesLocked[_trade] = false;

        require(feePaid);
        require(posterPaid);

        _executeTrade(_trade);
    }

    // execute the trade with CRACE
    function executeTradeCARS(uint256 _trade) external canExecuteTrade(_trade) {
        Trade memory trade = _tradesByTradeId[_trade];
        require(trade.payWithCars);
        require(carsToken.allowance(msg.sender, address(this)) >= trade.price);

        _tradesLocked[_trade] = true;
        carsToken.transferFrom(msg.sender, trade.poster, trade.price);
        _tradesLocked[_trade] = false;

        _executeTrade(_trade);
    }

    // cancel the trade
    function cancelTrade(uint256 _trade) external canExecuteTrade(_trade) {
        Trade memory trade = _tradesByTradeId[_trade];
        require(msg.sender == trade.poster);
        require(trade.status == "Open");
        require(ownerOf(trade.item) == msg.sender);

        _tradesByTradeId[_trade].status = "Cancelled";
        delete _tradesByItemId[trade.item];

        // unapprove item
        approve(address(0), trade.item);
    }

    // get details of a trade by id
    function getTrade(uint256 _trade) external view returns(address, uint256, uint256, bytes32, bool) {
        Trade memory trade = _tradesByTradeId[_trade];
        return (trade.poster, trade.item, trade.price, trade.status, trade.payWithCars);
    }

    // returns all id's of the open trades
    function getOpenTrades() external view returns (uint256[] memory) {
        uint256 size;
        uint256[] memory available = new uint256[](tradeCounter);

        for (uint256 id; id < tradeCounter; id++) {
            Trade memory trade = _tradesByTradeId[id];
            if (trade.status == "Open" && getApproved(trade.item) == address(this)) {
                available[size++] = id;
            }
        }

        return slice(available, size);
    }

    function totalSupply() external view returns (uint256) {
        return itemIds;
    }

    // get trade if of by item
    function getTradeIdByItem(uint256 item) external view returns (int) {
        Trade memory trade = _tradesByItemId[item];
        if (trade.poster == address(0)) {
            return -1;
        } else {
            return int(trade.id);
        }
    }

    function slice(uint256[] memory items, uint256 size) internal pure returns (uint256[] memory) {
        uint256[] memory newItems = new uint256[](size);

        for (uint256 index = 0; index < size; index++) {
            newItems[index] = items[index];
        }

        return newItems;
    }

    // internal trade execution => transfer item
    function _executeTrade(uint256 _trade) internal {
        Trade memory trade = _tradesByTradeId[_trade];
        _tradesByTradeId[_trade].status = "Executed";
        _tradesByTradeId[_trade].buyer = msg.sender;

        transferFrom(trade.poster, msg.sender, trade.item);
        delete _tradesByItemId[trade.item];

        emit TradeExecuted(_trade, trade.item, block.timestamp);
    }
}