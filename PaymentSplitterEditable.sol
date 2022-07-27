// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PaymentSplitterEditable is Ownable {
    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);

    struct Shareholder {
        address addr;
        uint8 share;
        uint256 released;
    }

    mapping(uint256 => Shareholder) public shareholders;
    uint256 noOfShareholders;
    IERC20 token;
  
    constructor(address[] memory shareholdersArr, uint8[] memory shares, IERC20 _token) payable {
        editShareholders(shareholdersArr, shares);
        token = _token;
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
            Address.sendValue(payable(sh.addr), payment);
            emit PaymentReleased(sh.addr, payment);
        }
    }

    function releaseToken(IERC20 _token) external onlyOwner {
        uint256 receivedToken = IERC20(_token).balanceOf(address(this));
        for (uint256 i = 0; i < noOfShareholders; i++) {
            Shareholder storage sh = shareholders[i + 1];
            uint256 tokenPayment = receivedToken * uint256(sh.share) / 100;
            emit PaymentReleased(sh.addr, tokenPayment);
            IERC20(_token).transferFrom(address(this), sh.addr, tokenPayment);
        } 
    }

    function releaseToken() external onlyOwner {
        uint256 receivedToken = token.balanceOf(address(this));
        for (uint256 i = 0; i < noOfShareholders; i++) {
            Shareholder storage sh = shareholders[i + 1];
            uint256 tokenPayment = receivedToken * uint256(sh.share) / 100;
            emit PaymentReleased(sh.addr, tokenPayment);
            token.transferFrom(address(this), sh.addr, tokenPayment);
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

    function changeToken(IERC20 _token) external onlyOwner {
        token = _token;
    }

    function getTokenBalance() public view returns(uint256){
        return token.balanceOf(address(this));
    }

    function getTokenBalance(IERC20 _token) external view returns(uint256){
        return _token.balanceOf(address(this));
    }

    function withdrawEther() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function withdrawToken() external onlyOwner {
        token.transferFrom(address(this), owner(), token.balanceOf(address(this)));
    }

}
