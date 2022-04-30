// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";


contract PaymentSplitter is Context {
    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);

    mapping(address => uint256) private _shares;
    address[] private _payees;

    
    constructor(address[] memory payees, uint256[] memory shares_) payable {
        require(payees.length == shares_.length, "PaymentSplitter: payees and shares length mismatch");
        require(payees.length > 0, "PaymentSplitter: no payees");
        
        for (uint256 i = 0; i < payees.length; i++) {
            _addPayee(payees[i], shares_[i]);
        }

    }

    receive() external payable virtual {
        emit PaymentReceived(_msgSender(), msg.value);
        release();
    }
    
    function shares(address account) public view returns (uint256) {
        return _shares[account];
    }

    function payee(uint256 index) public view returns (address) {
        return _payees[index];
    }

    function release() private{
         for (uint256 i = 0; i < _payees.length; i++) {
            address account = _payees[i];
            uint256 payment = _pendingPayment(account);
            require(payment != 0, "PaymentSplitter: Payment is not available yet.");

            Address.sendValue(payable(account), payment);
            emit PaymentReleased(account, payment);
        }
        
    }

    function _pendingPayment(
        address account
    ) private view returns (uint256) {
        return (address(this).balance * _shares[account]) / 100 ;
    }

    
    function _addPayee(address account, uint256 shares_) private {
        require(account != address(0), "PaymentSplitter: account is the zero address");
        require(shares_ > 0, "PaymentSplitter: shares are 0");
        require(_shares[account] == 0, "PaymentSplitter: account already has shares");

        _payees.push(account);
        _shares[account] = shares_;
    }
}