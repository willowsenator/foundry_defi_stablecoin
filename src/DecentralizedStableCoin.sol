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

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Decentralized Stable Coin
 * @author Omar Fernando Moreno Benito
 * Collateral: Exogenous (BTC & ETH)
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 *
 * This is the contract meant to be governed by DCEngine.
 * This contract is just the ERC20 implementation of our stablecoin system.
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    //////////////////
    // Errors
    /////////////////
    error DecentralizedStableCoin__MustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    //////////////////
    // Modifiers
    /////////////////

    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        _;
    }

    modifier notZeroAddress(address _address) {
        if (_address == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        _;
    }

    modifier burnAmountExceedsBalance(uint256 _amount) {
        uint256 balance = balanceOf(msg.sender);
        if (balance < _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        _;
    }

    //////////////////
    // Functions
    /////////////////

    constructor() ERC20("Decentralized Stable Coin", "DSC") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner moreThanZero(_amount) burnAmountExceedsBalance(_amount) {
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount)
        external
        onlyOwner
        notZeroAddress(_to)
        moreThanZero(_amount)
        returns (bool)
    {
        _mint(_to, _amount);
        return true;
    }
}
