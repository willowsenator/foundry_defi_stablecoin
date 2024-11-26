// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.20;

/**
 * @title DSCEngine
 * @author Omar Fernando Moreno Benito
 * The system engine that governs the Decentralized Stable Coin. It has the tokens maintain 1 token == 1 USD.
 * This stable coin has the properties:
 * Collateral: Exogenous (BTC & ETH)
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 * 
 * It is similar to DAI if DAI had no governance token, no fees and was only backed by WBTC and WETH.
 * 
 * DSC system has to be overcollateralized to mint DSC. At no point, the value of DSC can exceed the value of the collateral.
 * 
 * @notice This contract is meant to be the governance contract for DecentralizedStableCoin. It handles the mining and redeeming of DSC,
 * as well as deposting and withdrawing collateral.
 * @notice This contract is similar to the MakerDAO system, but with a few key differences.
 */
contract DSCEngine {
    function depositCollateralAndMintDSC() external {
        // Deposit collateral
        // Mint DSC
    }

    function depositCollateral() external {
        // Deposit Collateral
    }

    function redeemCollateralForDSC() external {
        // Redeem Collateral
    }

    function redeemDSC() external {
        // Redeem DSC
    }

    function mintDSC() external {

    }
    
    function burnDSC() external {

    }

    function liquidate() external {

    }

    function getHealthFactor() external view {
    }
}