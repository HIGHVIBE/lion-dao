// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PaymentSplitter is Context, Ownable {
    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);

    IERC20 public token;

    mapping(address => uint256) public _shares;
    address[] public _payees;

    constructor(address[] memory payees, uint256[] memory shares, IERC20 _token) payable {
        require(payees.length == shares.length, "PaymentSplitter: payees and shares length mismatch");
        require(payees.length > 0, "PaymentSplitter: no payees");
        uint256 sharesTotal;
        for (uint256 i = 0; i < payees.length; i++) {
            _addPayee(payees[i], shares[i]);
            sharesTotal += shares[i];
        }
        require(sharesTotal == 100, "Shares total should be equal to 100");
        token = _token;
    }

    receive() external payable virtual {
        emit PaymentReceived(_msgSender(), msg.value);
        release();
    }

    function release() private{
        uint256 received = address(this).balance;
        for (uint256 i = 0; i < _payees.length; i++) {
            address account = _payees[i];
            uint256 payment = received * _shares[account] / 100;
            Address.sendValue(payable(account), payment);
            emit PaymentReleased(account, payment);
        } 
    }

    function releaseToken() external onlyOwner {
        uint256 receivedToken = token.balanceOf(address(this));
        for (uint256 i = 0; i < _payees.length; i++) {
            address account = _payees[i];
            uint256 tokenPayment = receivedToken * _shares[account] / 100;
            emit PaymentReleased(account, tokenPayment);
            token.transferFrom(address(this), account, tokenPayment);
        } 
    }

    function releaseToken(IERC20 _token) external onlyOwner {
        uint256 receivedToken = IERC20(_token).balanceOf(address(this));
        for (uint256 i = 0; i < _payees.length; i++) {
            address account = _payees[i];
            uint256 tokenPayment = receivedToken * _shares[account] / 100;
            emit PaymentReleased(account, tokenPayment);
            IERC20(_token).transferFrom(address(this), account, tokenPayment);
        } 
    }

     function _addPayee(address account, uint256 shares) private {
        require(account != address(0), "PaymentSplitter: account is the zero address");
        require(shares > 0, "PaymentSplitter: shares are 0");
        require(_shares[account] == 0, "PaymentSplitter: account already has shares");

        _payees.push(account);
        _shares[account] = shares;
    }

    function changeToken(IERC20 _token) external onlyOwner {
        token = _token;
    }

    function getTokenBalance() external view returns(uint256){
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
