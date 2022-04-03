const { time,expectRevert } = require("@openzeppelin/test-helpers");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");

const lotteryContract = artifacts.require('SumTreeLottery.sol');
const RNG = artifacts.require('FalseRandomNumber.sol');




contract('SumTreeLottery' , accounts =>{
    let Lot,Rng;
    const [trader1, trader2, trader3, trader4, trader5]=[accounts[0], accounts[1], accounts[2], accounts[3], accounts[4], accounts[5]];
 
    
    beforeEach(async ()=>{       
       
        Rng = await RNG.new();
        Lot = await lotteryContract.new(Rng.address, (60*60).toString());        
       // const amount = web3.utils.toWei('1000');
      
    })

    it('should return what vaguely look like random numbers', async ()=>{
        let numbers = [];
        for(let i = 0 ;i< 5 ;i++){
            let requestId = await Rng.getRNGNumber();
            let reqIdNum = web3.utils.hexToNumber(web3.utils.bytesToHex(requestId));
            let num = await Rng.getNumberFromID(web3.eth.abi.encodeParameter('uint256', reqIdNum));
            numbers[i]=num;
            await time.increase( 60*3);
            console.log('num : ' + num);
        }
    
        assert(numbers[0]!=numbers[1]);
        assert(numbers[1]!=numbers[2]);
        assert(numbers[2]!=numbers[3]);
        assert(numbers[3]!=numbers[4]);
       
   
}, 'init failed');

    it('should have owner who only could change lottery length and rng contract', async ()=>{


            let owny= await Lot.owner();
           
            let length = await Lot.lotteryLength();
            console.log("1 :" + length);

            await expectRevert(
                Lot.setLotteryLength(200,{from:trader2}),
               'Ownable: caller is not the owner'
             );

            length = await Lot.lotteryLength();
            console.log("2 :" +length);

            await Lot.setLotteryLength(100, {from:owny});

            length = await Lot.lotteryLength();
            console.log("3 :" +length);
            assert(length.toNumber()==100);
           
       // assert(cLot.endtime == Date.now() + Date.h);
    }, 'init failed');
  

    /// test is passing if run only this, but not when all tests are launched
    it('should have create lottery at creation', async ()=>{
     
        const cLot = await Lot.getCurrentLottery();
        
        const cLotEndtime= cLot.endTime;
      
       
        let currentTimePlus1H= new Date();
        currentTimePlus1H.setTime(Date.now() + 60*60*1000);
       
        console.log(cLot);
        console.log(cLotEndtime);
        console.log(currentTimePlus1H.getTime());

        console.log(Date(cLotEndtime*1000));
        console.log(Date(currentTimePlus1H.getTime()));


        /// +3 et - 3 pour comparer endtime car on n'a pas la date de creation précise
        assert(cLotEndtime < currentTimePlus1H.getTime()/1000+3 && cLotEndtime> currentTimePlus1H.getTime()/1000-3,"End of the lottery incorrect");
        assert(cLot.sumTree_key == web3.eth.abi.encodeParameter('int256', String(0)));
       // assert(cLot.endtime == Date.now() + Date.h);
    }, 'init failed');


    it('should wage current lottery', async ()=>{
      
        const depositvalue= web3.utils.toWei('14');

        await Lot.deposit({from:trader1,value:depositvalue});
        let stake = await Lot.getStake(trader1);
        assert(web3.utils.fromWei(stake)==14, "1st deposit value wrong");
        console.log(web3.utils.fromWei(stake));
       
        await Lot.deposit({from:trader1,value:depositvalue});    
        stake = await Lot.getStake(trader1); 
        assert(web3.utils.fromWei(stake)==28, "2nd deposit value wrong");
    
        console.log(web3.utils.fromWei(stake));

        console.log(stake);
   
        const cLot = await Lot.getCurrentLottery();
        console.log(cLot.endTime);      
        
    }, 'wage failed');


    it('should choose a winner and send prizepool', async ()=>{
      
        const depositvalue= web3.utils.toWei('10');
        const depositvalue2= web3.utils.toWei('20');
        
        await Lot.deposit({from:trader1,value:depositvalue}); 
        await Lot.deposit({from:trader2,value:depositvalue2});

        let lotBalance= await  web3.eth.getBalance(Lot.address);
        let trader1Balance = await web3.eth.getBalance(trader1);
        console.log("lot :" + Math.round(web3.utils.fromWei(lotBalance)));
        console.log("trader1 :" + Math.round(web3.utils.fromWei(trader1Balance)));

        const cLot = await Lot.getCurrentLottery();
        const endtime = cLot.endTime;
        //console.log(endtime.toNumber());
        let lat= await time.latest();
        console.log("endtime : " + endtime);
        console.log(lat.toNumber());
    
        let currentTimePlus10min= new Date();
        currentTimePlus10min.setTime(Date.now() + 60*60*1000);
        await time.increase( 60*60*3);
        
       let betRet3 =  await Lot.deposit({from:trader3,value:depositvalue2});
       console.log('betRet3 :' + web3.utils.hexToNumber(web3.utils.bytesToHex(betRet3)));
       //let betRet3_1 = await web3.utils.toAscii(betRet3[0]);


        lotBalance= await  web3.eth.getBalance(Lot.address);
        trader1Balance = await web3.eth.getBalance(trader1);

        let trader2Balance = await web3.eth.getBalance(trader2);
        console.log("lot :" + Math.round(web3.utils.fromWei(lotBalance)));
        console.log("trader1 :" + Math.round(web3.utils.fromWei(trader1Balance)));
        console.log("trader2 :" + Math.round(web3.utils.fromWei(trader2Balance)));

        let stake = await Lot.getStake(trader3); 
        console.log(web3.utils.fromWei(stake));
        // assert(web3.utils.fromWei(stake)==28, "2nd deposit value wrong");
        lat= await time.latest();
        console.log(lat.toNumber());
        console.log("done");
        
    }, 'wage failed');
}



);



function numStringToBytes32(num) { 
    var bn = new BN(num).toTwos(256);
    return padToBytes32(bn.toString(16));
 }