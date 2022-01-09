// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract LIONDAO is ERC1155, Ownable, ERC1155Supply  {
    string public name = "LionDAO - Legend";
    string public symbol = "LGND";
    uint256 public currentSupply = 0;
    uint256 public maxTotalSupply = 111;
    bool public burnable = false;
    event Mint(address account, uint256 id, uint256 amount);
    event Burn(address account, uint256 id, uint256 amount);


    constructor()
        ERC1155("ipfs://QmbhNDXeDSVtHFkFRoGpNFQEgE5CLp1oUwpQfuozzoEF3X")
    {
    }

    function setURI(string memory newuri) private onlyOwner {
        _setURI(newuri);
    }

    function mint(address account, uint256 id, uint256 amount)
        public
        onlyOwner
    {
        require(currentSupply + amount <= maxTotalSupply);
        _mint(account, id, amount, "0x00");
        currentSupply = amount + currentSupply;
        emit Mint(account,id,amount);
    }

    function activateBurn() public onlyOwner() {
      burnable = true;
    }
    function deactivateBurn() public onlyOwner() {
      burnable = false;
    }

    function burn(address account, uint256 id, uint256 amount) public {
         require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        require(
            burnable, "ERC1155: burn is not allowed"
        );
        _burn(account, id, amount);
        currentSupply =  currentSupply - amount;
        emit Burn(account,id,amount);
    }

    function addressBatchMint(address[] memory _to, uint256  id, uint256[] memory amounts)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < _to.length; i++) {           
            require(currentSupply + amounts[i] <= maxTotalSupply);
                    mint(_to[i], id, amounts[i]);
        }

    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}