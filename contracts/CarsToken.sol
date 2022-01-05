pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CarsToken is ERC20 {
    uint256 private constant maxSupply = 10e24; // 10 million total supply (10e18 is the decimals)

    constructor() ERC20("Crypto Race Token", "CRR") {
        _mint(msg.sender, maxSupply);
    }
}