// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// NOTE: Still work in progress

/**
 * @title Loot utility NFT for staking
 * @author Gary Thung
 * @notice The NFTs are minted by the owner of the original Loot bag and are non-transferable
 */
contract StakeableLoot is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenSupply;

    /* ========== STATE VARIABLES ========== */

    IERC721 public lootToken;
    uint256 private _totalSupply;

    /* ========== CONSTRUCTOR ========== */

    constructor(address _lootToken) ERC721("Stakeable Loot", "stkLOOT") {
        lootToken = IERC721(_lootToken);
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    /**
     * @param _tokenId The token ID of the Loot bag
     * @notice Mints a new NFT if none exists. Else, transfers the NFT from the old owner to the new owner
     */
    function claim(uint256 _tokenId) external {
        require(lootToken.ownerOf(_tokenId) == msg.sender, "You are not the owner of this token");

        if (_exists(_tokenId)) {
            _transfer(this.ownerOf(_tokenId), msg.sender, _tokenId);
        } else {
            _tokenSupply.increment();
            _safeMint(_msgSender(), _tokenId);
        }
    }

    /**
     * @notice NFT is intended to be non-transferable
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {}

    /**
     * @notice NFT is intended to be non-transferable
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {}

    /**
     * @notice NFT is intended to be non-transferable
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {}

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _tokenSupply.current();
    }

    function tokenURI(uint256 _tokenId) override public view returns (string memory) {
        return IERC721Metadata(address(lootToken)).tokenURI(_tokenId);
    }
}
