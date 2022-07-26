// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

/*
# Welcome!
> Lion DAO is a social club cultivating decentralized IP in an evolving storyworld. 
The pantheons of [Highvibe Network](https://www.highvibe.network/). 
Where Web3 meets elevated consciousness. A call to adventure for the benevolent leaders of this present moment.
*/

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
import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';


error ApprovalCallerNotOwnerNorApproved();
error ApprovalQueryForNonexistentToken();
error ApproveToCaller();
error ApprovalToCurrentOwner();
error BalanceQueryForZeroAddress();
error MintedQueryForZeroAddress();
error BurnedQueryForZeroAddress();
error AuxQueryForZeroAddress();
error MintToZeroAddress();
error MintZeroQuantity();
error OwnerIndexOutOfBounds();
error OwnerQueryForNonexistentToken();
error TokenIndexOutOfBounds();
error TransferCallerNotOwnerNorApproved();
error TransferFromIncorrectOwner();
error TransferToNonERC721ReceiverImplementer();
error TransferToZeroAddress();
error URIQueryForNonexistentToken();

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


contract ERC721A is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Compiler will pack this into a single 256bit word.
    struct TokenOwnership {
        // The address of the owner.
        address addr;
        // Keeps track of the start time of ownership with minimal overhead for tokenomics.
        uint64 startTimestamp;
        // Whether the token has been burned.
        bool burned;
    }

    // Compiler will pack this into a single 256bit word.
    struct AddressData {
        // Realistically, 2**64-1 is more than enough.
        uint64 balance;
        // Keeps track of mint count with minimal overhead for tokenomics.
        uint64 numberMinted;
        // Keeps track of burn count with minimal overhead for tokenomics.
        uint64 numberBurned;
        // For miscellaneous variable(s) pertaining to the address
        // (e.g. number of whitelist mint slots used).
        // If there are multiple variables, please pack them into a uint64.
        uint64 aux;
    }

    // The tokenId of the next token to be minted.
    uint256 internal _currentIndex;

    // The number of tokens burned.
    uint256 internal _burnCounter;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to ownership details
    // An empty struct value does not necessarily mean the token is unowned. See ownershipOf implementation for details.
    mapping(uint256 => TokenOwnership) internal _ownerships;

    // Mapping owner address to address data
    mapping(address => AddressData) private _addressData;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _currentIndex = _startTokenId();
    }

    /**
     * To change the starting tokenId, please override this function.
     */
    function _startTokenId() internal view virtual returns (uint256) {
        return 1;
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     * @dev Burned tokens are calculated here, use _totalMinted() if you want to count just minted tokens.
     */
    function totalSupply() public view returns (uint256) {
        // Counter underflow is impossible as _burnCounter cannot be incremented
        // more than _currentIndex - _startTokenId() times
        unchecked {
            return _currentIndex - _burnCounter - _startTokenId();
        }
    }

    /**
     * Returns the total amount of tokens minted in the contract.
     */
    function _totalMinted() internal view returns (uint256) {
        // Counter underflow is impossible as _currentIndex does not decrement,
        // and it is initialized to _startTokenId()
        unchecked {
            return _currentIndex - _startTokenId();
        }
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view override returns (uint256) {
        if (owner == address(0)) revert BalanceQueryForZeroAddress();
        return uint256(_addressData[owner].balance);
    }

    /**
     * Returns the number of tokens minted by `owner`.
     */
    function _numberMinted(address owner) public view returns (uint256) {
        if (owner == address(0)) revert MintedQueryForZeroAddress();
        return uint256(_addressData[owner].numberMinted);
    }

    /**
     * Returns the number of tokens burned by or on behalf of `owner`.
     */
    function _numberBurned(address owner) internal view returns (uint256) {
        if (owner == address(0)) revert BurnedQueryForZeroAddress();
        return uint256(_addressData[owner].numberBurned);
    }

    /**
     * Returns the auxillary data for `owner`. (e.g. number of whitelist mint slots used).
     */
    function _getAux(address owner) internal view returns (uint64) {
        if (owner == address(0)) revert AuxQueryForZeroAddress();
        return _addressData[owner].aux;
    }

    /**
     * Sets the auxillary data for `owner`. (e.g. number of whitelist mint slots used).
     * If there are multiple variables, please pack them into a uint64.
     */
    function _setAux(address owner, uint64 aux) internal {
        if (owner == address(0)) revert AuxQueryForZeroAddress();
        _addressData[owner].aux = aux;
    }

    /**
     * Gas spent here starts off proportional to the maximum mint batch size.
     * It gradually moves to O(1) as tokens get transferred around in the collection over time.
     */
    function ownershipOf(uint256 tokenId) internal view returns (TokenOwnership memory) {
        uint256 curr = tokenId;

        unchecked {
            if (_startTokenId() <= curr && curr < _currentIndex) {
                TokenOwnership memory ownership = _ownerships[curr];
                if (!ownership.burned) {
                    if (ownership.addr != address(0)) {
                        return ownership;
                    }
                    // Invariant:
                    // There will always be an ownership that has an address and is not burned
                    // before an ownership that does not have an address and is not burned.
                    // Hence, curr will not underflow.
                    while (true) {
                        curr--;
                        ownership = _ownerships[curr];
                        if (ownership.addr != address(0)) {
                            return ownership;
                        }
                    }
                }
            }
        }
        revert OwnerQueryForNonexistentToken();
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view override returns (address) {
        return ownershipOf(tokenId).addr;
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
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _baseURI();
        return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : '';
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return '';
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public override {
        address owner = ERC721A.ownerOf(tokenId);
        if (to == owner) revert ApprovalToCurrentOwner();

        if (_msgSender() != owner && !isApprovedForAll(owner, _msgSender())) {
            revert ApprovalCallerNotOwnerNorApproved();
        }

        _approve(to, tokenId, owner);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view override returns (address) {
        if (!_exists(tokenId)) revert ApprovalQueryForNonexistentToken();

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public override {
        if (operator == _msgSender()) revert ApproveToCaller();

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
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
        _transfer(from, to, tokenId, false);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, '');
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
        _transfer(from, to, tokenId, false);
        if (to.isContract() && !_checkContractOnERC721Received(from, to, tokenId, _data)) {
            revert TransferToNonERC721ReceiverImplementer();
        }
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _startTokenId() <= tokenId && tokenId < _currentIndex &&
            !_ownerships[tokenId].burned;
    }

    function _safeMint(address to, uint256 quantity) internal {
        _safeMint(to, quantity, '');
    }

    /**
     * @dev Safely mints `quantity` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called for each safe transfer.
     * - `quantity` must be greater than 0.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(
        address to,
        uint256 quantity,
        bytes memory _data
    ) internal {
        _mint(to, quantity, _data, true);
    }

    /**
     * @dev Mints `quantity` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `quantity` must be greater than 0.
     *
     * Emits a {Transfer} event.
     */
    function _mint(
        address to,
        uint256 quantity,
        bytes memory _data,
        bool safe
    ) internal {
        uint256 startTokenId = _currentIndex;
        if (to == address(0)) revert MintToZeroAddress();
        if (quantity == 0) revert MintZeroQuantity();

        _beforeTokenTransfers(address(0), to, startTokenId, quantity);

        // Overflows are incredibly unrealistic.
        // balance or numberMinted overflow if current value of either + quantity > 1.8e19 (2**64) - 1
        // updatedIndex overflows if _currentIndex + quantity > 1.2e77 (2**256) - 1
        unchecked {
            _addressData[to].balance += uint64(quantity);
            _addressData[to].numberMinted += uint64(quantity);

            _ownerships[startTokenId].addr = to;
            _ownerships[startTokenId].startTimestamp = uint64(block.timestamp);

            uint256 updatedIndex = startTokenId;
            uint256 end = updatedIndex + quantity;

            if (safe && to.isContract()) {
                do {
                    emit Transfer(address(0), to, updatedIndex);
                    if (!_checkContractOnERC721Received(address(0), to, updatedIndex++, _data)) {
                        revert TransferToNonERC721ReceiverImplementer();
                    }
                } while (updatedIndex != end);
                // Reentrancy protection
                if (_currentIndex != startTokenId) revert();
            } else {
                do {
                    emit Transfer(address(0), to, updatedIndex++);
                } while (updatedIndex != end);
            }
            _currentIndex = updatedIndex;
        }
        _afterTokenTransfers(address(0), to, startTokenId, quantity);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
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
        uint256 tokenId,
        bool isLoanTransfer
    ) private {
        TokenOwnership memory prevOwnership = ownershipOf(tokenId);

        bool isApprovedOrOwner = (_msgSender() == prevOwnership.addr ||
            isApprovedForAll(prevOwnership.addr, _msgSender()) ||
            getApproved(tokenId) == _msgSender());

        if(!isLoanTransfer){
            if (!isApprovedOrOwner) revert TransferCallerNotOwnerNorApproved();
        }
        if (prevOwnership.addr != from) revert TransferFromIncorrectOwner();
        if (to == address(0)) revert TransferToZeroAddress();

        _beforeTokenTransfers(from, to, tokenId, 1);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId, prevOwnership.addr);

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        // Counter overflow is incredibly unrealistic as tokenId would have to be 2**256.
        unchecked {
            _addressData[from].balance -= 1;
            _addressData[to].balance += 1;

            _ownerships[tokenId].addr = to;
            _ownerships[tokenId].startTimestamp = uint64(block.timestamp);

            // If the ownership slot of tokenId+1 is not explicitly set, that means the transfer initiator owns it.
            // Set the slot of tokenId+1 explicitly in storage to maintain correctness for ownerOf(tokenId+1) calls.
            uint256 nextTokenId = tokenId + 1;
            if (_ownerships[nextTokenId].addr == address(0)) {
                // This will suffice for checking _exists(nextTokenId),
                // as a burned slot cannot contain the zero address.
                if (nextTokenId < _currentIndex) {
                    _ownerships[nextTokenId].addr = prevOwnership.addr;
                    _ownerships[nextTokenId].startTimestamp = prevOwnership.startTimestamp;
                }
            }
        }

        emit Transfer(from, to, tokenId);
        _afterTokenTransfers(from, to, tokenId, 1);
    }

    function loanRetreiveTransfer(address from, address to, uint256 tokenId, bool isLoanTransfer) internal {
        _transfer(from, to, tokenId, isLoanTransfer);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        TokenOwnership memory prevOwnership = ownershipOf(tokenId);

        _beforeTokenTransfers(prevOwnership.addr, address(0), tokenId, 1);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId, prevOwnership.addr);

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        // Counter overflow is incredibly unrealistic as tokenId would have to be 2**256.
        unchecked {
            _addressData[prevOwnership.addr].balance -= 1;
            _addressData[prevOwnership.addr].numberBurned += 1;

            // Keep track of who burned the token, and the timestamp of burning.
            _ownerships[tokenId].addr = prevOwnership.addr;
            _ownerships[tokenId].startTimestamp = uint64(block.timestamp);
            _ownerships[tokenId].burned = true;

            // If the ownership slot of tokenId+1 is not explicitly set, that means the burn initiator owns it.
            // Set the slot of tokenId+1 explicitly in storage to maintain correctness for ownerOf(tokenId+1) calls.
            uint256 nextTokenId = tokenId + 1;
            if (_ownerships[nextTokenId].addr == address(0)) {
                // This will suffice for checking _exists(nextTokenId),
                // as a burned slot cannot contain the zero address.
                if (nextTokenId < _currentIndex) {
                    _ownerships[nextTokenId].addr = prevOwnership.addr;
                    _ownerships[nextTokenId].startTimestamp = prevOwnership.startTimestamp;
                }
            }
        }

        emit Transfer(prevOwnership.addr, address(0), tokenId);
        _afterTokenTransfers(prevOwnership.addr, address(0), tokenId, 1);

        // Overflow not possible, as _burnCounter cannot be exceed _currentIndex times.
        unchecked {
            _burnCounter++;
        }
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(
        address to,
        uint256 tokenId,
        address owner
    ) private {
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkContractOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
            return retval == IERC721Receiver(to).onERC721Received.selector;
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert TransferToNonERC721ReceiverImplementer();
            } else {
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }

    /**
     * @dev Hook that is called before a set of serially-ordered token ids are about to be transferred. This includes minting.
     * And also called before burning one token.
     *
     * startTokenId - the first token id to be transferred
     * quantity - the amount to be transferred
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, `from`'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, `tokenId` will be burned by `from`.
     * - `from` and `to` are never both zero.
     */
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual {}

    /**
     * @dev Hook that is called after a set of serially-ordered token ids have been transferred. This includes
     * minting.
     * And also called after one token has been burned.
     *
     * startTokenId - the first token id to be transferred
     * quantity - the amount to be transferred
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, `from`'s `tokenId` has been
     * transferred to `to`.
     * - When `from` is zero, `tokenId` has been minted for `to`.
     * - When `to` is zero, `tokenId` has been burned by `from`.
     * - `from` and `to` are never both zero.
     */
    function _afterTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual {}
}

contract GENESIS is ERC721A, EIP2981, Ownable {
   using Strings for uint256;

    string[] levelURI;
    uint256[] levelPeriods;

    uint256 public maxTotalSupply = 3333;
    uint256 public stage1Cost = 0 ether;
    uint256 public stage2Cost = 0 ether;
    uint256 public stage3Cost = 0 ether;
    mapping(address => uint8) public stage1Minted;
    mapping(address => uint8) public mintRight;
    mapping(address => bool) public stage2Minted;
    mapping(address => bool) public stage3Minted;
    bool public paused;
    bool public revealed;
    string public notRevealedUri;
    bool public stage1;
    bool public stage2;
    bool public stage3;
    mapping(uint256 => uint256) public _birthdays;
    mapping(uint256 => uint256) public totalLevels;
    mapping(uint256 => address) public tokenOwnersOnLoan;
    bytes32 private stage2RootHash;
    uint256 public stage1StartTime;
    uint256 public stage2StartTime;

    event LeveledUp(uint256 indexed tokenId);

    constructor(string memory _initNotRevealedUri,
        uint256[] memory _levelPeriods, string[] memory _levelURI, address[] memory minters, uint8[] memory rights,
        bytes32 _stage2RootHash, address _royaltyRecipient, uint256 _royaltyAmount) 
        EIP2981(_royaltyRecipient, _royaltyAmount) ERC721A("Lion DAO Genesis", "GEN") Ownable() {

        notRevealedUri = _initNotRevealedUri;
        stage2RootHash = _stage2RootHash;
        levelPeriods = _levelPeriods;
        levelURI = _levelURI;
        require(levelURI.length == levelPeriods.length, "Lengths should be same");
        setMintingRights(minters, rights);
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override(ERC721A, EIP2981) returns (bool) {
        return super.supportsInterface(_interfaceId);
    }

    function setMintingRights(address[] memory minters, uint8[] memory rights) internal onlyOwner {
        require(minters.length == rights.length, "Lengths should match");
        for(uint i = 0; i < minters.length; i++){
            mintRight[minters[i]] = rights[i];
        }
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );
    
    if(revealed == false) {
        return string(abi.encodePacked(notRevealedUri, tokenId.toString(), ".json"));
    }
    (uint256 currentLevel,) = getLevelInfo(tokenId);
    string memory currentBaseURI;
    uint256 periodCount;
    for(uint256 i = 0; i < levelPeriods.length; i++){
        if(currentLevel >= levelPeriods[i]){
            periodCount = i;
        }
    }
    currentBaseURI = levelURI[periodCount];
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), ".json"))
        : "";
  }

  function mint(bytes32[] calldata proof, uint256 amount) external payable {
    require(!paused, "the contract is paused");
    require(amount > 0, "need to mint at least 1 NFT");
    require(totalSupply() + amount <= maxTotalSupply, "max NFT limit exceeded");
    require(msg.sender == tx.origin, "caller should not be a contract.");

    if(stage1) {
        require(block.timestamp - stage1StartTime <= 3 days, "Stage 1 has timed out");
        require(mintRight[msg.sender] > 0, "No minting rights in stage 1");
        require(stage1Minted[msg.sender] + amount <= mintRight[msg.sender], "Used all minting rights in stage1");
        require(msg.value >= stage1Cost * amount, "Not enough ETH sent: check whitelist price.");
        stage1Minted[msg.sender] += uint8(amount);
    } 
    if(stage2){
        require(amount == 1, "You can only mint one");
        require(block.timestamp - stage2StartTime <= 2 days, "Stage 1 has timed out");
        require(verifyStage2(proof), "User is not presalelisted!");
        //require(!stage2Minted[msg.sender], "max NFT per preSalelist address exceeded");
        require(msg.value >= stage2Cost * amount, "Not enough ETH sent: check presale price.");
        stage2Minted[msg.sender] = true;
    }
    if(stage3){
            require(amount == 1, "You can only mint one");
        require(msg.value >= stage3Cost * amount, "Not enough ETH sent: check public price.");
        //require(!stage3Minted[msg.sender], "Already minted in stage3");
        stage3Minted[msg.sender] = true;
    }

    if(stage1 || stage2 || stage3){
        _safeMint(msg.sender, amount);
        levelUpToken(_totalMinted());
    }

  }

  function verifyStage2(bytes32[] memory proof) public view returns (bool)
  {
    bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
    return MerkleProof.verify(proof, stage2RootHash, leaf);
  }

  function setStage2RootHash(bytes32 _hash) external onlyOwner {
    stage2RootHash = _hash;
  }

  function startStage1() external onlyOwner {
    stage1 = true;
    stage1StartTime = block.timestamp;
  }

  function startStage2() external onlyOwner {
    require(block.timestamp - stage1StartTime >= 48 hours, "Stage 1 hasn't ended yet");
    stage1 = false;
    stage2 = true;
    stage2StartTime = block.timestamp;
  }

  function startStage3() external onlyOwner {
    require(block.timestamp - stage2StartTime >= 48 hours, "Stage 2 hasn't ended yet");
    stage2 = false;
    stage3 = true;
  }

  function setLevelURI(string[] memory _levelURI) external onlyOwner {
      levelURI = _levelURI;
  }

  function reveal(bool _state) external onlyOwner() {
      revealed = _state;
  }

  function pause(bool _state) external onlyOwner {
    paused = _state;
  }
    
  function withdraw() external payable onlyOwner {
    (bool success, ) = payable(owner()).call{value: address(this).balance}("");
    require(success);
  }

    function changeRoyaltyRecipient(address _newRecipient) external onlyOwner {
        require(_newRecipient != address(0), "Error: new recipient is the zero address");
        royaltyAddr = _newRecipient;
    }

    function changeRoyaltyPercentage(uint256 _newPerc) external onlyOwner {
        require(_newPerc <= 10000, "Error: new percentage is greater than 10,000");
        royaltyPerc = _newPerc;
    }

    function getLevelInfo(uint256 tokenId) public view returns (uint256, uint256) 
	{
        require(_exists(tokenId), "Non-existent token");
        uint256 currentLevel = (block.timestamp - _birthdays[tokenId]) / 1 hours;
        uint256 totalLevel = totalLevels[tokenId];
        return (currentLevel, (currentLevel + totalLevel));
        
	}

    function levelUpToken(uint256 tokenId) internal {
        require(ownerOf(tokenId) == _msgSender());
		_birthdays[tokenId] = block.timestamp;
        emit LeveledUp(tokenId);
	}

    function loan(uint256 tokenId, address receiver) external {
        require(ownerOf(tokenId) == msg.sender);
        require(receiver != address(0) && receiver != msg.sender);
        require(tokenOwnersOnLoan[tokenId] == address(0));
        safeTransferFrom(msg.sender, receiver, tokenId);
        tokenOwnersOnLoan[tokenId] = msg.sender;
    }

    function retrieveLoan(uint256 tokenId) external {
        address borrower = ownerOf(tokenId);
        require(msg.sender != borrower);
        require(tokenOwnersOnLoan[tokenId] == msg.sender);
        delete tokenOwnersOnLoan[tokenId];
        loanRetreiveTransfer(borrower, msg.sender, tokenId, true);
    }

    bool private levelingState = false;

    function _beforeTokenTransfers(
        address,
        address,
        uint256 startTokenId,
        uint256 quantity
    ) internal view override {
        uint256 tokenId = startTokenId;
        for (uint256 end = tokenId + quantity; tokenId < end; ++tokenId) {
            require(_birthdays[tokenId] == 0 || levelingState,"You cannot transfer when leveling up");
            require(tokenOwnersOnLoan[tokenId] == address(0), "You cannot transfer loaned token");
        }
    }

     function TransferWhileLevelingUp(
        address from,
        address to,
        uint256 tokenId
    ) external {
        require(ownerOf(tokenId) == _msgSender(), "You do not own this token.");
        levelingState = true;
        safeTransferFrom(from, to, tokenId);
        levelingState = false;
        (,uint256 totalLevel) = getLevelInfo(tokenId);
        totalLevels[tokenId] = totalLevel;
        _birthdays[tokenId] = block.timestamp;
    }
}
