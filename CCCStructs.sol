// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@ganache/console.log/console.sol";

library CCCStructs {
    enum TokenType {
        ETH,
        ERC20,
        ERC721,
        ERC1155
    }

    struct TokenContract {
        TokenType tokenType;
        address tokenAddress;
    }

    struct Token {
        TokenContract tokenContract;
        uint256 tokenId;
    }

    struct TokenValue {
        Token token;
        uint256 value;
    }

    //[[ERC20,"0x5FC8d32690cc91D4c39d9d3abcBD16989F875707", 123, 100]]

    function transferToDemand(
        address initialOwner,
        address cccWeb,
        address demandProxy,
        TokenValue memory _offeredValue
    ) public {
        TokenType tokenType = _offeredValue.token.tokenContract.tokenType;
        if (tokenType == TokenType.ETH) {
            transferETH(_offeredValue, payable(demandProxy));
        } else if (tokenType == TokenType.ERC20) {
            transferERC20(_offeredValue, initialOwner, cccWeb);
            transferERC20(_offeredValue, cccWeb, demandProxy);
        } else if (tokenType == TokenType.ERC721) {
            transferERC721ToDemand(
                initialOwner,
                cccWeb,
                demandProxy,
                _offeredValue
            );
        } else if (tokenType == TokenType.ERC1155) {
            transferERC1155ToDemand(
                initialOwner,
                cccWeb,
                demandProxy,
                _offeredValue
            );
        } else {
            revert UnsupportedTokenType(tokenType);
        }
    }

    function transferTokenValue(
        TokenValue memory tokenValue,
        address from,
        address to
    ) public {
        TokenType tokenType = tokenValue.token.tokenContract.tokenType;
        if (tokenType == TokenType.ETH) {
            transferETH(tokenValue, payable(to));
        } else if (tokenType == TokenType.ERC20) {
            transferERC20(tokenValue, from, to);
        } else if (tokenType == TokenType.ERC721) {
            transferERC721(tokenValue, from, to);
        } else if (tokenType == TokenType.ERC1155) {
            transferERC1155(tokenValue, from, to);
        } else {
            revert UnsupportedTokenType(tokenType);
        }
    }

    function transferERC721ToDemand(
        address initialOwner,
        address cccWeb,
        address demand,
        TokenValue memory offer
    ) public {
        uint256 tokenId = offer.token.tokenId;
        IERC721 offeredToken = IERC721(offer.token.tokenContract.tokenAddress);
        bool needToTransferToCCCWebFirst = offeredToken.ownerOf(tokenId) ==
            initialOwner &&
            offeredToken.getApproved(tokenId) == cccWeb;
        if (needToTransferToCCCWebFirst) {
            transferERC721(offer, initialOwner, cccWeb);
        }
        transferERC721(offer, cccWeb, demand);
    }

    function transferERC721(
        TokenValue memory tokenValue,
        address from,
        address to
    ) public {
        uint256 tokenId = tokenValue.token.tokenId;
        IERC721 offeredToken = IERC721(
            tokenValue.token.tokenContract.tokenAddress
        );
        offeredToken.safeTransferFrom(from, to, tokenId);
    }

    function transferERC1155ToDemand(
        address initialOwner,
        address cccWeb,
        address demand,
        TokenValue memory offer
    ) public {
        uint256 tokenId = offer.token.tokenId;
        uint256 tokenAmount = offer.value;
        IERC1155 offeredToken = IERC1155(
            offer.token.tokenContract.tokenAddress
        );
        bool needToTransferToEthlanceFirst = offeredToken.balanceOf(
            initialOwner,
            tokenId
        ) >=
            tokenAmount &&
            offeredToken.isApprovedForAll(initialOwner, cccWeb);

        if (needToTransferToEthlanceFirst) {
            transferERC1155(offer, initialOwner, cccWeb);
        }
        transferERC1155(offer, cccWeb, demand);
    }

    function transferERC1155(
        TokenValue memory tokenValue,
        address from,
        address to
    ) public {
        uint256 tokenId = tokenValue.token.tokenId;
        uint256 tokenAmount = tokenValue.value;
        IERC1155 offeredToken = IERC1155(
            tokenValue.token.tokenContract.tokenAddress
        );
        offeredToken.safeTransferFrom(from, to, tokenId, tokenAmount, "");
    }

    function transferETH(TokenValue memory tokenValue, address payable to)
        public
    {
        to.transfer(tokenValue.value); // If more was included in msg.value, the reminder stays in the calling contract
    }

    function transferERC20(
        TokenValue memory tokenValue,
        address from,
        address to
    ) public {
        uint256 offeredAmount = tokenValue.value;
        IERC20 offeredToken = IERC20(
            tokenValue.token.tokenContract.tokenAddress
        );
        bool isAlreadyOwner = from == address(this);
        if (isAlreadyOwner) {
            require(
                offeredToken.balanceOf(address(this)) >= offeredAmount,
                "Insufficient ERC20 tokens"
            );
            offeredToken.transfer(to, offeredAmount);
        } else {
            uint256 allowedToTransfer = offeredToken.allowance(from, to);
            require(
                allowedToTransfer >= offeredAmount,
                "Insufficient amount of ERC20 allowed. Approve more"
            );
            offeredToken.transferFrom(from, to, offeredAmount);
        }
    }

    error UnsupportedTokenType(TokenType);
}
