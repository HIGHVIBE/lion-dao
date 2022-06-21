
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";


contract PaymentSplitter is Context {
    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);

    uint256 public _totalReleased;

    mapping(address => uint256) public _shares;
    mapping(address => uint256) public _released;
    address[] public _payees;
  
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

    function release() private{
        uint256 received = address(this).balance;

        for (uint256 i = 0; i < _payees.length; i++) {
            address account = _payees[i];
            uint256 payment = received * _shares[account] / 100;
            _released[_payees[i]] += payment;
            _totalReleased += payment;
            Address.sendValue(payable(account), payment);
            emit PaymentReleased(account, payment);
        }
        
    }

     function _addPayee(address account, uint256 shares_) private {
        require(account != address(0), "PaymentSplitter: account is the zero address");
        require(shares_ > 0, "PaymentSplitter: shares are 0");
        require(_shares[account] == 0, "PaymentSplitter: account already has shares");

        _payees.push(account);
        _shares[account] = shares_;
    }

}