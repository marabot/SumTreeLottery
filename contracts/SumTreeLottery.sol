// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./SortitionSumTreeFactory.sol";
import "./FalseRandomNumber.sol";

/// @author Antoine Charcosset
/// @title lottery using SumTree
contract SumTreeLottery is Ownable, Pausable {
        
    uint public lotteryLength;              // The duration of a lottery, in seconds
    address public rng;                     // address of the RngNumber contract
    FalseRandomNumber Rngcontract;          // RngNumber contracts
    uint lotteriesCount;                    // Count of lottery, use as key for new lottery
    uint UserIdCount;                       // Count of user, use as ID for new User (1 address <=> 1 user)
    bytes32 public currentLottery;          // Key of the lottery currently opened
    
    //mapping lotteries
    mapping(bytes32 => Lottery) public lotteries;               // lotteries struct by key
    mapping(address => bytes32) sumTreeIdByAddress;             // UserID in sumTree by address
    mapping(bytes32 => address) addressBySumTreeId;             // address by userId in sumTree
    SortitionSumTreeFactory.SortitionSumTrees lotterieTrees;    // storage struct containing lottery sumTrees by key

    struct Lottery {            
        bytes32 sumTree_key;            // Key of the lottery sumTree
        uint endTime;                   // end time of the lottery as timestamp in seconds
    }

    /**
    *  @param _rngContract The contract that will provide a random number
    *  @param _lotteryLength The duration of a lottery, in seconds
    */
    constructor(address _rngContract, uint _lotteryLength) {
        lotteryLength = _lotteryLength ;
        rng=_rngContract;
        Rngcontract = FalseRandomNumber(rng);            
        UserIdCount = 1;
        newLottery();
    }

    /**
    *  @dev put money in the current lottery. if the current lottery is closed, open an new lottery.
    *       amount of the deposit is msg.value  
    */  
    function deposit() payable external whenNotPaused returns(bytes32) {
        uint newValue = msg.value;

        // update if Lottery closed
        if(lotteries[currentLottery].endTime < block.timestamp)
        {         
            bytes32 ret = update();   
            return ret;
        }

        /// si l'utilisateur n'a pas déjà un ID suite à un dépot précedent
        if(sumTreeIdByAddress[msg.sender] == 0) {
            sumTreeIdByAddress[msg.sender] = bytes32(UserIdCount);
            addressBySumTreeId[bytes32(UserIdCount)] = msg.sender;
            UserIdCount++;
        } else
        {                
            uint stake = SortitionSumTreeFactory.stakeOf(lotterieTrees, currentLottery, sumTreeIdByAddress[msg.sender]);
            newValue = newValue + stake;   
        }
        SortitionSumTreeFactory.set(lotterieTrees, currentLottery, newValue, sumTreeIdByAddress[msg.sender]);     
        return "BET";
    }

    /**
    *  @dev set a new value for lotteryLength   
    *  @param newLength  new value of the duration of a lottery  in seconds
    */  
    function setLotteryLength(uint newLength) payable external onlyOwner {
        lotteryLength = newLength;
    }     

    /**
    *  @dev set a new value for the address of the RngContract, and initiate a new Rng contract with this address   
    *  @param newAdress  new value of the duration of a lottery  in seconds
    */  
    function setRngContract(address newAdress) external onlyOwner{
            rng = newAdress;
            Rngcontract= FalseRandomNumber(newAdress);
    }

    /**
    *  @dev return the stake associate to an address   
    *  @param staker  address of the user
    */  
    function getStake(address staker) external view returns (uint) {
        bytes32 stakerID = sumTreeIdByAddress[staker];
        uint stake = SortitionSumTreeFactory.stakeOf(lotterieTrees, currentLottery, stakerID);
        return stake;
    }

    /**
    *  @dev return the lottery struct associate to a key  
    *  @param key  key of the lottery
    */  
    function getLottery(bytes32 key)external view returns (Lottery memory) {
        return  lotteries[key];
    }

    /**
    *  @dev return the current lottery struct    
    */  
    function getCurrentLottery() external view returns (Lottery memory) {
        return  lotteries[currentLottery];
    }

    /**
    *  @dev return the end time of the current lottery as timestamp in seconds    
    */  
    function getCurrentLotteryEndTime() external view returns (uint) {
        return lotteries[currentLottery].endTime; 
    }

    /**
    *  @dev create a new lottery, set it as current lottery, and return the key   
    */  
    function newLottery() internal returns (bytes32) {        
        bytes32 key = bytes32(lotteriesCount);
        Lottery storage lot = lotteries[key];

        require (lot.endTime == 0,"existe deja");
       
        lot.sumTree_key = key;
        lot.endTime= block.timestamp + lotteryLength;               
        SortitionSumTreeFactory.createTree(lotterieTrees, key, 2);
        currentLottery = key;
        lotteriesCount++;

        return key;
    }
      
    /**
    *  @dev _pause the contract, retrieve a random number by calling RngContract,
    *       let in pause if retrieved number is 0
    *       if not, call draw function of SortitionSumTreeFactory to get winner ID
    *       try to send totat amount of the lottery to the winner,
    *       let in pause if fail, if not, create a new lottery 
    *       return winner ID
    */   
    function update() internal returns(bytes32 ) { 
        _pause();
        ////  TODO make a real random number generator
        bytes32 requestId = Rngcontract.getRNGNumber();        
        uint rngNum = Rngcontract.getNumberFromID(requestId);         

        require(rngNum!=0,"no random number received");
        
        // TODO  add formula to find winner
        bytes32 winnerID = SortitionSumTreeFactory.draw(lotterieTrees, currentLottery, rngNum);

        (bool success, bytes memory data) = addressBySumTreeId[winnerID].call{value:SortitionSumTreeFactory.total(lotterieTrees, currentLottery)}("");
        if (success == false) {
            _pause();
        }else {
            newLottery();
            _unpause();
        }             
       
        return (winnerID);
    }   
}
