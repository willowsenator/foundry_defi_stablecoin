// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleLib
 * @author Omar Fernando Moreno Benito
 * @notice This library is used in chainlink oracles
 * If a price is stale, the function will revert and render DSCEngine unusable - this is a feature, not a bug.
 * We want the DSCEngine to freeze if the price is stale.
 *
 * So if the Chainlink Oracle is down, the DSCEngine will lock your money until the Oracle is back up.
 */
library OracleLib {
    error OracleLib__StalePrice();

    uint256 private constant TIMEOUT = 3 hours; // 3 * 60 * 60 = 10800 seconds

    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundID, int256 price, uint256 startedAt, uint256 timestamp, uint80 answeredInRound) =
            priceFeed.latestRoundData();
        uint256 secondsSince = block.timestamp - timestamp;
        if (secondsSince > TIMEOUT) {
            revert OracleLib__StalePrice();
        }
        return (roundID, price, startedAt, timestamp, answeredInRound);
    }
}
