// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Legacy6Swap is Ownable, ReentrancyGuard {
    address public legacy6Token;
    address public stablecoin;
    address public uniswapRouter;

    event SwapExecuted(address indexed user, uint256 l6cAmount, uint256 stablecoinReceived);

    constructor(
        address _legacy6Token,
        address _stablecoin,
        address _uniswapRouter,
        address initialOwner
    ) Ownable(initialOwner) {
        legacy6Token = _legacy6Token;
        stablecoin = _stablecoin;
        uniswapRouter = _uniswapRouter;
    }

    function swapLegacy6ForStablecoin(uint256 amountIn, uint256 minAmountOut) external nonReentrant {
        require(amountIn > 0, "Amount must be > 0");
        require(IERC20(legacy6Token).transferFrom(msg.sender, address(this), amountIn), "Transfer failed");

        IERC20(legacy6Token).approve(uniswapRouter, amountIn);

        address[] memory path = new address[](2);
        path[0] = legacy6Token;
        path[1] = stablecoin;

        uint256 deadline = block.timestamp + 300;

        uint[] memory amounts = IUniswapV2Router02(uniswapRouter).swapExactTokensForTokens(
            amountIn,
            minAmountOut,
            path,
            msg.sender,
            deadline
        );

        emit SwapExecuted(msg.sender, amountIn, amounts[1]);
    }

    function updateRouter(address _newRouter) external onlyOwner {
        uniswapRouter = _newRouter;
    }

    function updateStablecoin(address _newStablecoin) external onlyOwner {
        stablecoin = _newStablecoin;
    }

    // Emergency token withdrawal by owner
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }
}