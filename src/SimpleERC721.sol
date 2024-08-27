// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleERC721 is ERC721, Ownable {
    constructor() ERC721("SimpleNFT", "SNFT") Ownable(msg.sender) {}

    function mint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }
}
