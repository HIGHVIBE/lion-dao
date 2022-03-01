// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

///
/// @dev Interface for the NFT Royalty Standard
///
interface IEIP2981 {
    /// ERC165 bytes to add to interface array - set in parent contract
    /// implementing this standard
    ///
    /// bytes4(keccak256("royaltyInfo(uint256,uint256)")) == 0x2a55205a

    /// @notice Called with the sale price to determine how much royalty
    //          is owed and to whom.
    /// @param _tokenId - the NFT asset queried for royalty information
    /// @param _salePrice - the sale price of the NFT asset specified by _tokenId
    /// @return receiver - address of who should be sent the royalty payment
    /// @return royaltyAmount - the royalty payment amount for _salePrice
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns (address receiver,uint256 royaltyAmount);
}

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/introspection/ERC165.sol';
import '@openzeppelin/contracts/access/Ownable.sol';



contract EIP2981 is IEIP2981, ERC165 {

    address internal royaltyAddr;
    uint256 internal royaltyPerc; // percentage in basis (out of 10,000)

    /**
    *   @notice constructor
    *   @dev need inheriting contracts to accept the parameters in their constructor
    *   @param addr is the royalty payout address
    *   @param perc is the royalty percentage, multiplied by 1000. Ex: 7.5% => 750
    */
    constructor(address addr, uint256 perc) {
        royaltyAddr = addr;
        royaltyPerc = perc;
    }

    /**
    *   @notice override ERC 165 implementation of this function
    *   @dev if using this contract with another contract that suppports ERC 265, will have to override in the inheriting contract
    */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return interfaceId == type(IEIP2981).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
    *   @notice EIP 2981 royalty support
    *   @dev royalty payout made to the owner of the contract and the owner can't be the 0 address
    *   @dev royalty amount determined when contract is deployed, and then divided by 1000 in this function
    *   @dev royalty amount not dependent on _tokenId
    */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        require(royaltyAddr != address(0));
        return (royaltyAddr, royaltyPerc * _salePrice / 10000);
    }
}

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension and the Enumerable extension
 *
 * @dev Only allows token IDs are minted serially starting from token ID 1
 *
 * @dev Does not support burning tokens or in any way changing the ownership of a token
 *      to address(0)
 */
contract ERC721X is Context, ERC165, IERC721, IERC721Metadata, IERC721Enumerable {
  using Address for address;
  using Strings for uint256;

  // Token name
  string private _name;

  // Token symbol
  string private _symbol;

  // Mapping from token ID to owner address
  mapping(uint256 => address) private _owners;

  // Mapping from token ID to approved address
  mapping(uint256 => address) private _tokenApprovals;

  // Mapping from owner to operator approvals
  mapping(address => mapping(address => bool)) private _operatorApprovals;

  /**
   * @dev Returns next token ID to be mint
   */
  uint256 public nextId = 1;

  /**
   * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection. It
   *      also sets a `maxTotalSupply` variable to cap the tokens to ever be created
   */
  constructor(string memory name_, string memory symbol_) {
    _name = name_;
    _symbol = symbol_;
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
    return
      interfaceId == type(IERC721).interfaceId ||
      interfaceId == type(IERC721Metadata).interfaceId ||
      interfaceId == type(IERC721Enumerable).interfaceId ||
      super.supportsInterface(interfaceId);
  }

  /**
   * @dev See {IERC721-balanceOf}.
   */
  function balanceOf(address owner) public view virtual override returns (uint256) {
    require(owner != address(0), "ERC721X: balance query for the zero address");

    uint256 count = 0;

    for(uint256 i = 1; _exists(i); i++) {
      if(_owners[i] == owner) {
        count++;
        if(_owners[i + 1] == address(0) && _exists(i + 1)) count++;
      }
    }

    return count;
  }

  /**
   * @dev See {IERC721-ownerOf}.
   */
  function ownerOf(uint256 tokenId) public view virtual override returns (address) {
    require(_exists(tokenId), "ERC721X: owner query for nonexistent token");

    return _owners[tokenId] != address(0) ? _owners[tokenId] : _owners[tokenId - 1];
  }

  /**
   * @dev See {IERC721Metadata-name}.
   */
  function name() public view virtual override returns (string memory) {
    return _name;
  }

  /**
   * @dev See {IERC721Metadata-symbol}.
   */
  function symbol() public view virtual override returns (string memory) {
    return _symbol;
  }

  /**
   * @dev See {IERC721Metadata-tokenURI}.
   */
  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

    string memory baseURI = _baseURI();
    return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
  }

  /**
   * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
   * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
   * by default, can be overriden in child contracts.
   */
  function _baseURI() internal view virtual returns (string memory) {
    return "";
  }

  /**
   * @dev See {IERC721-approve}.
   */
  function approve(address to, uint256 tokenId) public virtual override {
    address owner = ownerOf(tokenId);
    require(to != owner, "ERC721X: approval to current owner");

    require(
      _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
      "ERC721X: approve caller is not owner nor approved for all"
    );

    _approve(to, tokenId);
  }

  /**
   * @dev See {IERC721-getApproved}.
   */
  function getApproved(uint256 tokenId) public view virtual override returns (address) {
    require(_exists(tokenId), "ERC721X: approved query for nonexistent token");

    return _tokenApprovals[tokenId];
  }

  /**
   * @dev See {IERC721-setApprovalForAll}.
   */
  function setApprovalForAll(address operator, bool approved) public virtual override {
    _setApprovalForAll(_msgSender(), operator, approved);
  }

  /**
   * @dev See {IERC721-isApprovedForAll}.
   */
  function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
    return _operatorApprovals[owner][operator];
  }

  /**
   * @dev See {IERC721-transferFrom}.
   */
  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    //solhint-disable-next-line max-line-length
    require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721X: transfer caller is not owner nor approved");

    _transfer(from, to, tokenId);
  }

  /**
   * @dev See {IERC721-safeTransferFrom}.
   */
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    safeTransferFrom(from, to, tokenId, "");
  }

  /**
   * @dev See {IERC721-safeTransferFrom}.
   */
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes memory _data
  ) public virtual override {
    require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721X: transfer caller is not owner nor approved");
    _safeTransfer(from, to, tokenId, _data);
  }

  /**
   * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
   * are aware of the ERC721 protocol to prevent tokens from being forever locked.
   *
   * `_data` is additional data, it has no specified format and it is sent in call to `to`.
   *
   * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
   * implement alternative mechanisms to perform token transfer, such as signature-based.
   *
   * Requirements:
   *
   * - `from` cannot be the zero address.
   * - `to` cannot be the zero address.
   * - `tokenId` token must exist and be owned by `from`.
   * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
   *
   * Emits a {Transfer} event.
   */
  function _safeTransfer(
    address from,
    address to,
    uint256 tokenId,
    bytes memory _data
  ) internal virtual {
    _transfer(from, to, tokenId);
    require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721X: transfer to non ERC721Receiver implementer");
  }

  /**
   * @dev Returns whether `tokenId` exists.
   *
   * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
   *
   * Tokens start existing when they are minted (`_mint`).
   */
  function _exists(uint256 tokenId) internal view virtual returns (bool) {
    return tokenId != 0 && tokenId < nextId;
  }

  /**
   * @dev Returns whether `spender` is allowed to manage `tokenId`.
   *
   * Requirements:
   *
   * - `tokenId` must exist.
   */
  function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
    require(_exists(tokenId), "ERC721X: operator query for nonexistent token");
    address owner = ownerOf(tokenId);
    return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
  }

  /**
   * @dev Safely mints the token with next consecutive ID and transfers it to `to`. Setting
   *      `amount` to `true` will mint another nft.
   *
   * Requirements:
   *
   * - `tokenId` must not exist.
   * - `maxTotalSupply` maximum total supply has not been reached
   * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
   *
   * Emits a {Transfer} event.
   */
  function _safeMint(address to, bool amount) internal virtual {
    _safeMint(to, amount, "");
  }

  /**
   * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
   * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
   */
  function _safeMint(
    address to,
    bool amount,
    bytes memory _data
  ) internal virtual {
    _mint(to, amount);

    uint256 n = !amount ? 1 : 2;

    for(uint256 i = 0; i < n; i++) {
      require(
        _checkOnERC721Received(address(0), to, nextId - i - 1, _data),
        "ERC721X: transfer to non ERC721Receiver implementer"
      );
    }
  }

  /**
   * @dev Mints the token with next consecutive ID and transfers it to `to`. Setting
   *      `amount` to `true` will mint another nft.
   *
   * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
   *
   * Requirements:
   *
   * - `to` cannot be the zero address.
   * - `maxTotalSupply` maximum total supply has not been reached
   *
   * Emits a {Transfer} event.
   */
  function _mint(address to, bool amount) internal virtual {
    // The below calculations do not depend on user input and
    // are very hard to overflow (nextId must be >= 2^256-2 for
    // that to happen) so using `unchecked` as a means of saving
    // gas is safe here
    unchecked {
      require(to != address(0), "ERC721X: mint to the zero address");

      uint256 n = !amount ? 1 : 2;

      _owners[nextId] = to;

      for(uint256 i = 0; i < n; i++) {
        _beforeTokenTransfer(address(0), to, nextId + i);
        emit Transfer(address(0), to, nextId + i);
      }

      nextId += n;
    }
  }

  /**
   * @dev Transfers `tokenId` from `from` to `to`.
   *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
   *
   * Requirements:
   *
   * - `to` cannot be the zero address.
   * - `tokenId` token must be owned by `from`.
   *
   * Emits a {Transfer} event.
   */
  function _transfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual {
    // The below calculations are very hard to overflow (nextId must
    // be = 2^256-1 for that to happen) so using `unchecked` as
    // a means of saving gas is safe here
    unchecked {
      require(
        ownerOf(tokenId) == from,
        "ERC721X: transfer of token that is not own"
      );
      require(to != address(0), "ERC721X: transfer to the zero address");

      _beforeTokenTransfer(from, to, tokenId);

      // Clear approvals from the previous owner
      _approve(address(0), tokenId);

      if(_owners[tokenId] == address(0)) {
        _owners[tokenId] = to;
      } else {
        _owners[tokenId] = to;

        if(_owners[tokenId + 1] == address(0)) {
          _owners[tokenId + 1] = from;
        }
      }

      emit Transfer(from, to, tokenId);
    }
  }

  /**
   * @dev Approve `to` to operate on `tokenId`
   *
   * Emits a {Approval} event.
   */
  function _approve(address to, uint256 tokenId) internal virtual {
    _tokenApprovals[tokenId] = to;
    emit Approval(ownerOf(tokenId), to, tokenId);
  }

  /**
   * @dev Approve `operator` to operate on all of `owner` tokens
   *
   * Emits a {ApprovalForAll} event.
   */
  function _setApprovalForAll(
    address owner,
    address operator,
    bool approved
  ) internal virtual {
    require(owner != operator, "ERC721X: approve to caller");
    _operatorApprovals[owner][operator] = approved;
    emit ApprovalForAll(owner, operator, approved);
  }

  /**
   * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
   * The call is not executed if the target address is not a contract.
   *
   * @param from address representing the previous owner of the given token ID
   * @param to target address that will receive the tokens
   * @param tokenId uint256 ID of the token to be transferred
   * @param _data bytes optional data to send along with the call
   * @return bool whether the call correctly returned the expected magic value
   */
  function _checkOnERC721Received(
    address from,
    address to,
    uint256 tokenId,
    bytes memory _data
  ) private returns (bool) {
    if (to.isContract()) {
      try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
        return retval == IERC721Receiver.onERC721Received.selector;
      } catch (bytes memory reason) {
        if (reason.length == 0) {
          revert("ERC721X: transfer to non ERC721Receiver implementer");
        } else {
          assembly {
            revert(add(32, reason), mload(reason))
          }
        }
      }
    } else {
      return true;
    }
  }

  /**
   * @dev Hook that is called before any token transfer. This includes minting
   * and burning.
   *
   * Calling conditions:
   *
   * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
   * transferred to `to`.
   * - When `from` is zero, `tokenId` will be minted for `to`.
   * - When `to` is zero, ``from``'s `tokenId` will be burned.
   * - `from` and `to` are never both zero.
   *
   * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual {}

  /**
   * @dev See {IEnumerableERC721-totalSupply}.
   */
  function totalSupply() external view returns (uint256) {
    return nextId - 1;
  }

  /**
   * @dev See {IEnumerableERC721-tokenByIndex}.
   */
  function tokenByIndex(uint256 index) external view returns (uint256) {
    require(_exists(index + 1), "ERC721X: global index out of bounds");

    return index + 1;
  }

  /**
   * @dev See {IEnumerableERC721-tokenOfOwnerByIndex}.
   */
  function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256) {
    require(owner != address(0), "ERC721X: balance query for the zero address");

    uint256 count = 0;
    uint256 i = 1;

    for(; _exists(i) && count < index + 1; i++) {
      if(_owners[i] == owner) {
        count++;
        if(_owners[i + 1] == address(0) && count < index + 1 && _exists(i + 1)) {
          count++;
          i++;
        }
      }
    }

    if(count == index + 1) return i - 1;
    else revert("ERC721X: owner index out of bounds");
  }
}



contract GENERATIVE is ERC721X, EIP2981, Ownable {
   using Strings for uint256;

    string baseURI;
    uint256 public maxTotalSupply = 3333;
    uint256 public whitelistCost = 0.0555 ether;
    uint256 public preSaleCost = 0.0888 ether;
    uint256 public publicSaleCost = 0.111 ether;
    bool public paused = false;
    bool public revealed = false;
    string public notRevealedUri;
    uint256 public whitelistAddressLimit = 1;
    uint256 public preSaleAddressLimit = 1;
    uint256 public publicSaleAddressLimit = 1;
    bool public whitelistSale = true;
    bool public preSale = false;
    bool public publicSale = false;
    mapping(address => uint256) public addressMintedBalance;
    bytes32 private whitelistSaleRootHash;
    bytes32 private preSaleRootHash;
    uint256 public immutable maxAdminMint = 100;
    uint256 public adminMintCount = 0;



    constructor(string memory _initNotRevealedUri, string memory _initBaseURI, address _royaltyRecipient, uint256 _royaltyAmount) EIP2981(_royaltyRecipient, _royaltyAmount) ERC721X("GENERATIVE", "GEN") Ownable() {
            setNotRevealedURI(_initNotRevealedUri);
            setBaseURI(_initBaseURI);
    }
    
    function _baseURI() internal view virtual override returns (string memory) {
     return baseURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
      baseURI = _newBaseURI;
     }

    function supportsInterface(bytes4 _interfaceId) public view virtual override(ERC721X, EIP2981) returns (bool) {
        return super.supportsInterface(_interfaceId);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );
    
    if(revealed == false) {
        return notRevealedUri;
    }

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), ".json"))
        : "";
  }
    

  function mint(bool _amount, bytes32[] calldata proof) public payable {
    uint256 n = !_amount ? 1 : 2;

    require(nextId <= maxTotalSupply - maxAdminMint, "not enough tokens");
    require(addressMintedBalance[msg.sender] + n <= 2, "mint limit reached");
    require(!paused, "the contract is paused");
    require(msg.value >= whitelistCost * n, "Not enough ETH sent: check whitelist price.");


    if (msg.sender != owner()) {
        if(whitelistSale) {
            require(verifyWhitelisted(keccak256(abi.encodePacked(msg.sender)), proof), "User is not whitelisted!");
            uint256 ownerMintedCount = addressMintedBalance[msg.sender];
            require(ownerMintedCount + n <= whitelistAddressLimit, "max NFT per whitelist address exceeded");
            require(msg.value >= whitelistCost * n, "Not enough ETH sent: check whitelist price.");
        } 
        if(preSale){
            require(verifyPreSaleListed(keccak256(abi.encodePacked(msg.sender)), proof), "User is not presalelisted!");
            uint256 ownerMintedCount = addressMintedBalance[msg.sender];
            require(ownerMintedCount + n <= preSaleAddressLimit, "max NFT per prelist address exceeded");
            require(msg.value >= preSaleCost * n, "Not enough ETH sent: check presale price.");
        }
        if(publicSale){
            uint256 ownerMintedCount = addressMintedBalance[msg.sender];
            require(ownerMintedCount + n <= publicSaleAddressLimit, "max NFT per address exceeded");
            require(msg.value >= publicSaleCost * n, "Not enough ETH sent: check public price.");
        }
    }

        addressMintedBalance[msg.sender] += n;
        _mint(msg.sender, _amount);
  }
    function adminMint(address _to, bool _amount) public onlyOwner {
        uint256 n = !_amount ? 1 : 2;

        adminMintCount += n;

        require(nextId <= maxTotalSupply && adminMintCount <= maxAdminMint, "not enough tokens");

         _mint(_to, _amount);
  }

    function verifyWhitelisted(bytes32 leaf, bytes32[] memory proof) internal view returns (bool)
  {
    bytes32 computedHash = leaf;

    for (uint256 i = 0; i < proof.length; i++) {
      bytes32 proofElement = proof[i];

      if (computedHash <= proofElement) {
        computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
      } else {
        computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
      }
    }

    return computedHash == whitelistSaleRootHash;
  }

  function verifyPreSaleListed(bytes32 leaf, bytes32[] memory proof) internal view returns (bool)
  {
    bytes32 computedHash = leaf;

    for (uint256 i = 0; i < proof.length; i++) {
      bytes32 proofElement = proof[i];

      if (computedHash <= proofElement) {
        computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
      } else {
        computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
      }
    }

    return computedHash == preSaleRootHash;
  }

  function setWhitelistSaleRootHash(bytes32 _hash) public onlyOwner {
    whitelistSaleRootHash = _hash;
  }
  function setPreSaleRootHash(bytes32 _hash) public onlyOwner {
    preSaleRootHash = _hash;
  }

  function setwhitelistAddressLimit(uint256 _limit) public onlyOwner {
    whitelistAddressLimit = _limit;
  }
  function setpreSaleAddressLimit(uint256 _limit) public onlyOwner {
    preSaleAddressLimit = _limit;
  }
  function setpublicSaleAddressLimit(uint256 _limit) public onlyOwner {
    publicSaleAddressLimit = _limit;
  }

  function setMaxTotalSupply(uint256 _supply) public onlyOwner {
    maxTotalSupply = _supply;
  }

  function setWhitelistSale(bool _state) public onlyOwner {
    whitelistSale = _state;
  }
  function setPreSale(bool _state) public onlyOwner {
    preSale = _state;
  }
  function setPublicSale(bool _state) public onlyOwner {
    publicSale = _state;
  }

  function startPreSale() public onlyOwner {
    whitelistSale = false;
    preSale = true;
  }

  function startPublicSale() public onlyOwner {
    whitelistSale = false;
    preSale = false;
    publicSale = true;
  }

  function reveal(bool _state) public onlyOwner() {
      revealed = _state;
  }

  function pause(bool _state) public onlyOwner {
    paused = _state;
  }
  
  function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
    notRevealedUri = _notRevealedURI;
  }
 
  function setwhitelistCost(uint256 _newCost) public onlyOwner() {
    whitelistCost = _newCost;
  }
  function setpreSaleCost(uint256 _newCost) public onlyOwner() {
    preSaleCost = _newCost;
  }
  function setpublicSaleCost(uint256 _newCost) public onlyOwner() {
    publicSaleCost = _newCost;
  }
  
  function withdraw() public payable onlyOwner {
    (bool success, ) = payable(owner()).call{value: address(this).balance}("");
    require(success);
  }

  function changeRoyaltyRecipient(address _newRecipient) public onlyOwner {
        require(_newRecipient != address(0), "Error: new recipient is the zero address");
        royaltyAddr = _newRecipient;
    }


  function changeRoyaltyPercentage(uint256 _newPerc) public onlyOwner {
        require(_newPerc <= 10000, "Error: new percentage is greater than 10,0000");
        royaltyPerc = _newPerc;
    }


}