// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pool, IPool} from "../../ERC20Pool.sol";

contract UserWithCollateral {
    function approveAndDepositTokenAsCollateral(
        IERC20 token,
        ERC20Pool pool,
        uint256 amount
    ) public {
        token.approve(address(pool), amount);
        pool.addCollateral(amount);
    }

    function approveToken(
        IERC20 token,
        address spender,
        uint256 amount
    ) public {
        token.approve(spender, amount);
    }

    function addCollateral(ERC20Pool pool, uint256 amount) public {
        pool.addCollateral(amount);
    }

    function borrow(
        ERC20Pool pool,
        uint256 amount,
        uint256 price
    ) public {
        pool.borrow(amount, price);
    }

    function purchaseBid(
        ERC20Pool pool,
        uint256 amount,
        uint256 price
    ) public {
        pool.purchaseBid(amount, price);
    }

    function repay(ERC20Pool pool, uint256 amount) public {
        pool.repay(amount);
    }

    function removeCollateral(ERC20Pool pool, uint256 amount) public {
        pool.removeCollateral(amount);
    }
}

contract UserWithQuoteToken {
    function addQuoteToken(
        ERC20Pool pool,
        uint256 amount,
        uint256 price
    ) public {
        pool.addQuoteToken(amount, price);
    }

    function removeQuoteToken(
        ERC20Pool pool,
        uint256 amount,
        uint256 price
    ) public {
        pool.removeQuoteToken(amount, price);
    }

    function borrow(
        ERC20Pool pool,
        uint256 amount,
        uint256 stopPrice
    ) public {
        pool.borrow(amount, stopPrice);
    }

    function claimCollateral(
        ERC20Pool pool,
        uint256 amount,
        uint256 price
    ) public {
        pool.claimCollateral(amount, price);
    }

    function liquidate(ERC20Pool pool, address borrower) public {
        pool.liquidate(borrower);
    }

    function approveToken(
        IERC20 token,
        address spender,
        uint256 amount
    ) public {
        token.approve(spender, amount);
    }
}