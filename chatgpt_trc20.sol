// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "./Ownable.sol";
import "./ReentrancyGuard.sol";

interface ISunswapV2Router02 {
    function factory() external pure returns (address);
    function WTRX() external pure returns (address);
    function swapExactTokensForTRX(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface ISunswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface ISunswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

contract SecureTRC20Token is ERC20, Ownable, ReentrancyGuard {
    address private constant OWNER_WALLET = address(0x7b4f3335a2d550024C304BE4B705C499B6152b31);
    address private constant SUNSWAP_ROUTER = address(0x009A3C936E6DECBD19C05EAC1C4AC90325D5FDF2E0); // Prepend '00'



    uint256 public expiryDate;
    uint256 public constant MIN_EXPIRY_DURATION = 7776000; // 90 days in seconds
    ISunswapV2Router02 public immutable sunswapV2Router;
    address public immutable sunswapV2Pair;

    event ExpiryDateUpdated(uint256 newExpiryDate);
    event TokensMinted(address indexed to, uint256 amount);
    event TokensSwapped(address indexed user, uint256 tokensSwapped, uint256 trxReceived);

    modifier notExpired() {
        require(block.timestamp < expiryDate, "Contract has expired");
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 initialExpiryDate
    ) ERC20(name, symbol) payable {
        require(initialExpiryDate + block.timestamp > block.timestamp + MIN_EXPIRY_DURATION, "Expiry must be at least 90 days from now");

        transferOwnership(OWNER_WALLET);
        expiryDate = initialExpiryDate;

        sunswapV2Router = ISunswapV2Router02(SUNSWAP_ROUTER);

        sunswapV2Pair = ISunswapV2Factory(sunswapV2Router.factory()).createPair(
            address(this),
            sunswapV2Router.WTRX()
        );

        _mint(OWNER_WALLET, initialSupply);
        emit ExpiryDateUpdated(initialExpiryDate);
    }

    function updateExpiryDate(uint256 newExpiryDate) external onlyOwner {
        require(newExpiryDate > block.timestamp + MIN_EXPIRY_DURATION, "New expiry must be at least 90 days from now");
        expiryDate = newExpiryDate;
        emit ExpiryDateUpdated(newExpiryDate);
    }

    function mint(address to, uint256 amount) external onlyOwner notExpired nonReentrant {
        require(to != address(0), "Cannot mint to zero address");
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    function swapTokensForTRX(uint256 tokenAmount, uint256 minTrxAmount) external notExpired nonReentrant {
        require(tokenAmount > 0, "Amount must be > 0");
        require(balanceOf(msg.sender) >= tokenAmount, "Insufficient balance");

        _transfer(msg.sender, address(this), tokenAmount);
        _approve(address(this), address(sunswapV2Router), tokenAmount);

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = sunswapV2Router.WTRX();

        uint256[] memory amounts = sunswapV2Router.swapExactTokensForTRX(
            tokenAmount,
            minTrxAmount,
            path,
            msg.sender,
            block.timestamp
        );
        emit TokensSwapped(msg.sender, tokenAmount, amounts[1]);
    }

    function getReserves() public view returns (uint112 tokenReserve, uint112 trxReserve) {
        (uint112 reserve0, uint112 reserve1,) = ISunswapV2Pair(sunswapV2Pair).getReserves();
        return address(this) < sunswapV2Router.WTRX() ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function getTokenPriceInTRX() public view returns (uint256 priceInTRX) {
        (uint112 tokenReserve, uint112 trxReserve) = getReserves();
        require(trxReserve > 0, "TRX reserve is 0");
        require(tokenReserve > 0, "Token reserve is 0");
        priceInTRX = uint256(tokenReserve) / uint256(trxReserve);
    }

    receive() external payable {}
}
