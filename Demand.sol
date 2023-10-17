// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;
pragma experimental ABIEncoderV2;

import "./CCCStructs.sol";
import "./CCCWeb.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Demand {
    uint256 public constant version = 1; // current version of {Demand} smart-contract

    CCCWeb public cccWeb;
    address public creator;

    mapping(bytes32 => Deposit) public deposits;
    bytes32[] public depositIds; // To allow looking up and listing all deposits
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet internal depositors;
    EnumerableSet.AddressSet internal invitedCandidates;

    struct Deposit {
        address depositor;
        CCCStructs.TokenValue tokenValue;
    }

    function initialize(
        CCCWeb _cccWeb,
        address _creator,
        CCCStructs.TokenValue calldata _offeredValue
    ) external {
        require(
            address(cccWeb) == address(0),
            "Contract already initialized. Can only be done once"
        );
        require(address(_cccWeb) != address(0), "CCCWeb cannot be null");
        require(_creator != address(0), "Creator cannot be null");
        require(_offeredValue.value > 0, "You must offer some tokens as pay");

        cccWeb = _cccWeb;
        creator = _creator;
        _recordAddedFunds(_creator, _offeredValue);
    }

    function _recordAddedFunds(
        address _funder,
        CCCStructs.TokenValue memory _offeredValue
    ) internal {
        bytes32 depositId = _generateDepositId(_funder, _offeredValue);
        Deposit storage earlierDeposit = deposits[depositId];
        if (earlierDeposit.depositor == address(0)) {
            Deposit memory deposit = Deposit(_funder, _offeredValue);
            deposits[depositId] = deposit;
            depositIds.push(depositId);
            depositors.add(_funder);
        } else {
            earlierDeposit.tokenValue.value += _offeredValue.value;
        }
        cccWeb.emitFundsAdded(address(this), _funder, depositId, _offeredValue);
    }


    function executeWithdraw(
        address receiver,
        CCCStructs.TokenValue memory tokenValue
    ) public {
        bytes32 valueDepositId = _generateDepositId(receiver, tokenValue);
        Deposit memory deposit = deposits[valueDepositId];
        require(
            tokenValue.value <= deposit.tokenValue.value,
            "Can't withdraw more than the withdrawer has deposited"
        );
        CCCStructs.transferTokenValue(tokenValue, address(this), receiver);
        deposit.tokenValue.value -= tokenValue.value;
        deposits[valueDepositId] = deposit;
    }

    function _generateDepositId(
        address depositor,
        CCCStructs.TokenValue memory tokenValue
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    depositor,
                    tokenValue.token.tokenContract.tokenType,
                    tokenValue.token.tokenContract.tokenAddress,
                    tokenValue.token.tokenId
                )
            );
    }

    /**
     * @dev It is called by demand creator when he allows a new candidate to start invoicing for this demand
     *
     * Requirements:
     * - Can only be called by demand creator
     * - `_candidate` cannot be empty
     * - same `_candidate` cannot be added twice
     *
     * Emits {CandidateAdded} event
     */
    function addCandidate(address _creator, address _candidate) public {
        require(
            _creator == creator,
            "Only demand creator can add candidates"
        );
        // TODO: add check that candidate cant be same as arbiter or employer (creator)
        require(
            _candidate != creator,
            "Candidate can't be the same address as creator (employer)"
        );
        require(
            invitedCandidates.contains(_candidate) == false,
            "Candidate already added. Can't add duplicates"
        );
        invitedCandidates.add(_candidate);
    }


}
