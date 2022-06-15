// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { Interest } from "./Interest.sol";

import { IBorrowerManager } from "../interfaces/IBorrowerManager.sol";

import { BucketMath } from "../libraries/BucketMath.sol";
import { Maths }      from "../libraries/Maths.sol";

/**
 *  @notice Lender Management related functionality
 */
abstract contract BorrowerManager is IBorrowerManager, Interest {

    using EnumerableSet for EnumerableSet.UintSet;

    // borrowers book: borrower address -> BorrowerInfo
    mapping(address => BorrowerInfo) public override borrowers;

    // TODO: rename
    /// @dev Internal visibility is required as it contains a nested struct
    // borrowers book: borrower address -> NFTBorrowerInfo
    mapping(address => NFTBorrowerInfo) internal NFTborrowers;

    function getBorrowerInfo(address borrower_)
        public view override returns (
            uint256 debt_,
            uint256 pendingDebt_,
            uint256 collateralDeposited_,
            uint256 collateralEncumbered_,
            uint256 collateralization_,
            uint256 borrowerInflatorSnapshot_,
            uint256 inflatorSnapshot_
        )
    {
        BorrowerInfo memory borrower = borrowers[borrower_];

        debt_                     = borrower.debt;
        pendingDebt_              = borrower.debt;
        collateralDeposited_      = borrower.collateralDeposited;
        collateralization_        = Maths.ONE_WAD;
        borrowerInflatorSnapshot_ = borrower.inflatorSnapshot;
        inflatorSnapshot_         = inflatorSnapshot;

        if (debt_ != 0 && borrowerInflatorSnapshot_ != 0) {
            pendingDebt_          += getPendingInterest(debt_, getPendingInflator(), borrowerInflatorSnapshot_);
            collateralEncumbered_ = getEncumberedCollateral(pendingDebt_);
            collateralization_    = Maths.wrdivw(collateralDeposited_, collateralEncumbered_);
        }

    }

    function getNFTBorrowerInfo(address borrower_)
        public view returns (
            uint256 debt_,
            uint256 pendingDebt_,
            uint256[] memory collateralDeposited_,
            uint256 collateralEncumbered_,
            uint256 collateralization_,
            uint256 borrowerInflatorSnapshot_,
            uint256 inflatorSnapshot_
        )
    {
        NFTBorrowerInfo storage borrower = NFTborrowers[borrower_];
        uint256 borrowerPendingDebt = borrower.debt;
        uint256 collateralEncumbered;
        uint256 collateralization = Maths.ONE_WAD;

        if (borrower.debt > 0 && borrower.inflatorSnapshot != 0) {
            borrowerPendingDebt  += getPendingInterest(borrower.debt, getPendingInflator(), borrower.inflatorSnapshot);
            collateralEncumbered  = getEncumberedCollateral(borrowerPendingDebt);
            collateralization     = Maths.wrdivw(Maths.wad(borrower.collateralDeposited.length()), collateralEncumbered);
        }

        return (
            borrower.debt,
            borrowerPendingDebt,
            borrower.collateralDeposited.values(),
            collateralEncumbered,
            collateralization,
            borrower.inflatorSnapshot,
            inflatorSnapshot
        );
    }

    function getBorrowerCollateralization(uint256 collateralDeposited_, uint256 debt_) public view override returns (uint256) {
        if (lup != 0 && debt_ != 0) {
            return Maths.wrdivw(collateralDeposited_, getEncumberedCollateral(debt_));
        }
        return Maths.ONE_WAD;
    }

    function estimatePriceForLoan(uint256 amount_) public view override returns (uint256) {
        return estimatePrice(amount_, lup == 0 ? hpb : lup);
    }

}