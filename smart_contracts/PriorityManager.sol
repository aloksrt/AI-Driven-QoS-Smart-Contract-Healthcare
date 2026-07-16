// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title PriorityManager
 * @author Alock Gupta
 * @notice AI-Driven QoS Priority Management for Healthcare Blockchain
 * @dev Companion contract for HealthcareQoS.sol
 */

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract PriorityManager is
    AccessControl,
    Pausable,
    ReentrancyGuard
{

    // ==========================================================
    // ROLES
    // ==========================================================

    bytes32 public constant AI_ENGINE_ROLE =
        keccak256("AI_ENGINE_ROLE");

    bytes32 public constant HEALTHCARE_ROLE =
        keccak256("HEALTHCARE_ROLE");

    // ==========================================================
    // ENUMS
    // ==========================================================

    enum PriorityLevel{
        LOW,
        NORMAL,
        HIGH,
        CRITICAL,
        EMERGENCY
    }

    enum TransactionStatus{
        PENDING,
        PROCESSING,
        COMPLETED,
        FAILED
    }

    // ==========================================================
    // STRUCTURES
    // ==========================================================

    struct QoSMetric{

        uint256 latency;

        uint256 throughput;

        uint256 gasConsumption;

        uint256 availability;

        uint256 reliability;

        uint256 aiScore;

        uint256 timestamp;

    }

    struct HealthcareTransaction{

        uint256 transactionId;

        uint256 recordId;

        address requester;

        PriorityLevel priority;

        TransactionStatus status;

        QoSMetric qos;

        uint256 createdAt;

        uint256 processedAt;

    }

    // ==========================================================
    // STORAGE
    // ==========================================================

    uint256 public transactionCounter;

    mapping(uint256 => HealthcareTransaction)
        public transactions;

    mapping(PriorityLevel => uint256[])
        internal priorityQueue;

    mapping(uint256 => QoSMetric[])
        internal qosHistory;

    // ==========================================================
    // EVENTS
    // ==========================================================

    event TransactionQueued(
        uint256 indexed transactionId,
        PriorityLevel priority
    );

    event TransactionProcessed(
        uint256 indexed transactionId,
        PriorityLevel priority
    );

    event QoSScoreUpdated(
        uint256 indexed transactionId,
        uint256 aiScore
    );

    event PriorityChanged(
        uint256 indexed transactionId,
        PriorityLevel oldPriority,
        PriorityLevel newPriority
    );

    // ==========================================================
    // CUSTOM ERRORS
    // ==========================================================

    error InvalidTransaction();

    error InvalidPriority();

    error QueueEmpty();

    error Unauthorized();

    // ==========================================================
    // CONSTRUCTOR
    // ==========================================================

    constructor(){

        _grantRole(
            DEFAULT_ADMIN_ROLE,
            msg.sender
        );

        _grantRole(
            AI_ENGINE_ROLE,
            msg.sender
        );

    }
    // ==========================================================
    // QUEUE MANAGEMENT
    // ==========================================================

    function queueTransaction(

        uint256 _recordId,

        PriorityLevel _priority

    )
        external
        whenNotPaused
        nonReentrant
        onlyRole(HEALTHCARE_ROLE)
    {

        transactionCounter++;

        QoSMetric memory metric = QoSMetric({

            latency:0,

            throughput:0,

            gasConsumption:0,

            availability:100,

            reliability:100,

            aiScore:0,

            timestamp:block.timestamp

        });

        transactions[transactionCounter] =
            HealthcareTransaction({

                transactionId:transactionCounter,

                recordId:_recordId,

                requester:msg.sender,

                priority:_priority,

                status:TransactionStatus.PENDING,

                qos:metric,

                createdAt:block.timestamp,

                processedAt:0

            });

        priorityQueue[_priority].push(
            transactionCounter
        );

        emit TransactionQueued(

            transactionCounter,

            _priority

        );

    }

    // ==========================================================
    // AI QoS UPDATE
    // ==========================================================

    function updateQoSScore(

        uint256 _transactionId,

        uint256 _latency,

        uint256 _throughput,

        uint256 _gas,

        uint256 _availability,

        uint256 _reliability,

        uint256 _aiScore

    )
        external
        onlyRole(AI_ENGINE_ROLE)
    {

        if(_transactionId==0 ||

            _transactionId>transactionCounter)

            revert InvalidTransaction();

        HealthcareTransaction storage txn =

            transactions[_transactionId];

        txn.qos.latency = _latency;

        txn.qos.throughput = _throughput;

        txn.qos.gasConsumption = _gas;

        txn.qos.availability = _availability;

        txn.qos.reliability = _reliability;

        txn.qos.aiScore = _aiScore;

        txn.qos.timestamp = block.timestamp;

        qosHistory[_transactionId].push(
            txn.qos
        );

        emit QoSScoreUpdated(

            _transactionId,

            _aiScore

        );

    }

    // ==========================================================
    // AI PRIORITY ASSIGNMENT
    // ==========================================================

    function assignPriority(

        uint256 _transactionId

    )
        external
        onlyRole(AI_ENGINE_ROLE)
    {

        HealthcareTransaction storage txn =

            transactions[_transactionId];

        PriorityLevel previous =

            txn.priority;

        uint256 score =

            txn.qos.aiScore;

        if(score>=90){

            txn.priority=
                PriorityLevel.EMERGENCY;

        }
        else if(score>=75){

            txn.priority=
                PriorityLevel.CRITICAL;

        }
        else if(score>=60){

            txn.priority=
                PriorityLevel.HIGH;

        }
        else if(score>=40){

            txn.priority=
                PriorityLevel.NORMAL;

        }
        else{

            txn.priority=
                PriorityLevel.LOW;

        }

        emit PriorityChanged(

            _transactionId,

            previous,

            txn.priority

        );

    }

    // ==========================================================
    // PROCESS TRANSACTION
    // ==========================================================

    function processTransaction(

        uint256 _transactionId

    )
        external
        onlyRole(HEALTHCARE_ROLE)
    {

        HealthcareTransaction storage txn =

            transactions[_transactionId];

        txn.status=

            TransactionStatus.PROCESSING;

        txn.processedAt=

            block.timestamp;

        emit TransactionProcessed(

            _transactionId,

            txn.priority

        );

    }

    // ==========================================================
    // COMPLETE TRANSACTION
    // ==========================================================

    function completeTransaction(

        uint256 _transactionId

    )
        external
        onlyRole(HEALTHCARE_ROLE)
    {

        transactions[_transactionId]

            .status=

            TransactionStatus.COMPLETED;

    }

    // ==========================================================
    // FAIL TRANSACTION
    // ==========================================================

    function failTransaction(

        uint256 _transactionId

    )
        external
        onlyRole(HEALTHCARE_ROLE)
    {

        transactions[_transactionId]

            .status=

            TransactionStatus.FAILED;

    }

    // ==========================================================
    // VIEW QUEUE
    // ==========================================================

    function getPriorityQueue(

        PriorityLevel _priority

    )
        external
        view
        returns(uint256[] memory)
    {

        return priorityQueue[_priority];

    }

    function getTransaction(

        uint256 _transactionId

    )
        external
        view
        returns(

            HealthcareTransaction memory

        )
    {

        return transactions[_transactionId];

    }
    // ==========================================================
    // EMERGENCY PROCESSING
    // ==========================================================

    event EmergencyTransactionQueued(
        uint256 indexed transactionId,
        address indexed requester,
        uint256 timestamp
    );

    event QueueOptimized(
        uint256 timestamp,
        uint256 totalTransactions
    );

    mapping(uint256 => bool)
        public emergencyTransactions;

    function markEmergency(
        uint256 _transactionId
    )
        external
        onlyRole(HEALTHCARE_ROLE)
    {
        if(_transactionId == 0 ||
            _transactionId > transactionCounter)
            revert InvalidTransaction();

        HealthcareTransaction storage txn =
            transactions[_transactionId];

        txn.priority = PriorityLevel.EMERGENCY;

        emergencyTransactions[_transactionId] = true;

        priorityQueue[PriorityLevel.EMERGENCY]
            .push(_transactionId);

        emit EmergencyTransactionQueued(
            _transactionId,
            msg.sender,
            block.timestamp
        );
    }

    // ==========================================================
    // REMOVE FROM QUEUE
    // ==========================================================

    function removeTransactionFromQueue(
        uint256 _transactionId,
        PriorityLevel _priority
    )
        internal
    {
        uint256[] storage queue =
            priorityQueue[_priority];

        for(uint256 i=0;i<queue.length;i++)
        {
            if(queue[i]==_transactionId)
            {
                queue[i]=queue[
                    queue.length-1
                ];

                queue.pop();

                break;
            }
        }
    }

    // ==========================================================
    // REASSIGN PRIORITY
    // ==========================================================

    function reassignPriority(
        uint256 _transactionId,
        PriorityLevel _newPriority
    )
        external
        onlyRole(AI_ENGINE_ROLE)
    {

        HealthcareTransaction storage txn =
            transactions[_transactionId];

        removeTransactionFromQueue(
            _transactionId,
            txn.priority
        );

        PriorityLevel previous =
            txn.priority;

        txn.priority = _newPriority;

        priorityQueue[_newPriority]
            .push(_transactionId);

        emit PriorityChanged(
            _transactionId,
            previous,
            _newPriority
        );
    }

    // ==========================================================
    // NEXT TRANSACTION
    // ==========================================================

    function nextTransaction()
        external
        view
        returns(uint256)
    {

        if(priorityQueue[
            PriorityLevel.EMERGENCY
        ].length>0)
        {
            return priorityQueue[
                PriorityLevel.EMERGENCY
            ][0];
        }

        if(priorityQueue[
            PriorityLevel.CRITICAL
        ].length>0)
        {
            return priorityQueue[
                PriorityLevel.CRITICAL
            ][0];
        }

        if(priorityQueue[
            PriorityLevel.HIGH
        ].length>0)
        {
            return priorityQueue[
                PriorityLevel.HIGH
            ][0];
        }

        if(priorityQueue[
            PriorityLevel.NORMAL
        ].length>0)
        {
            return priorityQueue[
                PriorityLevel.NORMAL
            ][0];
        }

        if(priorityQueue[
            PriorityLevel.LOW
        ].length>0)
        {
            return priorityQueue[
                PriorityLevel.LOW
            ][0];
        }

        revert QueueEmpty();
    }

    // ==========================================================
    // QoS ANALYTICS
    // ==========================================================

    function averageQoS(
        uint256 _transactionId
    )
        external
        view
        returns(uint256)
    {

        QoSMetric[] memory history =
            qosHistory[_transactionId];

        if(history.length==0)
            return 0;

        uint256 total;

        for(uint256 i=0;i<history.length;i++)
        {
            total += history[i].aiScore;
        }

        return total/history.length;
    }

    function totalHistory(
        uint256 _transactionId
    )
        external
        view
        returns(uint256)
    {
        return qosHistory[_transactionId]
            .length;
    }

    // ==========================================================
    // QUEUE STATISTICS
    // ==========================================================

    function queueLength(
        PriorityLevel _priority
    )
        external
        view
        returns(uint256)
    {
        return priorityQueue[_priority]
            .length;
    }

    function optimizeQueue()
        external
        onlyRole(AI_ENGINE_ROLE)
    {
        emit QueueOptimized(
            block.timestamp,
            transactionCounter
        );
    }
    // ==========================================================
    // ADMINISTRATIVE FUNCTIONS
    // ==========================================================

    function grantHealthcareRole(
        address _account
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(
            HEALTHCARE_ROLE,
            _account
        );
    }

    function revokeHealthcareRole(
        address _account
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _revokeRole(
            HEALTHCARE_ROLE,
            _account
        );
    }

    function grantAIEngineRole(
        address _account
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(
            AI_ENGINE_ROLE,
            _account
        );
    }

    function revokeAIEngineRole(
        address _account
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _revokeRole(
            AI_ENGINE_ROLE,
            _account
        );
    }

    // ==========================================================
    // PAUSE CONTROL
    // ==========================================================

    function pause()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _pause();
    }

    function unpause()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _unpause();
    }

    // ==========================================================
    // SYSTEM INFORMATION
    // ==========================================================

    function totalTransactions()
        external
        view
        returns(uint256)
    {
        return transactionCounter;
    }

    function totalEmergencyTransactions()
        external
        view
        returns(uint256 total)
    {
        for(uint256 i = 1; i <= transactionCounter; i++)
        {
            if(emergencyTransactions[i])
            {
                total++;
            }
        }
    }

    function pendingTransactions()
        external
        view
        returns(uint256 total)
    {
        for(uint256 i = 1; i <= transactionCounter; i++)
        {
            if(
                transactions[i].status ==
                TransactionStatus.PENDING
            )
            {
                total++;
            }
        }
    }

    function completedTransactions()
        external
        view
        returns(uint256 total)
    {
        for(uint256 i = 1; i <= transactionCounter; i++)
        {
            if(
                transactions[i].status ==
                TransactionStatus.COMPLETED
            )
            {
                total++;
            }
        }
    }

    // ==========================================================
    // ROLE VALIDATION
    // ==========================================================

    function isHealthcareProvider(
        address _account
    )
        external
        view
        returns(bool)
    {
        return hasRole(
            HEALTHCARE_ROLE,
            _account
        );
    }

    function isAIEngine(
        address _account
    )
        external
        view
        returns(bool)
    {
        return hasRole(
            AI_ENGINE_ROLE,
            _account
        );
    }

    // ==========================================================
    // VERSION
    // ==========================================================

    function contractName()
        external
        pure
        returns(string memory)
    {
        return "PriorityManager";
    }

    function contractVersion()
        external
        pure
        returns(string memory)
    {
        return "1.0.0";
    }

    // ==========================================================
    // ERC165 SUPPORT
    // ==========================================================

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(AccessControl)
        returns(bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
