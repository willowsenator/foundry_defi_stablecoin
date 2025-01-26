// SPDX-License Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/interfaces/AggregatorV3Interface.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;

    // Constants
    uint256 private constant ADDIONAL_FEED_PRECISION = 1e10;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;
    uint256 private constant PRECISION = 1e18;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant AMOUNT_TO_MINT = 2 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    ///////////////////
    // Constructor Tests ///
    ///////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMathPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeTheSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }
    ///////////////////
    // Price Tests ///
    ///////////////////

    function testGetUSDValue() public view {
        uint256 ethAmount = 15e18;
        // 15e18 * 2000/ETH = 30000e18
        uint256 expectedUSD = 30000e18;
        uint256 actualUSD = engine.getUSDValue(weth, ethAmount);
        assertEq(expectedUSD, actualUSD);
    }

    /////////////////////////
    // Minting Tests ///
    ///////////////////////
    function testSuccessfulMintDSC() public {
        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        engine.depositCollateral(weth, AMOUNT_COLLATERAL);

        engine.mintDSC(AMOUNT_TO_MINT);

        (uint256 totalDscMinted, uint256 totalCollateralInUSD) = engine.getAccountInformation(USER);
        assertEq(totalDscMinted, AMOUNT_TO_MINT);
        assertEq(totalCollateralInUSD, engine.getUSDValue(weth, AMOUNT_COLLATERAL));
        vm.stopPrank();
    }

    function testRevertIfMintAmountZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.mintDSC(0);
        vm.stopPrank();
    }

    // Fix the problem about precision to calculate healthFactor

    /*
    function testRevertIfHealthFactorFails() public {
    // Start a prank as the user
    vm.startPrank(USER);

    // Mint and approve collateral
    ERC20Mock(weth).mint(USER, 0.002 ether); // Example: 1 WETH
    ERC20Mock(weth).approve(address(engine), 0.002 ether);

    // Deposit collateral into the system
    engine.depositCollateral(weth, 0.002 ether);

    // Calculate the amount to mint to break the health factor
    uint256 amountToMint = (30000e18 * LIQUIDATION_PRECISION) / 
                           (LIQUIDATION_THRESHOLD * PRECISION) + 300000e18;

    // Expect the minting to revert due to health factor violation
    vm.expectRevert(
        abi.encodeWithSelector(
            DSCEngine.DSCEngine__BreakHealthFactor.selector,
            engine.healthFactor(USER) 
        )
    );

    // Attempt to mint excessive DSC
    engine.mintDSC(amountToMint);

    // Stop the prank
    vm.stopPrank();
    }*/

    ///////////////////////////////
    // Deposit collateral Tests ///
    ///////////////////////////////
    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnaprovedCollateral() public {
        ERC20Mock mockToken = new ERC20Mock();
        mockToken.mint(USER, AMOUNT_COLLATERAL);

        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllow.selector);
        engine.depositCollateral(address(mockToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUSD) = engine.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = engine.getTokenAmountFromUSD(weth, collateralValueInUSD);
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function testSuccessfullCollateralDeposit() public {
        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        ERC20Mock(wbtc).mint(USER, AMOUNT_COLLATERAL);
        ERC20Mock(wbtc).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        engine.depositCollateral(wbtc, AMOUNT_COLLATERAL);

        uint256 wbtcCollateralInUSD = engine.getUSDValue(wbtc, AMOUNT_COLLATERAL);
        uint256 wethCollateralInUSD = engine.getUSDValue(weth, AMOUNT_COLLATERAL);
        uint256 totalCollateralInUSD = wbtcCollateralInUSD + wethCollateralInUSD;

        uint256 userCollateralInUSD = engine.getAccountCollateralValueInUSD(USER);

        assertEq(userCollateralInUSD, totalCollateralInUSD);

        vm.stopPrank();
    }

    function testEmitEventOnCollateralDeposit() public {
        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectEmit(true, true, true, true);
        emit DSCEngine.CollateralDeposited(USER, weth, AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testRevertOnFailedTransfer() public {
        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        // Simulate a failed transfer
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IERC20.transferFrom.selector, USER, address(engine), AMOUNT_COLLATERAL),
            abi.encode(false)
        );

        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }
    ///////////////////////////////
    // Redeem Collateral Tests ///
    ///////////////////////////////

    function testSuccessfulRedeemCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        // Deposit collateral
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);

        // Redeem collateral
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL);

        (, uint256 collateralValueInUSD) = engine.getAccountInformation(USER);
        assertEq(collateralValueInUSD, 0);
        vm.stopPrank();
    }

    function testRevertIfCollateralAmountZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    // Fix the problem about precision to calculate healthFactor
    /*function testRevertIfHealthFactorIsBrokenAfterRedemption() public {
    vm.startPrank(USER);
    ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);
    ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

    // Deposit collateral
    engine.depositCollateral(weth, AMOUNT_COLLATERAL);

    // Mint DSC to set up the scenario
    engine.mintDSC(AMOUNT_TO_MINT);

    // Calculate the amount to redeem to break the health factor
    uint256 amountToRedeem = (AMOUNT_COLLATERAL * LIQUIDATION_PRECISION) / (LIQUIDATION_THRESHOLD * MIN_HEALTH_FACTOR) + 1;

    vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreakHealthFactor.selector, engine.healthFactor(USER)));
    engine.redeemCollateral(weth, amountToRedeem);
    vm.stopPrank();
    }*/

    ////////////////////////////
    // Burn DSC Tests ///
    ///////////////////////////

    function testSuccessfulBurnDSC() public {
        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        // Deposit collateral and mint DSC
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        engine.mintDSC(AMOUNT_TO_MINT);

        // Approve DSC tokens for burning
        ERC20Mock(address(dsc)).approve(address(engine), AMOUNT_TO_MINT);

        // Burn DSC
        engine.burnDSC(AMOUNT_TO_MINT);

        (uint256 totalDscMinted,) = engine.getAccountInformation(USER);
        assertEq(totalDscMinted, 0);
    }

    function testRevertIfBurnAmountZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.burnDSC(0);
        vm.stopPrank();
    }

    // Fix the problem about precision to calculate healthFactor
    /*function testRevertIfHealthFactorIsBrokenAfterBurning() public {
        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        // Deposit collateral and mint DSC
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        engine.mintDSC(AMOUNT_TO_MINT);

        // Aprove DSC tokens for burning
        ERC20Mock(address(dsc)).approve(address(engine), AMOUNT_TO_MINT);


        // Calculate the amount to burn to break the health factor
        uint256 amountToBurn = (AMOUNT_COLLATERAL * LIQUIDATION_PRECISION) / (LIQUIDATION_THRESHOLD * MIN_HEALTH_FACTOR) + 1;

        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreakHealthFactor.selector, engine.healthFactor(USER)));
        engine.burnDSC(amountToBurn);
        vm.stopPrank();

    }*/

    ////////////////////////////
    // Liquidation Tests ///
    ////////////////////////////

    function testRevertIfDebtToCoverIsZero() public {
        vm.startPrank(USER);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.liquidate(weth, USER, 0);
        vm.stopPrank();
    }

    function testRevertIfUserHealthFactorIsAboveMinimum() public {
        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        // Deposit collateral and mint DSC
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        engine.mintDSC(AMOUNT_TO_MINT);

        // Approve DSC tokens for burning
        ERC20Mock(address(dsc)).approve(address(engine), AMOUNT_TO_MINT);

        // Attempt to liquidate the user with a health factor above the minimum
        vm.expectRevert(DSCEngine.DSCEngine_HealthFactorOk.selector);
        engine.liquidate(weth, USER, AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    ///////////////////////////////
    // TokenAmountFromUSD Tests ///
    ///////////////////////////////

    function testGetTokenAmountFromUSD() public {
        // Mock the price feed
        address token = address(weth);
        uint256 usdAmountInWei = 1000e18; // Example: 1000 USD in Wei
        uint256 price = 2000e8; // Example: 2000 USD per token with 8 decimals

        // Mock the price feed response
        vm.mockCall(
            ethUsdPriceFeed,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(0, int256(price), 0, 0, 0)
        );

        uint256 expectedTokenAmount = (usdAmountInWei * PRECISION) / (price * ADDIONAL_FEED_PRECISION);
        uint256 actualTokenAmount = engine.getTokenAmountFromUSD(token, usdAmountInWei);

        assertEq(expectedTokenAmount, actualTokenAmount);
    }

    function testGetTokenAmountFromUSDZeroUSD() public {
        // Mock the price feed
        address token = address(weth);
        uint256 usdAmountInWei = 0; // Zero USD amount
        uint256 price = 2000e8; // Example: 2000 USD per token with 8 decimals

        // Mock the price feed response
        vm.mockCall(
            address(ethUsdPriceFeed),
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(0, int256(price), 0, 0, 0)
        );

        uint256 expectedTokenAmount = 0;
        uint256 actualTokenAmount = engine.getTokenAmountFromUSD(token, usdAmountInWei);

        assertEq(expectedTokenAmount, actualTokenAmount);
    }

    function testGetTokenAmountFromUSDZeroPrice() public {
        // Mock the price feed
        address token = address(weth);
        uint256 usdAmountInWei = 1000e18; // Example: 1000 USD in Wei
        uint256 price = 0; // Zero price feed

        // Mock the price feed response
        vm.mockCall(
            address(ethUsdPriceFeed),
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(0, int256(price), 0, 0, 0)
        );

        // Expect revert due to division by zero
        vm.expectRevert();
        engine.getTokenAmountFromUSD(token, usdAmountInWei);
    }
}
