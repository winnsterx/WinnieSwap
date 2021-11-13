// =================== CS251 DEX Project =================== // 
//        @authors: Simon Tao '22, Mathew Hogan '22          //
// ========================================================= //    
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '../interfaces/erc20_interface.sol';
import '../libraries/safe_math.sol';
import './token.sol';


contract TokenExchange {
    using SafeMath for uint;
    address public admin;
    struct position {
        uint eth;
        uint poo; 
        uint feesEth;
        uint feesPoo;
        uint percent;
        bool exists;
    }

    address tokenAddr = 0x4Be8f58439A2c2c96873E7d69Cd0F08924e5400C;                              // TODO: Paste token contract address here.
    Pooh private token = Pooh(tokenAddr);         // TODO: Replace "Token" with your token class.             

    // Liquidity pool for the exchange
    uint public token_reserves = 0;
    uint public eth_reserves = 0;

    // Constant: x * y = k
    uint public k;
    uint multiplier = 10**18;
    
    // liquidity rewards
    uint private swap_fee_numerator = 1;       // TODO Part 5: Set liquidity providers' returns.
    uint private swap_fee_denominator = 100;

    uint reinvestEth_reserve = 0;
    uint reinvestPoo_reserve = 0;

    mapping(address => position) positions;
    address[] providers;
    
    event AddLiquidity(address from, uint amount);
    event RemoveLiquidity(address to, uint amount);
    event Received(address from, uint amountETH);

    constructor() 
    {
        admin = msg.sender;
    }
    
    modifier AdminOnly {
        require(msg.sender == admin, "Only admin can use this function!");
        _;
    }

    // Used for receiving ETH
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
    fallback() external payable{}

    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens)
        external
        payable
        AdminOnly
    {
        // require pool does not yet exist
        require (token_reserves == 0, "Token reserves was not 0");
        require (eth_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require (msg.value > 0, "Need ETH to create pool.");
        require (amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        eth_reserves = msg.value;
        token_reserves = amountTokens;
        k = eth_reserves.mul(token_reserves);

        // TODO: Keep track of the initial liquidity added so the initial provider
        //          can remove this liquidity
        positions[msg.sender].eth = msg.value;
        positions[msg.sender].poo = amountTokens;
        positions[msg.sender].percent = multiplier;
        positions[msg.sender].exists = true;
        providers.push(msg.sender);
    }

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================
    /* Be sure to use the SafeMath library for all operations! */
    
    // Function priceToken: Calculate the price of your token in ETH.
    // You can change the inputs, or the scope of your function, as needed.
    function priceToken() 
        public 
        view
        returns (uint)
    {
        /******* TODO: Implement this function *******/
        /* HINTS:
            Calculate how much ETH is of equivalent worth based on the current exchange rate.
        */
        require(token_reserves > 0, "POO reserve is 0.");
        return (eth_reserves.mul(multiplier)).div(token_reserves);
    }

    // Function priceETH: Calculate the price of ETH for your token.
    // You can change the inputs, or the scope of your function, as needed.
    function priceETH()
        public
        view
        returns (uint)
    {
        /******* TODO: Implement this function *******/
        /* HINTS:
            Calculate how much of your token is of equivalent worth based on the current exchange rate.
        */
        require(eth_reserves > 0, "ETH reserve is 0.");
        return (token_reserves.mul(multiplier)).div(eth_reserves);
    }


    /* ========================= Liquidity Provider Functions =========================  */ 

    /***  Define helper functions for liquidity management here as needed: ***/

    function updatePositions() 
        internal 
    {
        for (uint i = 0; i < providers.length; i++) {
            positions[providers[i]].percent = (positions[providers[i]].eth.mul(multiplier)).div(eth_reserves);
        }
    }

    function showPositionPercent(address provider)
        public view returns (uint)
    {
        return positions[provider].percent;
    }

    function showPositionEth(address provider)
        public view returns (uint)
    {
        return positions[provider].eth;
    }

    function showPositionPoo(address provider)
        public view returns (uint)
    {
        return positions[provider].poo;
    }

    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value)
    // You can change the inputs, or the scope of your function, as needed.
    function addLiquidity(uint max_exchange_rate, uint min_exchange_rate) 
        external 
        payable
    {
        /******* TODO: Implement this function *******/
        /* HINTS:
            Calculate the liquidity to be added based on what was sent in and the prices.
            If the caller possesses insufficient tokens to equal the ETH sent, then transaction must fail.
            Update token_reserves, eth_reserves, and k.
            Emit AddLiquidity event.
        */
        require(eth_reserves > 0 && token_reserves > 0, "Insufficient liquidity.");
        require(msg.value > 0, "Need some ETH for liquidity.");
        uint amountTokens = msg.value.mul(priceETH()).div(multiplier);
        require(token.balanceOf(msg.sender) >= amountTokens, "Insufficient tokens for ETH sent.");

        // slippages
        require(priceETH() <= max_exchange_rate, "Slippage exceeds max exchange rate of ETH.");
        require(priceETH() >= min_exchange_rate, "Slippage falls below min exchange rate of ETH.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        token_reserves = token_reserves.add(amountTokens);
        eth_reserves = eth_reserves.add(msg.value);
        k = eth_reserves.mul(token_reserves);

        positions[msg.sender].eth = positions[msg.sender].eth.add(msg.value);
        positions[msg.sender].poo = positions[msg.sender].poo.add(amountTokens);
        if (positions[msg.sender].exists == false) {
            providers.push(msg.sender);
            positions[msg.sender].exists = true;
        }
        updatePositions();

        emit AddLiquidity(msg.sender, msg.value);
    }


    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
    function removeLiquidity(uint amountETH, uint max_exchange_rate, uint min_exchange_rate, uint amountFeeETH, uint amountFeePoo)
        public 
        payable
    {
        /******* TODO: Implement this function *******/
        /* HINTS:
            Calculate the amount of your tokens that should be also removed.
            Transfer the ETH and Token to the provider.
            Update token_reserves, eth_reserves, and k.
            Emit RemoveLiquidity event.
        */
        require(eth_reserves > 0 && token_reserves > 0, "Insufficient liquidity.");
        require(amountETH > 0, "Insufficient input amount.");
        require(amountETH < eth_reserves, "Must withdraw ETH < ETH supply.");

        // since the fees in position are not yet in the liquidity pool yet
        // when reinvested, feesETH/feesPoo becomes eth/poo
        require(amountFeeETH <= positions[msg.sender].feesEth, "Insufficient eth fee"); 
        require(amountFeePoo <= positions[msg.sender].feesPoo, "Insufficient poo fee");

        uint maxETH = (positions[msg.sender].percent.mul(eth_reserves)).div(multiplier);
        require(amountETH <= maxETH, "Must withdraw lower than maximum allowed value"); 

        uint amountTokens = (amountETH.mul(priceETH())).div(multiplier);
        require(amountTokens < token_reserves, "Must withdraw token < token supply.");

        // slippages
        require(priceETH() <= max_exchange_rate, "Slippage exceeds max exchange rate of ETH.");
        require(priceETH() >= min_exchange_rate, "Slippage falls below min exchange rate of ETH.");

        // usually fee params r 0; if remove max, then all 
        payable(msg.sender).transfer(amountETH.add(amountFeeETH));
        token.transfer(msg.sender, amountTokens.add(amountFeePoo));
        
        eth_reserves = eth_reserves.sub(amountETH);
        token_reserves = token_reserves.sub(amountTokens);
        k = eth_reserves.mul(token_reserves);

        positions[msg.sender].feesEth = positions[msg.sender].feesEth.sub(amountFeeETH); 
        positions[msg.sender].feesPoo = positions[msg.sender].feesPoo.sub(amountFeePoo);
        positions[msg.sender].eth = positions[msg.sender].eth.sub(amountETH);
        positions[msg.sender].poo = positions[msg.sender].poo.sub(amountTokens);
        updatePositions();

        emit RemoveLiquidity(msg.sender, amountETH);
    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity(uint max_exchange_rate, uint min_exchange_rate)
        external
        payable
    {
        /******* TODO: Implement this function *******/
        /* HINTS:
            Decide on the maximum allowable ETH that msg.sender can remove.
            Call removeLiquidity().
        */
        require(eth_reserves > 0 && token_reserves > 0, "Insufficient liquidity.");
        uint maxETH = (positions[msg.sender].percent.mul(eth_reserves)).div(multiplier);
        removeLiquidity(maxETH, max_exchange_rate, min_exchange_rate, positions[msg.sender].feesEth, positions[msg.sender].feesPoo);
    }


    /***  Define helper functions for swaps here as needed: ***/
    function distributeTokenFees(uint fees) 
        internal
    { 
        for (uint i = 0; i < providers.length; i++) {
            positions[providers[i]].feesPoo = positions[providers[i]].percent.mul(fees).div(multiplier);
        }
    }


    function distributeETHFees(uint fees) 
        internal
    { 
        for (uint i = 0; i < providers.length; i++) {
            positions[providers[i]].feesEth = positions[providers[i]].percent.mul(fees).div(multiplier);
        }
    }

    function showFeesPoo(address provider)
        public view returns (uint)
    {
        return positions[provider].feesPoo;
    }

    function showFeesEth(address provider)
        public view returns (uint)
    {
        return positions[provider].feesEth;
    }

    function reinvest() 
        internal 
    {
        //swap will never happen bc reverted 
        // require(reinvestEth_reserve > 0, "There is no fees accumulated in ETH");
        // require(reinvestPoo_reserve > 0, "There is no fees accumulated in POO"); 
        if (reinvestPoo_reserve == 0 || reinvestEth_reserve == 0) {
            return;
        } 

        uint amountTokens = reinvestEth_reserve.mul(priceETH()).div(multiplier);
        uint amountETH = reinvestPoo_reserve.mul(priceToken()).div(multiplier);
        if (amountTokens >= reinvestPoo_reserve) { // reinvestEth >= reinvestTok
            // reinvest all of reinvestPoo & amountTokens - Eth
            // limiting factor, token
            for (uint i = 0; i < providers.length; i++) {
                positions[providers[i]].poo = positions[providers[i]].poo.add(positions[providers[i]].feesPoo);
                uint equalEth = positions[providers[i]].feesPoo.mul(priceToken()).div(multiplier);
                positions[providers[i]].eth = positions[providers[i]].eth.add(equalEth);
                positions[providers[i]].feesEth = positions[providers[i]].feesEth.sub(equalEth); 
                positions[providers[i]].feesPoo = 0;    
            }
            reinvestPoo_reserve = 0;
            reinvestEth_reserve = reinvestEth_reserve.sub(amountETH);

            token_reserves = token_reserves.add(reinvestPoo_reserve);
            eth_reserves = eth_reserves.add(amountETH); 


        } else {    // reinvestEth < reinvestTok
            // limiting factor, eth 
            // invest all of reinvest_eth & reinvest_tokens - equivalent
            for (uint i = 0; i < providers.length; i++) {
                positions[providers[i]].eth = positions[providers[i]].eth.add(positions[providers[i]].feesEth);
                uint equalPoo = positions[providers[i]].feesEth.mul(priceETH()).div(multiplier);
                positions[providers[i]].poo = positions[providers[i]].poo.add(equalPoo);
                positions[providers[i]].feesPoo = positions[providers[i]].feesEth.sub(equalPoo); 
                positions[providers[i]].feesEth = 0;    
            }
            reinvestEth_reserve = 0;
            reinvestPoo_reserve = reinvestPoo_reserve.sub(amountTokens);
            
            eth_reserves = eth_reserves.add(reinvestEth_reserve); 
            token_reserves = token_reserves.add(amountTokens);
        }

        k = token_reserves.mul(eth_reserves);     
        updatePositions();
    }

    /* ========================= Swap Functions =========================  */ 

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    function swapTokensForETH(uint amountTokens, uint max_exchange_rate)
        external 
        payable
    {
        /******* TODO: Implement this function *******/
        /* HINTS:
            Calculate amount of ETH should be swapped based on exchange rate.
            Transfer the ETH to the provider.
            If the caller possesses insufficient tokens, transaction must fail.
            If performing the swap would exhaus total ETH supply, transaction must fail.
            Update token_reserves and eth_reserves.

            Part 4: 
                Expand the function to take in addition parameters as needed.
                If current exchange_rate > slippage limit, abort the swap.
            
            Part 5:
                Only exchange amountTokens * (1 - liquidity_percent), 
                    where % is sent to liquidity providers.
                Keep track of the liquidity fees to be added.
        */
        // price is in 1e18 unit
        require(amountTokens > 0, "Insufficient input amount.");
        require(eth_reserves > 0 && token_reserves > 0, "Insufficient liquidity.");
        require(token.balanceOf(msg.sender) >= amountTokens, "Insufficient tokens in balance.");

        // slippages
        require(priceETH() <= max_exchange_rate, "Slippage exceeds max exchange rate of ETH.");

        uint amountAfterFee = amountTokens.mul(uint(100).sub(swap_fee_numerator)).div(100);
        uint numerator = eth_reserves.mul(amountAfterFee);
        uint denominator = token_reserves.add(amountAfterFee);
        uint amountETH = numerator.div(denominator);
        require(amountETH < eth_reserves, "Swap depletes ETH supply.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        payable(msg.sender).transfer(amountETH);

        uint fees = amountTokens.sub(amountAfterFee);
        distributeTokenFees(fees); // in tokens

        token_reserves = token_reserves.add(amountAfterFee);
        eth_reserves = eth_reserves.sub(amountETH);

        /***************************/
        // DO NOT MODIFY BELOW THIS LINE
        /* Check for x * y == k, assuming x and y are rounded to the nearest integer. */
        // Check for Math.abs(token_reserves * eth_reserves - k) < (token_reserves + eth_reserves + 1));
        //   to account for the small decimal errors during uint division rounding.
        uint check = token_reserves.mul(eth_reserves);
        if (check >= k) {
            check = check.sub(k);
        }
        else {
            check = k.sub(check);
        }
        require(check < (token_reserves.add(eth_reserves).add(1)), "failed the k check");
        
        reinvestPoo_reserve = reinvestPoo_reserve.add(fees);
        
        reinvest();
    }



    // Function swapETHForTokens: Swaps ETH for your tokens.
    // ETH is sent to contract as msg.value.
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens(uint max_exchange_rate)
        external
        payable 
    {
        /******* TODO: Implement this function *******/
        /* HINTS:
            Calculate amount of your tokens should be swapped based on exchange rate.
            Transfer the amount of your tokens to the provider.
            If performing the swap would exhaus total token supply, transaction must fail.
            Update token_reserves and eth_reserves.

            Part 4: 
                Expand the function to take in addition parameters as needed.
                If current exchange_rate > slippage limit, abort the swap. 
            
            Part 5: 
                Only exchange amountTokens * (1 - %liquidity), 
                    where % is sent to liquidity providers.
                Keep track of the liquidity fees to be added.
        */
        require(msg.value > 0, "Insufficient input amount.");
        require(eth_reserves > 0 && token_reserves > 0, "Insufficient liquidity.");

        // slippage
        require(priceToken() <= max_exchange_rate, "Slippage caused priceToken to exceed max_exchange_rate");

        // apply simple pricing rule
        uint amountSub = uint(100).sub(swap_fee_numerator);
        uint amountPreDiv = msg.value.mul(amountSub);
        uint amountAfterFee = amountPreDiv.div(100);
        uint numerator = token_reserves.mul(amountAfterFee);
        uint denominator = eth_reserves.add(amountAfterFee);
        uint amountTokens = numerator.div(denominator); 
        // need to account for decimal points
        require(amountTokens < token_reserves, "Swap depletes POO supply.");

        token.transfer(msg.sender, amountTokens);

        uint fees = msg.value.sub(amountAfterFee);
        distributeETHFees(fees);

        token_reserves = token_reserves.sub(amountTokens);
        eth_reserves = eth_reserves.add(amountAfterFee);

        /**************************/
        // DO NOT MODIFY BELOW THIS LINE
        /* Check for x * y == k, assuming x and y are rounded to the nearest integer. */
        // Check for Math.abs(token_reserves * eth_reserves - k) < (token_reserves + eth_reserves + 1));
        //   to account for the small decimal errors during uint division rounding.
        uint check = token_reserves.mul(eth_reserves);
        if (check >= k) {
            check = check.sub(k);
        }
        else {
            check = k.sub(check);
        }
        require(check < (token_reserves.add(eth_reserves).add(1)), "failed the k check");

        reinvestEth_reserve = reinvestEth_reserve.add(fees);
        reinvest();
    }
}
