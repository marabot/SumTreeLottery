pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Strings.sol";


contract FalseRandomNumber  {

    mapping (bytes32 => uint) requestIds;
        uint requestCount;

        function getRNGNumber() external returns(bytes32){
          
           uint time= block.timestamp;
           requestIds[bytes32(requestCount)] = time;
           return bytes32(requestCount);
        }

        function getNumberFromID(bytes32  _ID) external view returns(uint){
            bytes32 id= bytes32(abi.encodePacked(_ID));
            return requestIds[id];
        }
}



