// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CCCStructs.sol";
import "./Demand.sol";
import "./external/auth.sol";
import "./external/MutableForwarder.sol";
import "./external/ApproveAndCallFallback.sol";

contract CCCWeb is ApproveAndCallFallBack, DSAuth {
    // Stores address of a contract that demand proxies will be delegating to
    address public demandProxyTarget;
    mapping(address => bool) public isDemandMap;

    event DemandCreated(
        address indexed newDemand,
        address indexed creater,
        CCCStructs.TokenValue offeredValue,
        bytes ipfsData,
        uint256 timestamp,
        uint256 demandVersion
    );

    event DemandEnded(address indexed demand, CCCStructs.TokenValue offeredValue, uint256 timestamp);

    event FundsAdded(
        address indexed demand,
        address indexed funder,
        bytes32 depositId,
        CCCStructs.TokenValue fundedValue,
        uint256 timestamp
    );

    event CandidateAdded(
        address indexed demand,
        address indexed candidate,
        bytes ipfsData,
        uint timestamp
  );

    modifier isDemand() {
        require(isDemandMap[msg.sender], "Not a demand contract address");
        _;
    }

    function setDemandProxyTarget(address _newDemandProxyTarget) external auth {
        require(_newDemandProxyTarget != address(0));
        demandProxyTarget = _newDemandProxyTarget;
    }

    function initialize(address _demandProxyTarget) external {
        require(_demandProxyTarget != address(0));
        this.setDemandProxyTarget(_demandProxyTarget);
    }

    function createDemand(
        address _creator,
        CCCStructs.TokenValue memory _offeredValue,
        bytes memory _ipfsData
    ) public payable {
        require(
            demandProxyTarget != address(0), "demandProxyTarget must be set from CCC#initialize first");
        
        address newDemand = address(new MutableForwarder());
        address payable newDemandPayableAddress = payable(
            address(uint160(newDemand))
        );
        MutableForwarder(newDemandPayableAddress).setTarget(demandProxyTarget);
        CCCStructs.transferToDemand(
            _creator,
            address(this),
            newDemandPayableAddress,
            _offeredValue
        );
        isDemandMap[newDemandPayableAddress] = true;
        Demand(newDemandPayableAddress).initialize(
            this,
            _creator,
            _offeredValue
        );
        emit DemandCreated(
            newDemand,
            _creator,
            _offeredValue,
            _ipfsData,
            timestamp(),
            Demand(newDemandPayableAddress).version()
        );
    }

    /*
     * end demand 
     */
    function endDemand(
        address _demandAddress, 
        address _receiver, 
        CCCStructs.TokenValue memory _offeredValue
        ) public {
        Demand demand = Demand(_demandAddress);
        demand.executeWithdraw(_receiver, _offeredValue);
        emit DemandEnded(_demandAddress, _offeredValue, timestamp());
    }



    function addCandidate(address _demandAddress, address _candidate, bytes memory _ipfsData) external {
        Demand demand = Demand(_demandAddress);
        demand.addCandidate(msg.sender, _candidate, _ipfsData);
        
    }

    /**
     * @dev This function is called automatically when this contract receives approval for ERC20 token
     * It calls {_createJob} where:
     * - passed `_creator` is `_from`
     * - passed `_offeredValues` are constructed from the transferred token
     * - rest of arguments is obtained by decoding `_data`
     * TODO: Needs implementation
     */
    function receiveApproval(
        address _from,
        uint256 _amount,
        address _token,
        bytes memory _data
    ) external override {
    }

    /**
     * @dev Emits {FundsAdded} event
     * Can only be called by {Demand} contract address
     */
    function emitFundsAdded(
        address _demand,
        address _funder,
        bytes32 depositId,
        CCCStructs.TokenValue memory _fundedValue
    ) external isDemand {
        emit FundsAdded(_demand, _funder, depositId, _fundedValue, timestamp());
    }

    function timestamp() internal view returns (uint256) {
        return block.number;
    }

    function emitCandidateAdded(
        address _demand,
        address _candidate,
        bytes memory _ipfsData
    ) external isDemand {
        emit CandidateAdded(_demand, _candidate, _ipfsData, timestamp());
  }
}
