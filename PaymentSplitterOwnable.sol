// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
  
    constructor(address[] memory payees, uint8[] memory shares_) payable {
        require(payees.length == shares_.length, "PaymentSplitter: payees and shares length mismatch");
        require(payees.length > 0, "PaymentSplitter: no payees");
        
        for (uint256 i = 0; i < payees.length; i++) {
            addShareholder(payees[i], shares_[i]);
        }
    }

    receive() external payable virtual {
        emit PaymentReceived(_msgSender(), msg.value);
        uint256 sharesTotal;
        for(uint256 i = 0; i < noOfShareholders; i++){
            sharesTotal += shareholders[i+1].share;
        }
        if(sharesTotal == 100){ // what if get payment while editing shareholders
            release(); 
        } 
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

    function addShareholder(address _addr, uint8 _share) public onlyOwner {
        require(_addr != address(0), "PaymentSplitter: account is the zero address");
        require(_share > 0, "PaymentSplitter: shares are 0");
        noOfShareholders += 1;
        shareholders[noOfShareholders] = Shareholder(_addr, _share, 0);
    }

    function editShareholder(address addr, uint8 share) external onlyOwner {
        uint256 idx;
        for(uint256 i = 0; i < noOfShareholders; i++){
            if(shareholders[i + 1].addr == addr) idx = i + 1;
        }
        if (idx == 0) revert("No shareholder with given address was found");
        Shareholder storage sh = shareholders[idx];
        sh.share = share;
    }

    function deleteShareholder(address addr) external onlyOwner {
        uint256 idx;
        for(uint256 i = 0; i < noOfShareholders; i++){
            if(shareholders[i + 1].addr == addr) idx = i + 1;
        }
        if (idx == 0) revert("No shareholder with given address was found");
        for(uint256 i = idx; i < noOfShareholders; i++){
            shareholders[i] = shareholders[i + 1];
        }
        delete shareholders[noOfShareholders];
        noOfShareholders -= 1;
    }

    function releaseAsOwner() external onlyOwner {
        uint256 sharesTotal;
        for(uint256 i = 0; i < noOfShareholders; i++){
            sharesTotal += shareholders[i+1].share;
        }
        if(sharesTotal == 100){ // what if get payment while editing shareholders
            release(); 
        } 
    }

}