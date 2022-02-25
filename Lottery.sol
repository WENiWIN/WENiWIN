//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.7;

import "./Libraries.sol";
import "./Interfaces.sol";
import "./BaseErc20.sol";



contract LotteryWallet {
    
    address private _token;
    
    modifier onlyToken() {
        require(msg.sender == _token, "can only be called by the parent token");
        _;
    }
    
    constructor(address token) {
        _token = token;
    }

    function payWinner(address who) public onlyToken {
        IERC20 token = IERC20(_token);
        token.transfer(who, token.balanceOf(address(this)));
    }
    
}

abstract contract Lottery is BaseErc20 {
    using SafeMath for uint256;
    
    LotteryWallet internal lotteryWallet;
    
    bool public lotteryEnabled = true;
    uint256 public lotteryMinimumSpend;
    uint256 public lotteryThreshold;
    uint256 public lotteryPotPercentage;
    uint256 public lotteryChance;
    uint256 public lotteryCooldown;

    uint256 public lotteryLastWinTime;
    address public lotteryLastWinner;
    uint256 public lotteryLastWinnerPrize;
    
    mapping (address => bool) public excludedFromLottery;

    uint256 private _nonce;

    event LotteryAward(address winner, uint256 amount, uint256 time);
    
    // Overrides
    
    function configure(address _owner) internal virtual override {
        lotteryWallet = new LotteryWallet(address(this));
        excludedFromLottery[_owner] = true;
        super.configure(_owner);
    }
    
    function preTransfer(address from, address to, uint256 value) override virtual internal {
        super.preTransfer(from, to, value);
        
        if(
            lotteryReady() &&
            excludedFromLottery[to] == false && 
            value >= lotteryMinimumSpend && 
            exchanges[from]
        ) {

            uint256 lotteryTokens = balanceOf(lotteryWalletAddress());
            if (lotteryTokens >= lotteryThreshold) {
                uint256 roll = random(lotteryChance); 
                if(roll == 1) {
                    // We won the lottery!
                    lotteryTokens = lotteryTokens.mul(lotteryPotPercentage).div(1000);
                    lotteryLastWinTime = block.timestamp;
                    lotteryLastWinner = to;
                    lotteryLastWinnerPrize = lotteryTokens;
                    lotteryWallet.payWinner(to);
                    emit LotteryAward(to, lotteryTokens, block.timestamp);
                }
            } 
        }
    }
    
    
    // public methods
    
    function lotteryWalletAddress() public view returns (address) {
        return address(lotteryWallet);
    }

    function lotteryReady() public virtual view returns (bool) {
        
        if (launched && lotteryEnabled && block.timestamp - lotteryLastWinTime >= lotteryCooldown) { 
            return true;
        }

        return false;
    }


    // Admin methods
    
    function setLotteryEnabled(bool enabled) external onlyOwner {
        lotteryEnabled = enabled;
    }
    
    function setIsLotteryExempt(address who, bool enabled) external onlyOwner {
        excludedFromLottery[who] = enabled;
    }
    
    function setLotteryMinimumSpend(uint256 minimumSpend) external onlyOwner {
        lotteryMinimumSpend = minimumSpend;
    }
    
    function setLotteryThreshold(uint256 threshold) external onlyOwner {
        lotteryThreshold = threshold;
    }

    function setLotteryPotPercentage(uint256 percentage) external onlyOwner {
        lotteryPotPercentage = percentage;
    }
    
    function setLotteryChance(uint256 chance) external onlyOwner {
        lotteryChance = chance;
    }
    
    function setLotteryCooldown(uint256 second) external onlyOwner {
        lotteryCooldown = second;
    }
    
    
    // private methods
        
    /**
     * @notice Generates a random number between 1 and x
     */
    function random(uint256 x) private returns (uint) {
        uint r = uint(uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _nonce))) % x);
        r = r.add(1);
        _nonce++;
        return r;
    }
}
