// =================== CS251 DEX Project =================== // 
//        @authors: Simon Tao '22, Mathew Hogan '22          //
// ========================================================= //    
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '../interfaces/erc20_interface.sol';
import '../libraries/safe_math.sol';
 
// Your token contract
// TODO: Replace "Token" with your token name!
contract Pooh is IERC20 {
    using SafeMath for uint;

    string public constant symbol = 'POO';                 // TODO: Give your token a symbol
    string public constant name = 'Pooh';                   // TODO: Give your token a name
    uint8 public constant decimals = 18;                // See note about decimals in section 2

    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;

    uint public _totalSupply;
    bool private isMintDisabled;
    
    address public admin;

    constructor() {
        _totalSupply = 0;
        balances[msg.sender] = 0;  
        admin = msg.sender;    
        isMintDisabled = false;
    }

    modifier AdminOnly {
        require(msg.sender == admin);
        _;
    }

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================
    /* Be sure to use the SafeMath library for all operations! */

    // Function _mint: Create more of your tokens.
    // You can change the inputs, or the scope of your function, as needed.
    // Do not remove the AdminOnly modifier!
    function _mint(uint amount) 
        public 
        AdminOnly
    {
        /******* TODO: Implement this function *******/
        require(isMintDisabled == false, "Mint is disabled.");
        require(amount > 0, "Must mint at least one token.");
        
        _totalSupply = _totalSupply.add(amount);
        balances[msg.sender] = balances[msg.sender].add(amount);
        transfer(msg.sender, amount); // emits transfer event
    }

    // Function _disable_mint: Disable future minting of your token.
    // You can change the inputs, or the scope of your function, as needed.
    // Do not remove the AdminOnly modifier!
    function _disable_mint()
        public
        AdminOnly
    {
        /******* TODO: Implement this function *******/
        require(isMintDisabled == false, "Mint already disabled.");
        isMintDisabled = true;
    }


    // ============================================================
    //               STANDARD ERC-20 IMPLEMENTATION
    //                      DO NOT MODIFY 
    // ============================================================
    
    // return total supply of the token
    function totalSupply() 
        public 
        override
        view 
        returns (uint) 
    {
        return _totalSupply;
    }
 
    // return number of tokens held by account
    function balanceOf(address account) 
        public
        override 
        view 
        returns (uint) 
    {
        return balances[account];
    }
 
    // transfer numTokens from msg.sender to receiver
    function transfer(address receiver, uint numTokens) 
        public
        override 
        returns (bool) 
    {
        require(numTokens <= balances[msg.sender], "Not enough tokens in balance of msg.sender");
        balances[msg.sender] = balances[msg.sender].sub(numTokens);
        balances[receiver] = balances[receiver].add(numTokens);
        emit Transfer(msg.sender, receiver, numTokens);
        return true;
    }
 
    // approve delegate to send up to numTokens on behalf of msg.sender
    function approve(address delegate, uint numTokens) 
        public 
        override 
        returns (bool) 
    {
        allowed[msg.sender][delegate] = numTokens;
        emit Approval(msg.sender, delegate, numTokens);
        return true;
    }

    // check how many tokens delegate is allowed to send on behalf of owner
    function allowance(address owner, address delegate) 
        public
        override 
        view 
        returns (uint) 
    {
        return allowed[owner][delegate];
    }
 
    // transfer numTokens from owner to buyer
    function transferFrom(address owner, address buyer, uint numTokens) 
        public
        override 
        returns (bool) 
    {
        require(numTokens <= balances[owner], "error in transferFrom 1");
        require(numTokens <= allowed[owner][msg.sender], "error in transferFrom 2");
        balances[owner] = balances[owner].sub(numTokens);
        allowed[owner][msg.sender] = allowed[owner][msg.sender].sub(numTokens);
        balances[buyer] = balances[buyer].add(numTokens);
        emit Transfer(owner, buyer, numTokens);
        return true;
    }
}