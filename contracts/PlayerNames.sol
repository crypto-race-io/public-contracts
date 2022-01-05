//SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

contract PlayerNames {
    uint8 constant private _minNameLen = 5;

    mapping(address => bytes32) private _nameByAddress;
    mapping(bytes32 => bool) private _nameTaken;

    constructor() {
        _nameByAddress[address(0)] = "dev"; // no need to add it to namesTakes, too short to claim anyway
    }

    function claim(bytes32 name) external {
        bytes32 lower = _toLower(name);
        require(_strLen(name) >= _minNameLen, "Name is too short");
        require(_strLen(name) <= 32, "Name is too long");
        require(_validChars(lower), "Name contains invalid characters");
        require(!_nameTaken[lower], "Name is already taken");

        // release old name if there was one
        if (_nameByAddress[msg.sender] != "") {
            bytes32 oldName = _nameByAddress[msg.sender];
            bytes32 oldLower = _toLower(oldName);
            _nameTaken[oldLower] = false;
        }

        _nameByAddress[msg.sender] = name;
        _nameTaken[lower] = true;
    }

    function available(bytes32 bStr) external view returns (bool) {
        bytes32 lower = _toLower(bStr);
        return _validChars(lower) && !_nameTaken[lower] && _strLen(bStr) >= _minNameLen && _strLen(bStr) <= 32;
    }

    function getNameByAddress(address player) external view returns (bytes32) {
        return _nameByAddress[player];
    }

    function _validChars(bytes32 bStr) internal pure returns (bool) {
        bool hadNull;

        for (uint i = 0; i < bStr.length; i++) {
            uint8 char = uint8(bStr[i]);

            // check null trick
            if (hadNull && char != 0) {
                return false;
            }

            // numeric
            if (char >= 48 && char <= 57) continue;

            // lowercasecase
            if (char >= 97 && char <= 122) continue;

            // underscore
            if (char == 95) continue;

            // empty byte
            if (char == 0) {
                hadNull = true;
                continue;
            }

            return false;
        }

        return true;
    }

    function _toLower(bytes32 name) internal pure returns (bytes32 result) {
        bytes memory bLower = new bytes(name.length);
        for (uint i = 0; i < name.length; i++) {
            if ((uint8(name[i]) >= 65) && (uint8(name[i]) <= 90)) {
                bLower[i] = bytes1(uint8(name[i]) + 32);
            } else {
                bLower[i] = name[i];
            }
        }

        string memory source = string(bLower);
        assembly {
            result := mload(add(source, 32))
        }
    }

    // this is used because bytes32 is always 32 length, this just checks for the null terminator
    function _strLen(bytes32 bStr) internal pure returns (uint8) {
        for (uint8 i = 0; i < bStr.length; i++) {
            uint8 char = uint8(bStr[i]);

            if (char == 0) {
                return i;
            }
        }

        return 32;
    }
}