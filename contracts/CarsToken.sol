//SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/*
10% are distrubuted between all developers and content creators
90% are listed in public token sale
*/
contract CarsToken is ERC20 {
    uint256 private constant maxSupply = 10e24; // 10 million total supply (10e18 is the decimals)

    constructor() ERC20("Crypto Race Token", "CRR") {
        _mint(msg.sender, maxSupply);
    }
}