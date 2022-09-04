// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.14;

import { ERC721Pool }        from "../../erc721/ERC721Pool.sol";
import { ERC721PoolFactory } from "../../erc721/ERC721PoolFactory.sol";

import { IERC721Pool } from "../../erc721/interfaces/IERC721Pool.sol";
import { IScaledPool } from "../../base/interfaces/IScaledPool.sol";

import { BucketMath } from "../../libraries/BucketMath.sol";
import { Maths }      from "../../libraries/Maths.sol";

import { ERC721HelperContract } from "./ERC721DSTestPlus.sol";

// TODO: pass different pool type to enable collection + subset test simplification
contract ERC721ScaledCollateralTest is ERC721HelperContract {

    address internal _borrower;
    address internal _borrower2;
    address internal _lender;
    address internal _lender2;

    function setUp() external {
        _borrower  = makeAddr("borrower");
        _borrower2 = makeAddr("borrower2");
        _lender    = makeAddr("lender");
        _lender2   = makeAddr("lender2");

        // deploy collection pool
        _collectionPool = _deployCollectionPool();

        // deploy subset pool
        uint256[] memory subsetTokenIds = new uint256[](5);
        subsetTokenIds[0] = 1;
        subsetTokenIds[1] = 3;
        subsetTokenIds[2] = 5;
        subsetTokenIds[3] = 51;
        subsetTokenIds[4] = 53;
        _subsetPool = _deploySubsetPool(subsetTokenIds);

        address[] memory _poolAddresses = _getPoolAddresses();

        _mintAndApproveQuoteTokens(_poolAddresses, _lender, 200_000 * 1e18);

        _mintAndApproveCollateralTokens(_poolAddresses, _borrower,  52);
        _mintAndApproveCollateralTokens(_poolAddresses, _borrower2, 53);
    }

    /*******************************/
    /*** ERC721 Collection Tests ***/
    /*******************************/

    /***************************/
    /*** ERC721 Subset Tests ***/
    /***************************/

    function testPledgeCollateralSubset() external {
        // check initial token balances
        assertEq(_subsetPool.pledgedCollateral(),             0);
        assertEq(_collateral.balanceOf(_borrower),            52);
        assertEq(_collateral.balanceOf(address(_subsetPool)), 0);

        uint256[] memory tokenIdsToAdd = new uint256[](3);
        tokenIdsToAdd[0] = 1;
        tokenIdsToAdd[1] = 3;
        tokenIdsToAdd[2] = 5;

        // borrower deposits three NFTs into the subset pool
        changePrank(_borrower);
        vm.expectEmit(true, true, false, true);
        emit Transfer(_borrower, address(_subsetPool), 1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(_borrower, address(_subsetPool), 3);
        vm.expectEmit(true, true, false, true);
        emit Transfer(_borrower, address(_subsetPool), 5);
        vm.expectEmit(true, true, false, true);
        emit PledgeCollateralNFT(_borrower, tokenIdsToAdd);
        _subsetPool.pledgeCollateral(_borrower, tokenIdsToAdd, address(0), address(0));

        // check token balances after add
        assertEq(_subsetPool.pledgedCollateral(),             Maths.wad(3));
        assertEq(_collateral.balanceOf(_borrower),            49);
        assertEq(_collateral.balanceOf(address(_subsetPool)), 3);
    }

    function testPledgeCollateralNotInSubset() external {
        uint256[] memory tokenIdsToAdd = new uint256[](3);
        tokenIdsToAdd[0] = 2;
        tokenIdsToAdd[1] = 4;
        tokenIdsToAdd[2] = 6;

        // should revert if borrower attempts to add tokens not in the pool subset
        changePrank(_borrower);
        vm.expectRevert(IERC721Pool.OnlySubset.selector);
        _subsetPool.pledgeCollateral(_borrower, tokenIdsToAdd, address(0), address(0));
    }

    function testPledgeCollateralInSubsetFromDifferentActor() external {
        // check initial token balances
        assertEq(_subsetPool.pledgedCollateral(),             0);
        assertEq(_collateral.balanceOf(_borrower),            52);
        assertEq(_collateral.balanceOf(_borrower2),           53);
        assertEq(_collateral.balanceOf(address(_subsetPool)), 0);

        (, , uint256[] memory col, ) = _subsetPool.borrowerInfo(_borrower);
        assertEq(col.length,  0);
        (, , col, ) = _subsetPool.borrowerInfo(_borrower2);
        assertEq(col.length,  0);

        uint256[] memory tokenIdsToAdd = new uint256[](1);
        tokenIdsToAdd[0] = 53;

        // borrower deposits three NFTs into the subset pool
        changePrank(_borrower2);
        _collateral.setApprovalForAll(address(_subsetPool), true);
        vm.expectEmit(true, true, false, true);
        emit Transfer(_borrower2, address(_subsetPool), 53);
        vm.expectEmit(true, true, false, true);
        emit PledgeCollateralNFT(_borrower, tokenIdsToAdd);
        _subsetPool.pledgeCollateral(_borrower, tokenIdsToAdd, address(0), address(0));

        // check token balances after add
        assertEq(_subsetPool.pledgedCollateral(),             Maths.wad(1));
        assertEq(_collateral.balanceOf(_borrower),            52);
        assertEq(_collateral.balanceOf(_borrower2),           52);
        assertEq(_collateral.balanceOf(address(_subsetPool)), 1);

        (, , col, ) = _subsetPool.borrowerInfo(_borrower);
        assertEq(col.length,  1);
        (, , col, ) = _subsetPool.borrowerInfo(_borrower2);
        assertEq(col.length,  0);
    }

    function testPullCollateral() external {
        // check initial token balances
        assertEq(_subsetPool.pledgedCollateral(),             0);
        assertEq(_collateral.balanceOf(_borrower),            52);
        assertEq(_collateral.balanceOf(address(_subsetPool)), 0);

        uint256[] memory tokenIdsToAdd = new uint256[](3);
        tokenIdsToAdd[0] = 1;
        tokenIdsToAdd[1] = 3;
        tokenIdsToAdd[2] = 5;

        // borrower deposits three NFTs into the subset pool
        changePrank(_borrower);
        vm.expectEmit(true, true, false, true);
        emit Transfer(_borrower, address(_subsetPool), 1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(_borrower, address(_subsetPool), 3);
        vm.expectEmit(true, true, false, true);
        emit Transfer(_borrower, address(_subsetPool), 5);
        vm.expectEmit(true, true, false, true);
        emit PledgeCollateralNFT(_borrower, tokenIdsToAdd);
        _subsetPool.pledgeCollateral(_borrower, tokenIdsToAdd, address(0), address(0));

        // check token balances after add
        assertEq(_subsetPool.pledgedCollateral(),             Maths.wad(3));
        assertEq(_collateral.balanceOf(_borrower),            49);
        assertEq(_collateral.balanceOf(address(_subsetPool)), 3);

        uint256[] memory tokenIdsToRemove = new uint256[](2);
        tokenIdsToRemove[0] = 3;
        tokenIdsToRemove[1] = 5;

        // borrower removes some of their deposted NFTS from the pool
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(_subsetPool), _borrower, 3);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(_subsetPool), _borrower, 5);
        vm.expectEmit(true, true, false, true);
        emit PullCollateralNFT(_borrower, tokenIdsToRemove);
        _subsetPool.pullCollateral(tokenIdsToRemove, address(0), address(0));

        // check token balances after remove
        assertEq(_subsetPool.pledgedCollateral(),             Maths.wad(1));
        assertEq(_collateral.balanceOf(_borrower),            51);
        assertEq(_collateral.balanceOf(address(_subsetPool)), 1);
    }

    // TODO: finish implementing
    function testPullCollateralNotInPool() external {
        uint256[] memory tokenIdsToAdd = new uint256[](3);
        tokenIdsToAdd[0] = 1;
        tokenIdsToAdd[1] = 3;
        tokenIdsToAdd[2] = 5;

        changePrank(_borrower);
        _subsetPool.pledgeCollateral(_borrower, tokenIdsToAdd, address(0), address(0));

        // should revert if borrower attempts to remove collateral not in pool
        uint256[] memory tokenIdsToRemove = new uint256[](1);
        tokenIdsToRemove[0] = 51;
        vm.expectRevert(IERC721Pool.TokenNotDeposited.selector);
        _subsetPool.pullCollateral(tokenIdsToRemove, address(0), address(0));

        // borrower should be able to remove collateral in the pool
        tokenIdsToRemove = new uint256[](3);
        tokenIdsToRemove[0] = 1;
        tokenIdsToRemove[1] = 3;
        tokenIdsToRemove[2] = 5;

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(_subsetPool), _borrower, 1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(_subsetPool), _borrower, 3);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(_subsetPool), _borrower, 5);
        vm.expectEmit(true, true, false, true);
        emit PullCollateralNFT(_borrower, tokenIdsToRemove);
        _subsetPool.pullCollateral(tokenIdsToRemove, address(0), address(0));
    }

    function testPullCollateralPartiallyEncumbered() external {
        vm.startPrank(_lender);
        // lender deposits 10000 Quote into 3 buckets
        _subsetPool.addQuoteToken(10_000 * 1e18, 2550);
        _subsetPool.addQuoteToken(10_000 * 1e18, 2551);
        _subsetPool.addQuoteToken(10_000 * 1e18, 2552);

        // check initial token balances
        assertEq(_subsetPool.pledgedCollateral(),             0);
        assertEq(_collateral.balanceOf(_borrower),            52);
        assertEq(_collateral.balanceOf(address(_subsetPool)), 0);

        assertEq(_quote.balanceOf(address(_subsetPool)), 30_000 * 1e18);
        assertEq(_quote.balanceOf(_borrower),            0);

        // check pool state
        assertEq(_subsetPool.htp(), 0);
        assertEq(_subsetPool.lup(), BucketMath.MAX_PRICE);

        assertEq(_subsetPool.poolSize(),         30_000 * 1e18);
        assertEq(_subsetPool.exchangeRate(2550), 1 * 1e27);

        uint256[] memory tokenIdsToAdd = new uint256[](3);
        tokenIdsToAdd[0] = 1;
        tokenIdsToAdd[1] = 3;
        tokenIdsToAdd[2] = 5;

        // borrower deposits three NFTs into the subset pool
        changePrank(_borrower);
        vm.expectEmit(true, true, false, true);
        emit Transfer(_borrower, address(_subsetPool), 1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(_borrower, address(_subsetPool), 3);
        vm.expectEmit(true, true, false, true);
        emit Transfer(_borrower, address(_subsetPool), 5);
        vm.expectEmit(true, true, false, true);
        emit PledgeCollateralNFT(_borrower, tokenIdsToAdd);
        _subsetPool.pledgeCollateral(_borrower, tokenIdsToAdd, address(0), address(0));

        // TODO: determine how to handle checking both token types of Transfer
        // emit Transfer(_borrower, address(_subsetPool), 5);
        vm.expectEmit(true, true, false, true);
        emit Borrow(_borrower, _subsetPool.indexToPrice(2550), 3_000 * 1e18);
        _subsetPool.borrow(3_000 * 1e18, 2551, address(0), address(0));

        // check token balances after borrow
        assertEq(_subsetPool.pledgedCollateral(),             Maths.wad(3));
        assertEq(_collateral.balanceOf(_borrower),            49);
        assertEq(_collateral.balanceOf(address(_subsetPool)), 3);

        assertEq(_quote.balanceOf(address(_subsetPool)), 27_000 * 1e18);
        assertEq(_quote.balanceOf(_borrower),            3_000 * 1e18);

        // check pool state
        assertEq(_subsetPool.htp(), 1000.961538461538462000 * 1e18);
        assertEq(_subsetPool.lup(), _subsetPool.indexToPrice(2550));

        assertEq(_subsetPool.poolSize(),         30_000 * 1e18);
        assertEq(_subsetPool.exchangeRate(2550), 1 * 1e27);

        // remove some unencumbered collateral
        uint256[] memory tokenIdsToRemove = new uint256[](2);
        tokenIdsToRemove[0] = 3;
        tokenIdsToRemove[1] = 5;

        // borrower removes some of their deposted NFTS from the pool
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(_subsetPool), _borrower, 3);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(_subsetPool), _borrower, 5);
        vm.expectEmit(true, true, false, true);
        emit PullCollateralNFT(_borrower, tokenIdsToRemove);
        _subsetPool.pullCollateral(tokenIdsToRemove, address(0), address(0));

        // check token balances after remove
        assertEq(_subsetPool.pledgedCollateral(),             Maths.wad(1));
        assertEq(_collateral.balanceOf(_borrower),            51);
        assertEq(_collateral.balanceOf(address(_subsetPool)), 1);

        assertEq(_quote.balanceOf(address(_subsetPool)), 27_000 * 1e18);
        assertEq(_quote.balanceOf(_borrower),            3_000 * 1e18);

        // check pool state
        assertEq(_subsetPool.htp(), 3002.884615384615386000 * 1e18);
        assertEq(_subsetPool.lup(), _subsetPool.indexToPrice(2550));

        assertEq(_subsetPool.poolSize(),         30_000 * 1e18);
        assertEq(_subsetPool.exchangeRate(2550), 1 * 1e27);

    }

    function testPullCollateralOverlyEncumbered() external {
        vm.startPrank(_lender);
        // lender deposits 10000 Quote into 3 buckets
        _subsetPool.addQuoteToken(10_000 * 1e18, 2550);
        _subsetPool.addQuoteToken(10_000 * 1e18, 2551);
        _subsetPool.addQuoteToken(10_000 * 1e18, 2552);

        uint256[] memory tokenIdsToAdd = new uint256[](3);
        tokenIdsToAdd[0] = 1;
        tokenIdsToAdd[1] = 3;
        tokenIdsToAdd[2] = 5;

        // borrower deposits three NFTs into the subset pool
        changePrank(_borrower);
        vm.expectEmit(true, true, false, true);
        emit Transfer(_borrower, address(_subsetPool), 1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(_borrower, address(_subsetPool), 3);
        vm.expectEmit(true, true, false, true);
        emit Transfer(_borrower, address(_subsetPool), 5);
        vm.expectEmit(true, true, false, true);
        emit PledgeCollateralNFT(_borrower, tokenIdsToAdd);
        _subsetPool.pledgeCollateral(_borrower, tokenIdsToAdd, address(0), address(0));

        // check collateralization after pledge
        assertEq(_subsetPool.encumberedCollateral(_subsetPool.borrowerDebt(), _subsetPool.lup()), 0);

        // borrower borrows some quote
        vm.expectEmit(true, true, false, true);
        emit Borrow(_borrower, _subsetPool.indexToPrice(2550), 9_000 * 1e18);
        _subsetPool.borrow(9_000 * 1e18, 2551, address(0), address(0));

        // check collateralization after borrow
        assertEq(_subsetPool.encumberedCollateral(_subsetPool.borrowerDebt(), _subsetPool.lup()), 2.992021560300836411 * 1e18);

        // should revert if borrower attempts to pull more collateral than is unencumbered
        uint256[] memory tokenIdsToRemove = new uint256[](2);
        tokenIdsToRemove[0] = 3;
        tokenIdsToRemove[1] = 5;

        vm.expectRevert(IScaledPool.RemoveCollateralInsufficientCollateral.selector);
        _subsetPool.pullCollateral(tokenIdsToRemove, address(0), address(0));
    }

    function testAddRemoveCollateral() external {
        vm.startPrank(_lender);
        // lender adds some liquidity
        _subsetPool.addQuoteToken(10_000 * 1e18, 1530);
        _subsetPool.addQuoteToken(10_000 * 1e18, 1692);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 5;

        // add three tokens to a single bucket
        changePrank(_borrower);
        vm.expectEmit(true, true, false, true);
        emit AddCollateralNFT(_borrower, 1530, tokenIds);
        _subsetPool.addCollateral(tokenIds, 1530);

        // should revert if the actor does not have any LP to remove a token
        changePrank(_borrower2);
        tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        vm.expectRevert(IScaledPool.RemoveCollateralInsufficientLP.selector);
        _subsetPool.removeCollateral(tokenIds, 1530);

        // should revert if we try to remove a token from a bucket with no collateral
        changePrank(_borrower);
        tokenIds[0] = 1;
        vm.expectRevert(IScaledPool.RemoveCollateralInsufficientCollateral.selector);
        _subsetPool.removeCollateral(tokenIds, 1692);

        // remove one token
        tokenIds[0] = 5;
        emit RemoveCollateralNFT(_borrower, _subsetPool.indexToPrice(1530), tokenIds);
        _subsetPool.removeCollateral(tokenIds, 1530);
        (, uint256 collateral, , ) = _subsetPool.bucketAt(1530);
        assertEq(collateral, 1 * 1e18);

        // remove another token
        tokenIds[0] = 1;
        emit RemoveCollateralNFT(_borrower, _subsetPool.indexToPrice(1530), tokenIds);
        _subsetPool.removeCollateral(tokenIds, 1530);
        (, collateral, , ) = _subsetPool.bucketAt(1530);
        assertEq(collateral, 0);
        (uint256 lpb, ) = _subsetPool.bucketLenders(1530, _borrower);
        assertEq(lpb, 0);

        // lender removes quote token
        changePrank(_lender);
        _subsetPool.removeAllQuoteToken(1530);
        (, collateral, lpb, ) = _subsetPool.bucketAt(1530);
        assertEq(collateral, 0);
        assertEq(lpb, 0);
    }

    function testMoveCollateral() external {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 3;
        tokenIds[2] = 5;

        // add three tokens to a single bucket
        changePrank(_borrower);
        vm.expectEmit(true, true, false, true);
        emit AddCollateralNFT(_borrower, 1530, tokenIds);
        _subsetPool.addCollateral(tokenIds, 1530);

        // move half of collateral to another bucket, splitting up the tokens
        changePrank(_borrower);
        vm.expectEmit(true, true, false, true);
        emit MoveCollateral(_borrower, 1530, 1447, 1.6 * 1e18);
        _subsetPool.moveCollateral(1.6 * 1e18, 1530, 1447);

        // remove a token from the old bucket
        tokenIds = new uint256[](1);
        tokenIds[0] = 5;
        _subsetPool.removeCollateral(tokenIds, 1530);

        // check buckets
        (, uint256 collateral, , ) = _subsetPool.bucketAt(1530);
        assertEq(collateral, 0.4 * 1e18);
        (, collateral, , ) = _subsetPool.bucketAt(1447);
        assertEq(collateral, 1.6 * 1e18);

        // remove a token from the new bucket
        tokenIds[0] = 1;
        _subsetPool.removeCollateral(tokenIds, 1447);

        // should revert if we try to remove a token from either bucket (both with 0.5 collateral)
        tokenIds[0] = 1;
        vm.expectRevert(IScaledPool.RemoveCollateralInsufficientCollateral.selector);
        _subsetPool.removeCollateral(tokenIds, 1530);
        vm.expectRevert(IScaledPool.RemoveCollateralInsufficientCollateral.selector);
        _subsetPool.removeCollateral(tokenIds, 1447);

        // move LP from old to new bucket, reconstituting the last token
        vm.expectEmit(true, true, false, true);
        emit MoveCollateral(_borrower, 1530, 1447, 0.4 * 1e18);
        _subsetPool.moveCollateral(0.4 * 1e18, 1530, 1447);

        // check buckets
        uint lpb;
        (, collateral, lpb, ) = _subsetPool.bucketAt(1530);
        assertEq(collateral, 0);
        assertEq(lpb, 0);
        (, collateral, , ) = _subsetPool.bucketAt(1447);
        assertEq(collateral, 1 * 1e18);

        // check actor
        (lpb, ) = _subsetPool.bucketLenders(1530, _borrower);
        assertEq(lpb, 0);

        // remove the last token
        tokenIds[0] = 3;
        emit RemoveCollateralNFT(_borrower, _subsetPool.indexToPrice(1447), tokenIds);
        _subsetPool.removeCollateral(tokenIds, 1447);
    }
}