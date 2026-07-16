// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title HealthcareQoS
 * @author Alock Gupta
 * @notice AI-Driven QoS-Aware Smart Contract Framework for Healthcare Blockchain Systems
 * @dev Reference implementation accompanying the research manuscript.
 */

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract HealthcareQoS is AccessControl, Pausable, ReentrancyGuard {

    // ==========================================================
    // ROLES
    // ==========================================================

    bytes32 public constant DOCTOR_ROLE =
        keccak256("DOCTOR_ROLE");

    bytes32 public constant HOSPITAL_ROLE =
        keccak256("HOSPITAL_ROLE");

    bytes32 public constant LAB_ROLE =
        keccak256("LAB_ROLE");

    bytes32 public constant PATIENT_ROLE =
        keccak256("PATIENT_ROLE");

    bytes32 public constant AI_ENGINE_ROLE =
        keccak256("AI_ENGINE_ROLE");

    // ==========================================================
    // ENUMS
    // ==========================================================

    enum PriorityLevel {
        LOW,
        NORMAL,
        HIGH,
        EMERGENCY
    }

    enum RecordStatus {
        ACTIVE,
        ARCHIVED,
        DELETED
    }

    // ==========================================================
    // STRUCTS
    // ==========================================================

    struct Patient {

        uint256 patientId;

        string fullName;

        uint8 age;

        string gender;

        address wallet;

        bool registered;

        uint256 registrationTime;
    }

    struct Provider {

        uint256 providerId;

        string organization;

        string specialization;

        address wallet;

        bool active;
    }

    struct QoSMetric {

        uint256 latency;

        uint256 throughput;

        uint256 gasConsumption;

        uint256 availability;

        uint256 reliability;

        uint256 aiScore;

        PriorityLevel priority;
    }

    struct HealthRecord {

        uint256 recordId;

        uint256 patientId;

        string ipfsHash;

        bytes32 dataHash;

        address createdBy;

        uint256 createdAt;

        RecordStatus status;

        QoSMetric qos;
    }

    // ==========================================================
    // STATE VARIABLES
    // ==========================================================

    uint256 public patientCounter;

    uint256 public providerCounter;

    uint256 public recordCounter;

    mapping(uint256 => Patient) public patients;

    mapping(address => uint256) public patientWallet;

    mapping(uint256 => Provider) public providers;

    mapping(address => uint256) public providerWallet;

    mapping(uint256 => HealthRecord) public records;

    // ==========================================================
    // EVENTS
    // ==========================================================

    event PatientRegistered(
        uint256 indexed patientId,
        address indexed wallet,
        string name
    );

    event ProviderRegistered(
        uint256 indexed providerId,
        address indexed wallet,
        string organization
    );

    event ContractPaused(address account);

    event ContractUnpaused(address account);

    // ==========================================================
    // ERRORS
    // ==========================================================

    error AlreadyRegistered();

    error InvalidAddress();

    error InvalidPatient();

    error InvalidProvider();

    // ==========================================================
    // MODIFIERS
    // ==========================================================

    modifier onlyPatient() {

        if(!hasRole(PATIENT_ROLE,msg.sender))
            revert InvalidPatient();

        _;
    }

    modifier onlyProvider() {

        if(
            !hasRole(DOCTOR_ROLE,msg.sender) &&
            !hasRole(HOSPITAL_ROLE,msg.sender) &&
            !hasRole(LAB_ROLE,msg.sender)
        )
            revert InvalidProvider();

        _;
    }

    // ==========================================================
    // CONSTRUCTOR
    // ==========================================================

    constructor() {

        _grantRole(DEFAULT_ADMIN_ROLE,msg.sender);

        _grantRole(AI_ENGINE_ROLE,msg.sender);

    }

    // ==========================================================
    // ADMIN FUNCTIONS
    // ==========================================================

    function pause()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _pause();

        emit ContractPaused(msg.sender);
    }

    function unpause()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _unpause();

        emit ContractUnpaused(msg.sender);
    }

    // ==========================================================
    // PATIENT REGISTRATION
    // ==========================================================

    function registerPatient(

        string memory _name,

        uint8 _age,

        string memory _gender

    )
        external
        whenNotPaused
    {

        if(patientWallet[msg.sender]!=0)
            revert AlreadyRegistered();

        patientCounter++;

        patients[patientCounter]=Patient({

            patientId:patientCounter,

            fullName:_name,

            age:_age,

            gender:_gender,

            wallet:msg.sender,

            registered:true,

            registrationTime:block.timestamp

        });

        patientWallet[msg.sender]=patientCounter;

        _grantRole(PATIENT_ROLE,msg.sender);

        emit PatientRegistered(
            patientCounter,
            msg.sender,
            _name
        );
    }

    // ==========================================================
    // PROVIDER REGISTRATION
    // ==========================================================

    function registerProvider(

        string memory _organization,

        string memory _specialization,

        uint8 providerType

    )
        external
        whenNotPaused
    {

        if(providerWallet[msg.sender]!=0)
            revert AlreadyRegistered();

        providerCounter++;

        providers[providerCounter]=Provider({

            providerId:providerCounter,

            organization:_organization,

            specialization:_specialization,

            wallet:msg.sender,

            active:true

        });

        providerWallet[msg.sender]=providerCounter;

        if(providerType==1){

            _grantRole(DOCTOR_ROLE,msg.sender);

        }else if(providerType==2){

            _grantRole(HOSPITAL_ROLE,msg.sender);

        }else{

            _grantRole(LAB_ROLE,msg.sender);

        }

        emit ProviderRegistered(
            providerCounter,
            msg.sender,
            _organization
        );
    }
    // ==========================================================
    // ACCESS CONTROL MAPPINGS
    // ==========================================================

    mapping(uint256 => mapping(address => bool)) private recordAccess;

    mapping(uint256 => uint256[]) private patientRecords;

    // ==========================================================
    // ADDITIONAL EVENTS
    // ==========================================================

    event HealthRecordCreated(
        uint256 indexed recordId,
        uint256 indexed patientId,
        address indexed provider,
        string ipfsHash
    );

    event HealthRecordUpdated(
        uint256 indexed recordId,
        address indexed provider
    );

    event AccessGranted(
        uint256 indexed recordId,
        address indexed user
    );

    event AccessRevoked(
        uint256 indexed recordId,
        address indexed user
    );

    // ==========================================================
    // CREATE HEALTH RECORD
    // ==========================================================

    function createHealthRecord(
        uint256 _patientId,
        string memory _ipfsHash,
        bytes32 _dataHash,
        PriorityLevel _priority
    )
        external
        onlyProvider
        whenNotPaused
        nonReentrant
    {
        require(
            patients[_patientId].registered,
            "Patient not registered"
        );

        recordCounter++;

        QoSMetric memory metric = QoSMetric({
            latency:0,
            throughput:0,
            gasConsumption:0,
            availability:100,
            reliability:100,
            aiScore:0,
            priority:_priority
        });

        records[recordCounter] = HealthRecord({
            recordId:recordCounter,
            patientId:_patientId,
            ipfsHash:_ipfsHash,
            dataHash:_dataHash,
            createdBy:msg.sender,
            createdAt:block.timestamp,
            status:RecordStatus.ACTIVE,
            qos:metric
        });

        patientRecords[_patientId].push(recordCounter);

        recordAccess[recordCounter][msg.sender] = true;
        recordAccess[recordCounter][patients[_patientId].wallet] = true;

        emit HealthRecordCreated(
            recordCounter,
            _patientId,
            msg.sender,
            _ipfsHash
        );
    }

    // ==========================================================
    // UPDATE HEALTH RECORD
    // ==========================================================

    function updateHealthRecord(
        uint256 _recordId,
        string memory _ipfsHash,
        bytes32 _dataHash
    )
        external
        whenNotPaused
        nonReentrant
    {
        require(
            recordAccess[_recordId][msg.sender],
            "Access denied"
        );

        HealthRecord storage record = records[_recordId];

        require(
            record.status == RecordStatus.ACTIVE,
            "Inactive record"
        );

        record.ipfsHash = _ipfsHash;
        record.dataHash = _dataHash;

        emit HealthRecordUpdated(
            _recordId,
            msg.sender
        );
    }

    // ==========================================================
    // GRANT ACCESS
    // ==========================================================

    function grantAccess(
        uint256 _recordId,
        address _user
    )
        external
        onlyPatient
    {
        uint256 patientId = patientWallet[msg.sender];

        require(
            records[_recordId].patientId == patientId,
            "Unauthorized"
        );

        recordAccess[_recordId][_user] = true;

        emit AccessGranted(
            _recordId,
            _user
        );
    }

    // ==========================================================
    // REVOKE ACCESS
    // ==========================================================

    function revokeAccess(
        uint256 _recordId,
        address _user
    )
        external
        onlyPatient
    {
        uint256 patientId = patientWallet[msg.sender];

        require(
            records[_recordId].patientId == patientId,
            "Unauthorized"
        );

        recordAccess[_recordId][_user] = false;

        emit AccessRevoked(
            _recordId,
            _user
        );
    }

    // ==========================================================
    // VIEW FUNCTIONS
    // ==========================================================

    function getHealthRecord(
        uint256 _recordId
    )
        external
        view
        returns(HealthRecord memory)
    {
        require(
            recordAccess[_recordId][msg.sender],
            "Access denied"
        );

        return records[_recordId];
    }

    function getPatientRecords(
        uint256 _patientId
    )
        external
        view
        returns(uint256[] memory)
    {
        require(
            patients[_patientId].wallet == msg.sender ||
            hasRole(DEFAULT_ADMIN_ROLE,msg.sender),
            "Unauthorized"
        );

        return patientRecords[_patientId];
    }

    function hasRecordAccess(
        uint256 _recordId,
        address _user
    )
        public
        view
        returns(bool)
    {
        return recordAccess[_recordId][_user];
    }
    // ==========================================================
    // AI QoS MANAGEMENT
    // ==========================================================

    event QoSUpdated(
        uint256 indexed recordId,
        uint256 aiScore,
        PriorityLevel priority
    );

    event EmergencyTransaction(
        uint256 indexed recordId,
        address indexed provider,
        uint256 timestamp
    );

    event AIRecommendation(
        uint256 indexed recordId,
        uint256 score,
        string recommendation
    );

    struct AIRecommendationData {

        uint256 aiScore;

        string recommendation;

        uint256 confidence;

        uint256 timestamp;
    }

    mapping(uint256 => AIRecommendationData)
        public aiRecommendations;

    // ==========================================================
    // UPDATE QoS SCORE
    // ==========================================================

    function updateQoSScore(

        uint256 _recordId,

        uint256 _latency,

        uint256 _throughput,

        uint256 _gas,

        uint256 _availability,

        uint256 _reliability,

        uint256 _aiScore

    )
        external
        onlyRole(AI_ENGINE_ROLE)
        whenNotPaused
    {

        require(
            _recordId<=recordCounter,
            "Invalid Record"
        );

        HealthRecord storage record =
            records[_recordId];

        record.qos.latency=_latency;

        record.qos.throughput=_throughput;

        record.qos.gasConsumption=_gas;

        record.qos.availability=_availability;

        record.qos.reliability=_reliability;

        record.qos.aiScore=_aiScore;

        if(_aiScore>=90){

            record.qos.priority=
                PriorityLevel.EMERGENCY;

        }
        else if(_aiScore>=70){

            record.qos.priority=
                PriorityLevel.HIGH;

        }
        else if(_aiScore>=40){

            record.qos.priority=
                PriorityLevel.NORMAL;

        }
        else{

            record.qos.priority=
                PriorityLevel.LOW;

        }

        emit QoSUpdated(

            _recordId,

            _aiScore,

            record.qos.priority

        );

    }

    // ==========================================================
    // STORE AI RECOMMENDATION
    // ==========================================================

    function submitAIRecommendation(

        uint256 _recordId,

        uint256 _score,

        string memory _recommendation,

        uint256 _confidence

    )
        external
        onlyRole(AI_ENGINE_ROLE)
    {

        aiRecommendations[_recordId]=

            AIRecommendationData({

                aiScore:_score,

                recommendation:_recommendation,

                confidence:_confidence,

                timestamp:block.timestamp

            });

        emit AIRecommendation(

            _recordId,

            _score,

            _recommendation

        );

    }

    // ==========================================================
    // EMERGENCY TRANSACTION
    // ==========================================================

    function emergencyAccess(

        uint256 _recordId

    )
        external
        onlyProvider
        nonReentrant
    {

        require(

            records[_recordId].status==

            RecordStatus.ACTIVE,

            "Inactive Record"

        );

        records[_recordId].qos.priority=

            PriorityLevel.EMERGENCY;

        emit EmergencyTransaction(

            _recordId,

            msg.sender,

            block.timestamp

        );

    }

    // ==========================================================
    // PRIORITY CHECK
    // ==========================================================

    function getPriorityLevel(

        uint256 _recordId

    )
        public
        view
        returns(PriorityLevel)
    {

        return records[_recordId]

            .qos.priority;

    }

    // ==========================================================
    // QoS SCORE
    // ==========================================================

    function calculateQoSScore(

        uint256 _recordId

    )
        public
        view
        returns(uint256)
    {

        QoSMetric memory qos=

            records[_recordId].qos;

        return(

            qos.availability+

            qos.reliability+

            qos.aiScore+

            qos.throughput

        )/4;

    }

    // ==========================================================
    // PERFORMANCE METRICS
    // ==========================================================

    function getQoSMetrics(

        uint256 _recordId

    )
        external
        view
        returns(

            QoSMetric memory

        )
    {

        return

            records[_recordId].qos;

    }

    // ==========================================================
    // AI VALIDATION
    // ==========================================================

    function validateAIEngine(

        address _engine

    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {

        _grantRole(

            AI_ENGINE_ROLE,

            _engine

        );

    }

    function revokeAIEngine(

        address _engine

    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {

        _revokeRole(

            AI_ENGINE_ROLE,

            _engine

        );

    }
    // ==========================================================
    // RECORD STATUS MANAGEMENT
    // ==========================================================

    event RecordArchived(
        uint256 indexed recordId,
        address indexed provider
    );

    event RecordDeleted(
        uint256 indexed recordId,
        address indexed provider
    );

    function archiveRecord(
        uint256 _recordId
    )
        external
        onlyProvider
        whenNotPaused
    {
        require(
            recordAccess[_recordId][msg.sender],
            "Unauthorized"
        );

        records[_recordId].status =
            RecordStatus.ARCHIVED;

        emit RecordArchived(
            _recordId,
            msg.sender
        );
    }

    function deleteRecord(
        uint256 _recordId
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        records[_recordId].status =
            RecordStatus.DELETED;

        emit RecordDeleted(
            _recordId,
            msg.sender
        );
    }

    // ==========================================================
    // ANALYTICS
    // ==========================================================

    function totalPatients()
        external
        view
        returns(uint256)
    {
        return patientCounter;
    }

    function totalProviders()
        external
        view
        returns(uint256)
    {
        return providerCounter;
    }

    function totalRecords()
        external
        view
        returns(uint256)
    {
        return recordCounter;
    }

    // ==========================================================
    // PROVIDER INFORMATION
    // ==========================================================

    function getProvider(
        uint256 _providerId
    )
        external
        view
        returns(Provider memory)
    {
        return providers[_providerId];
    }

    function getPatient(
        uint256 _patientId
    )
        external
        view
        returns(Patient memory)
    {
        return patients[_patientId];
    }

    // ==========================================================
    // RECORD EXISTENCE
    // ==========================================================

    function recordExists(
        uint256 _recordId
    )
        public
        view
        returns(bool)
    {
        return
            _recordId>0 &&
            _recordId<=recordCounter;
    }

    // ==========================================================
    // PATIENT VALIDATION
    // ==========================================================

    function isPatientRegistered(
        address _wallet
    )
        external
        view
        returns(bool)
    {
        return
            patientWallet[_wallet]!=0;
    }

    function isProviderRegistered(
        address _wallet
    )
        external
        view
        returns(bool)
    {
        return
            providerWallet[_wallet]!=0;
    }

    // ==========================================================
    // EMERGENCY PAUSE
    // ==========================================================

    function emergencyPause()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _pause();

        emit ContractPaused(msg.sender);
    }

    function resumeSystem()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _unpause();

        emit ContractUnpaused(msg.sender);
    }

    // ==========================================================
    // VERSION
    // ==========================================================

    function version()
        external
        pure
        returns(string memory)
    {
        return "1.0.0";
    }

    // ==========================================================
    // INTERFACE SUPPORT
    // ==========================================================

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(AccessControl)
        returns(bool)
    {
        return
            super.supportsInterface(
                interfaceId
            );
    }
}