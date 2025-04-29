// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importing required interfaces from Sunswap interface
interface ISunSwapRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

// Ownable contract logic
contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

// ReentrancyGuard to prevent reentrancy attacks
contract ReentrancyGuard {
    bool private _entered;

    modifier nonReentrant() {
        require(!_entered, "ReentrancyGuard: reentrant call");
        _entered = true;
        _;
        _entered = false;
    }
}

contract TRC20TokenWithSunSwap is Ownable, ReentrancyGuard {
    string public name = "SunSwap Token";
    string public symbol = "SST";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    address public sunSwapRouter;
    uint256 public mintExpirationTime;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Constructor to mint initial tokens and set the SunSwap Router address
    constructor(uint256 _initialSupply, address _sunSwapRouter) {
        totalSupply = _initialSupply * 10 ** uint256(decimals);
        balanceOf[msg.sender] = totalSupply;
        sunSwapRouter = _sunSwapRouter;
        mintExpirationTime = block.timestamp + 90 days; // Set 90 days expiration
    }

    // ERC-20 Standard Functions
    function transfer(address recipient, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }

    // TransferFrom function implementation
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        require(balanceOf[sender] >= amount, "Insufficient balance");
        require(allowance[sender][msg.sender] >= amount, "Allowance exceeded");

        // Deduct the amount from the sender's balance
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;

        // Decrease the allowance
        allowance[sender][msg.sender] -= amount;

        return true;
    }

    // Function to mint new tokens
    function mint(address recipient, uint256 amount) external onlyOwner {
        require(block.timestamp < mintExpirationTime, "Minting has expired");

        totalSupply += amount;
        balanceOf[recipient] += amount;
    }

    // Function to swap TRC20 tokens via SunSwap Router
    function swapTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path
    ) external nonReentrant {
        require(balanceOf[msg.sender] >= amountIn, "Insufficient balance");

        // Call the SunSwap router to swap tokens
        ISunSwapRouter(sunSwapRouter).swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            msg.sender,
            block.timestamp
        );

        // Adjust balance of the sender
        balanceOf[msg.sender] -= amountIn;
    }

    // Function to add liquidity to SunSwap pools (TRC20 <=> TRC20)
    function addLiquidity(
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant {
        require(balanceOf[msg.sender] >= amountADesired, "Insufficient balance");

        // Call SunSwap router to add liquidity
        ISunSwapRouter(sunSwapRouter).addLiquidity(
            address(this),  // Token A (this token)
            tokenB,         // Token B (other TRC20 token)
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            msg.sender,
            block.timestamp
        );

        // Adjust balance of the sender
        balanceOf[msg.sender] -= amountADesired;
    }

    // Function to remove liquidity from SunSwap pools (TRC20 <=> TRC20)
    function removeLiquidity(
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant {
        require(balanceOf[msg.sender] >= liquidity, "Insufficient balance");

        // Transfer the liquidity tokens to the contract (this contract needs to hold LP tokens)
        IERC20(sunSwapRouter).transferFrom(msg.sender, address(this), liquidity);

        // Call SunSwap router to remove liquidity
        (uint256 amountA, uint256 amountB) = ISunSwapRouter(sunSwapRouter).removeLiquidity(
            address(this),  // Token A (this token)
            tokenB,         // Token B (other TRC20 token)
            liquidity,
            amountAMin,
            amountBMin,
            msg.sender,
            block.timestamp
        );

        // Adjust balance of the sender
        balanceOf[msg.sender] += amountA + amountB;
    }
}
