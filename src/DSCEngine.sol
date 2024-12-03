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

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/interfaces/AggregatorV3Interface.sol";

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
contract DSCEngine is ReentrancyGuard {
    //////////////////
    // Errors
    /////////////////
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeTheSameLength();
    error DSCEngine__TokenNotAllow();
    error DSCEngine__DepositCollateralFailed();

    //////////////////
    // State variables
    /////////////////
    uint256 private constant ADDIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;

    mapping(address tokem => address priceFeed) private s_priceFeeds; // tokentoPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_userCollateralDeposited; // userCollateral
    mapping(address user => uint256 amountDSCMinted) private s_userDSCMinted; // userDSCMinted
    DecentralizedStableCoin private immutable i_dsc;
    address[] private s_collateralTokens;

    //////////////////
    // Events
    //////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    //////////////////
    // Modifiers
    /////////////////

    modifier moreThanZero(uint256 _amount) {
        if (_amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowToken(address _token) {
        if (s_priceFeeds[_token] == address(0)) {
            revert DSCEngine__TokenNotAllow();
        }
        _;
    }

    //////////////////
    // Functions
    /////////////////

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        // USD Price Feed
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeTheSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    //////////////////
    // External functions
    /////////////////

    function depositCollateralAndMintDSC() external {
        // Deposit collateral
        // Mint DSC
    }

    /**
     *
     * @param tokenCollateralAddress Collateral token address
     * @param collateralAmount collateral amount
     */
    function depositCollateral(address tokenCollateralAddress, uint256 collateralAmount)
        external
        moreThanZero(collateralAmount)
        isAllowToken(tokenCollateralAddress)
        nonReentrant
    {
        s_userCollateralDeposited[msg.sender][tokenCollateralAddress] += collateralAmount;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, collateralAmount);
        
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), collateralAmount);
        if (!success) {
            revert DSCEngine__DepositCollateralFailed();
        }

    }

    function redeemCollateralForDSC() external {
        // Redeem Collateral
    }

    function redeemDSC() external {
        // Redeem DSC
    }


    /**
     * @notice Mint DSC
     * @param amountDSCToMint Amount of DSC to mint
     * @notice They must have more collateral than the value of the DSC they are minting
     */
    function mintDSC(uint256 amountDSCToMint) external moreThanZero(amountDSCToMint) nonReentrant {
        s_userDSCMinted[msg.sender] += amountDSCToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDSC() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

     //////////////////
    // Internal and private functions
    /////////////////

    function _getAccountInformation(address user) private view returns (uint256 totalDSCMinted, uint256 collateralValueInUSD) {
        totalDSCMinted = s_userDSCMinted[user];
        collateralValueInUSD = getAccountCollateralValueInUSD(user);
    }

    /**
     * @notice Calculate how to close to being liquidated a user is
     * @param user User address
     */
    function _healthFactor(address user) private view returns (uint256) {


    }
    function _revertIfHealthFactorIsBroken(address user) internal view {

    }

     //////////////////
    // Public and external functions
    /////////////////

    function getAccountCollateralValueInUSD(address user) public view returns (uint256 totalCollateralValueInUSD) {
       for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_userCollateralDeposited[user][token];
            totalCollateralValueInUSD += getUSDValue(token, amount);
        }
        return totalCollateralValueInUSD;
    }

    function getUSDValue(address token, uint256 amount) public view returns (uint256) {
        // Get price feed
        // Get price
        // Return price * amount
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int price, , , ) = priceFeed.latestRoundData();

        // 1 ETH = 1000 $
        // 1 ETH = 1000 * 1e^8
        // (((1000 * 1e8) * 1e10) * 1000) / 1e^18
        return (((uint256(price) * ADDIONAL_FEED_PRECISION) * amount) / PRECISION);
    }
}
