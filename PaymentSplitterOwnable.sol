// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PaymentSplitterOwnable is Ownable {
    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);

    struct Shareholder {
        address addr;
        uint8 share;
        uint256 released;
    }

    mapping(uint256 => Shareholder) public shareholders;
    uint256 noOfShareholders;
    uint256 public _totalReleased;
  
    constructor(address[] memory shareholdersArr, uint8[] memory shares) payable {
        editShareholders(shareholdersArr, shares);
    }

    receive() external payable virtual {
        emit PaymentReceived(_msgSender(), msg.value);
        release(); 
    }

    function release() private{
        uint256 received = address(this).balance;

        for (uint256 i = 0; i < noOfShareholders; i++) {
            Shareholder storage sh = shareholders[i + 1];
            uint256 payment = received * uint256(sh.share) / 100;
            sh.released += payment;
            _totalReleased += payment;
            Address.sendValue(payable(sh.addr), payment);
            emit PaymentReleased(sh.addr, payment);
        }
    }

    function addShareholder(address _addr, uint8 _share) private onlyOwner {
        require(_addr != address(0), "PaymentSplitter: account is the zero address");
        require(_share > 0, "PaymentSplitter: shares are 0");
        noOfShareholders += 1;
        shareholders[noOfShareholders] = Shareholder(_addr, _share, 0);
    }

    function editShareholders(address[] memory shareholdersArr, uint8[] memory shares) public onlyOwner {
        uint256 oldShareholdersNo = noOfShareholders;
        noOfShareholders = 0;
        require(shareholdersArr.length == shares.length, "PaymentSplitter: shareholdersArr and shares length mismatch");
        require(shareholdersArr.length > 0, "PaymentSplitter: no shareholdersArr");
        uint256 sharesTotal;
        for (uint256 i = 0; i < shareholdersArr.length; i++) {
            addShareholder(shareholdersArr[i], shares[i]);
            sharesTotal += shares[i];
        }
        require(sharesTotal == 100, "Total should be hundred");
        if(noOfShareholders < oldShareholdersNo){
            for(uint i = noOfShareholders + 1; i <= oldShareholdersNo; i ++){
                delete shareholders[i];
            }
        }
    }

}