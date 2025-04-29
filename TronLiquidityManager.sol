// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISunswapV2RouterTRX {
    function addLiquidityTRX(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountTRXMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountTRX, uint liquidity);

    function removeLiquidityTRX(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountTRXMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountTRX);
}

interface ITRC20 {
    function balanceOf(address account) external view returns (uint256);
}

contract TronLiquidityManager {
    address public immutable SUNSWAP_V2_ROUTER; // TY1tqxVDgtnKnQZ7sVoNgXZqsuWjvLWmYN in base58
    
    // Your token address
    address public immutable TOKEN;
    

    ISunswapV2RouterTRX public immutable router;
    ITRC20 public immutable token;
    address public immutable owner;
    
    // Comprehensive Debug Events
    event BalanceCheckAttempted(
        string functionName,
        address tokenAddress,
        address accountAddress
    );
    
    event BalanceCheckResult(
        string functionName,
        uint256 balance,
        bool success
    );
    
    event DebugErrorOccurred(
        string functionName,
        string errorReason
    );

    event Debug_LiquidityAdditionAttempt(
        string context,
        address tokenAddress,
        address routerAddress,
        uint256 tokenAmount,
        uint256 trxAmount
    );

    event Debug_LiquidityAdditionSuccess(
        uint256 amountToken,
        uint256 amountTRX,
        uint256 liquidity
    );

    event Debug_LowLevelError(
        string context,
        bytes errorData
    );

    event Debug_RemoveLiquidityAttempt(
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountTRXMin
    );

    constructor(
        address token_addr,
        address SUNSWAP_V2_ROUTER_TRON
        ) payable {
            
        SUNSWAP_V2_ROUTER = SUNSWAP_V2_ROUTER_TRON;
        router = ISunswapV2RouterTRX(SUNSWAP_V2_ROUTER_TRON);
        TOKEN = token_addr;
        token = ITRC20(token_addr);
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    // Removed view keyword to resolve potential state modification issues
    function getContractTokenBalance() external returns (uint256) {
        emit BalanceCheckAttempted(
            "getContractTokenBalance", 
            TOKEN, 
            address(this)
        );
        
        uint256 balance = 0;
        bool success = false;
        
        (success, ) = address(token).staticcall(
            abi.encodeWithSignature("balanceOf(address)", address(this))
        );
        
        if (success) {
            balance = token.balanceOf(address(this));
            
            emit BalanceCheckResult(
                "getContractTokenBalance", 
                balance, 
                true
            );
            
            return balance;
        } else {
            emit DebugErrorOccurred(
                "getContractTokenBalance", 
                "Balance check failed"
            );
            
            return 0;
        }
    }
    
    function getTokenBalanceOfOwner() external returns (uint256) {
        emit BalanceCheckAttempted(
            "getTokenBalanceOfOwner", 
            TOKEN, 
            owner
        );
        
        uint256 balance = 0;
        bool success = false;
        
        (success, ) = address(token).staticcall(
            abi.encodeWithSignature("balanceOf(address)", owner)
        );
        
        if (success) {
            balance = token.balanceOf(owner);
            
            emit BalanceCheckResult(
                "getTokenBalanceOfOwner", 
                balance, 
                true
            );
            
            return balance;
        } else {
            emit DebugErrorOccurred(
                "getTokenBalanceOfOwner", 
                "Balance check failed"
            );
            
            return 0;
        }
    }
    
    function getContractTRXBalance() external view returns (uint) {
        return address(this).balance;
    }
    
    function addLiquidity(
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountTRXMin
    ) external payable onlyOwner {
        // Scale token amounts (multiply by 10^6)
        uint scaledTokenDesired = amountTokenDesired * 1_000_000;
        uint scaledTokenMin = amountTokenMin * 1_000_000;
        
        // Add detailed error logging for troubleshooting
        emit Debug_LiquidityAdditionAttempt(
            "Pre-Liquidity Addition Checks",
            TOKEN,
            SUNSWAP_V2_ROUTER,
            scaledTokenDesired,
            msg.value
        );

        uint deadline = block.timestamp + 20 minutes;
        
        try router.addLiquidityTRX{value: msg.value}(
            TOKEN,
            scaledTokenDesired,
            scaledTokenMin,
            amountTRXMin,
            owner,
            deadline
        ) returns (uint amountToken, uint amountTRX, uint liquidity) {
            // Successful liquidity addition
            emit Debug_LiquidityAdditionSuccess(
                amountToken, 
                amountTRX, 
                liquidity
            );
        } catch Error(string memory reason) {
            // Catch and log specific error messages
            emit DebugErrorOccurred(
                "Liquidity Addition Failure", 
                reason
            );
            revert(reason);
        } catch (bytes memory lowLevelData) {
            // Catch low-level errors
            emit Debug_LowLevelError(
                "Liquidity Addition Low-Level Error",
                lowLevelData
            );
            revert("Liquidity addition failed");
        }
    }
    
    function removeLiquidity(
        uint liquidity,
        uint amountTokenMin,
        uint amountTRXMin
    ) external onlyOwner {
        // Emit debug event for removal attempt
        emit Debug_RemoveLiquidityAttempt(
            liquidity,
            amountTokenMin,
            amountTRXMin
        );

        // Scale token min amount (multiply by 10^6)
        uint scaledTokenMin = amountTokenMin * 1_000_000;
        
        uint deadline = block.timestamp + 20 minutes;
        
        try router.removeLiquidityTRX(
            TOKEN,
            liquidity,
            scaledTokenMin,
            amountTRXMin,
            owner,
            deadline
        ) returns (uint amountToken, uint amountTRX) {
            // Optionally log successful removal
        } catch Error(string memory reason) {
            // Catch and log specific error messages
            emit DebugErrorOccurred(
                "Liquidity Removal Failure", 
                reason
            );
            revert(reason);
        } catch (bytes memory lowLevelData) {
            // Catch low-level errors
            emit Debug_LowLevelError(
                "Liquidity Removal Low-Level Error",
                lowLevelData
            );
            revert("Liquidity removal failed");
        }
    }
    
    // Fallback function to receive TRX
    receive() external payable {}
}