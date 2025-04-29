// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISunswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address);
}

interface ISunswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface ITRC20 {
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract FlexiblePoolStateChecker {
    address public constant SUNSWAP_V2_ROUTER = address(0x2A6408a27Ba01B0a848Ecdd67C5907DE37B9C882);
    address public constant WTRX = address(0x45b892211d56095d23Fc0aD71de23e30E5Caa50D);
    address public constant SUNSWAP_V2_FACTORY = address(0x6dCbC7B508A3F4DaA58A820C4B10Db3f597A49b);

    event Debug_FindingPair(address tokenAddress);
    event Debug_PairFound(address pair);
    event Debug_CheckingReserves(address pairAddress);
    event Debug_ReservesResult(
        uint112 reserve0, 
        uint112 reserve1, 
        address token0,
        string tokenSymbol,
        uint8 tokenDecimals
    );
    event Debug_TokenAmounts(
        uint tokenAmount, 
        uint trxAmount, 
        string tokenSymbol
    );

    // Check pool state for any token
    function checkPoolState(address tokenAddress) external {
        require(tokenAddress != address(0), "Invalid token address");
        
        // Get token info
        ITRC20 token = ITRC20(tokenAddress);
        string memory tokenSymbol;
        uint8 decimals;
        try token.symbol() returns (string memory symbol) {
            tokenSymbol = symbol;
        } catch {
            tokenSymbol = "UNKNOWN";
        }
        try token.decimals() returns (uint8 dec) {
            decimals = dec;
        } catch {
            decimals = 18;
        }

        // Find pair
        emit Debug_FindingPair(tokenAddress);
        ISunswapV2Factory factory = ISunswapV2Factory(SUNSWAP_V2_FACTORY);
        address pairAddress = factory.getPair(tokenAddress, WTRX);
        emit Debug_PairFound(pairAddress);

        require(pairAddress != address(0), "Pair not found");

        // Get reserves
        ISunswapV2Pair pair = ISunswapV2Pair(pairAddress);
        emit Debug_CheckingReserves(pairAddress);
        
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        address token0 = pair.token0();
        emit Debug_ReservesResult(reserve0, reserve1, token0, tokenSymbol, decimals);

        // Calculate amounts
        uint tokenAmount;
        uint trxAmount;
        if (token0 == tokenAddress) {
            tokenAmount = reserve0;
            trxAmount = reserve1;
        } else {
            tokenAmount = reserve1;
            trxAmount = reserve0;
        }
        emit Debug_TokenAmounts(tokenAmount, trxAmount, tokenSymbol);
    }

    // Check pair address for any token
    function getPairAddress(address tokenAddress) external view returns (address) {
        require(tokenAddress != address(0), "Invalid token address");
        ISunswapV2Factory factory = ISunswapV2Factory(SUNSWAP_V2_FACTORY);
        return factory.getPair(tokenAddress, WTRX);
    }

    // Get reserves for any token-TRX pair
    function getReserves(address tokenAddress) external view returns (
        uint tokenAmount, 
        uint trxAmount,
        string memory tokenSymbol,
        uint8 decimals
    ) {
        require(tokenAddress != address(0), "Invalid token address");

        // Get token info
        ITRC20 token = ITRC20(tokenAddress);
        try token.symbol() returns (string memory symbol) {
            tokenSymbol = symbol;
        } catch {
            tokenSymbol = "UNKNOWN";
        }
        try token.decimals() returns (uint8 dec) {
            decimals = dec;
        } catch {
            decimals = 18;
        }

        // Get pair and reserves
        ISunswapV2Factory factory = ISunswapV2Factory(SUNSWAP_V2_FACTORY);
        address pairAddress = factory.getPair(tokenAddress, WTRX);
        require(pairAddress != address(0), "Pair not found");

        ISunswapV2Pair pair = ISunswapV2Pair(pairAddress);
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        address token0 = pair.token0();

        if (token0 == tokenAddress) {
            tokenAmount = reserve0;
            trxAmount = reserve1;
        } else {
            tokenAmount = reserve1;
            trxAmount = reserve0;
        }
    }

    // Get full token info
    function getTokenInfo(address tokenAddress) external view returns (
        string memory symbol,
        string memory name,
        uint8 decimals
    ) {
        require(tokenAddress != address(0), "Invalid token address");
        ITRC20 token = ITRC20(tokenAddress);
        
        try token.symbol() returns (string memory sym) {
            symbol = sym;
        } catch {
            symbol = "UNKNOWN";
        }
        
        try token.name() returns (string memory n) {
            name = n;
        } catch {
            name = "Unknown Token";
        }
        
        try token.decimals() returns (uint8 dec) {
            decimals = dec;
        } catch {
            decimals = 18;
        }
    }
}