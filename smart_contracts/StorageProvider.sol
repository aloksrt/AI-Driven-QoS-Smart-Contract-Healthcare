// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title StorageProvider
 * @author Alock Gupta
 * @notice Secure Storage Provider for Healthcare Blockchain
 * @dev Companion contract for HealthcareQoS.sol
 */

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract StorageProvider is
    AccessControl,
    Pausable,
    ReentrancyGuard
{

    // ==========================================================
    // ROLES
    // ==========================================================

    bytes32 public constant STORAGE_ADMIN_ROLE =
        keccak256("STORAGE_ADMIN_ROLE");

    bytes32 public constant HEALTHCARE_ROLE =
        keccak256("HEALTHCARE_ROLE");

    bytes32 public constant AUDITOR_ROLE =
        keccak256("AUDITOR_ROLE");

    // ==========================================================
    // ENUMS
    // ==========================================================

    enum RecordStatus{
        ACTIVE,
        ARCHIVED,
        DELETED
    }

    // ==========================================================
    // STRUCTURES
    // ==========================================================

    struct Metadata{

        uint256 recordId;

        uint256 patientId;

        address owner;

        string ipfsCID;

        bytes32 fileHash;

        string fileType;

        string category;

        uint256 version;

        uint256 uploadedAt;

        RecordStatus status;

    }

    struct AuditLog{

        address actor;

        string action;

        uint256 timestamp;

    }

    // ==========================================================
    // STORAGE
    // ==========================================================

    uint256 public metadataCounter;

    mapping(uint256 => Metadata)
        private metadataStore;

    mapping(uint256 => AuditLog[])
        private auditLogs;

    mapping(uint256 => uint256[])
        private patientRecords;

    // ==========================================================
    // EVENTS
    // ==========================================================

    event MetadataStored(
        uint256 indexed recordId,
        uint256 indexed patientId,
        string ipfsCID
    );

    event MetadataUpdated(
        uint256 indexed recordId,
        uint256 version
    );

    event RecordArchived(
        uint256 indexed recordId
    );

    event RecordDeleted(
        uint256 indexed recordId
    );

    event AuditRecorded(
        uint256 indexed recordId,
        address actor,
        string action
    );

    // ==========================================================
    // ERRORS
    // ==========================================================

    error InvalidRecord();

    error Unauthorized();

    error RecordNotFound();

    error AlreadyExists();

    // ==========================================================
    // CONSTRUCTOR
    // ==========================================================

    constructor(){

        _grantRole(
            DEFAULT_ADMIN_ROLE,
            msg.sender
        );

        _grantRole(
            STORAGE_ADMIN_ROLE,
            msg.sender
        );

    }
    // ==========================================================
    // STORE METADATA
    // ==========================================================

    function storeMetadata(

        uint256 _patientId,

        string memory _ipfsCID,

        bytes32 _fileHash,

        string memory _fileType,

        string memory _category

    )
        external
        onlyRole(HEALTHCARE_ROLE)
        whenNotPaused
        nonReentrant
    {

        metadataCounter++;

        metadataStore[metadataCounter] = Metadata({

            recordId: metadataCounter,

            patientId: _patientId,

            owner: msg.sender,

            ipfsCID: _ipfsCID,

            fileHash: _fileHash,

            fileType: _fileType,

            category: _category,

            version: 1,

            uploadedAt: block.timestamp,

            status: RecordStatus.ACTIVE

        });

        patientRecords[_patientId].push(
            metadataCounter
        );

        auditLogs[metadataCounter].push(

            AuditLog({

                actor: msg.sender,

                action: "Record Created",

                timestamp: block.timestamp

            })

        );

        emit MetadataStored(

            metadataCounter,

            _patientId,

            _ipfsCID

        );

        emit AuditRecorded(

            metadataCounter,

            msg.sender,

            "Record Created"

        );

    }

    // ==========================================================
    // UPDATE METADATA
    // ==========================================================

    function updateMetadata(

        uint256 _recordId,

        string memory _ipfsCID,

        bytes32 _fileHash

    )
        external
        onlyRole(HEALTHCARE_ROLE)
        whenNotPaused
    {

        if(_recordId==0 ||
            _recordId>metadataCounter)
            revert RecordNotFound();

        Metadata storage record =
            metadataStore[_recordId];

        record.ipfsCID = _ipfsCID;

        record.fileHash = _fileHash;

        record.version++;

        auditLogs[_recordId].push(

            AuditLog({

                actor: msg.sender,

                action: "Record Updated",

                timestamp: block.timestamp

            })

        );

        emit MetadataUpdated(

            _recordId,

            record.version

        );

        emit AuditRecorded(

            _recordId,

            msg.sender,

            "Record Updated"

        );

    }

    // ==========================================================
    // RECORD RETRIEVAL
    // ==========================================================

    function getMetadata(

        uint256 _recordId

    )
        external
        view
        returns(

            Metadata memory

        )
    {

        if(_recordId==0 ||
            _recordId>metadataCounter)
            revert RecordNotFound();

        return metadataStore[_recordId];

    }

    function getPatientRecords(

        uint256 _patientId

    )
        external
        view
        returns(uint256[] memory)
    {

        return patientRecords[_patientId];

    }

    // ==========================================================
    // HASH VALIDATION
    // ==========================================================

    function verifyIntegrity(

        uint256 _recordId,

        bytes32 _hash

    )
        external
        view
        returns(bool)
    {

        return

            metadataStore[_recordId]

            .fileHash == _hash;

    }

    // ==========================================================
    // IPFS INFORMATION
    // ==========================================================

    function getIPFSCID(

        uint256 _recordId

    )
        external
        view
        returns(string memory)
    {

        return

            metadataStore[_recordId]

            .ipfsCID;

    }

    function latestVersion(

        uint256 _recordId

    )
        external
        view
        returns(uint256)
    {

        return

            metadataStore[_recordId]

            .version;

    }
    // ==========================================================
    // RECORD ARCHIVING
    // ==========================================================

    function archiveRecord(
        uint256 _recordId
    )
        external
        onlyRole(STORAGE_ADMIN_ROLE)
        whenNotPaused
    {

        if(_recordId==0 ||
            _recordId>metadataCounter)
            revert RecordNotFound();

        metadataStore[_recordId].status =
            RecordStatus.ARCHIVED;

        auditLogs[_recordId].push(

            AuditLog({

                actor: msg.sender,

                action: "Record Archived",

                timestamp: block.timestamp

            })

        );

        emit RecordArchived(_recordId);

        emit AuditRecorded(
            _recordId,
            msg.sender,
            "Record Archived"
        );
    }

    // ==========================================================
    // DELETE RECORD
    // ==========================================================

    function deleteRecord(
        uint256 _recordId
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {

        if(_recordId==0 ||
            _recordId>metadataCounter)
            revert RecordNotFound();

        metadataStore[_recordId].status =
            RecordStatus.DELETED;

        auditLogs[_recordId].push(

            AuditLog({

                actor: msg.sender,

                action: "Record Deleted",

                timestamp: block.timestamp

            })

        );

        emit RecordDeleted(_recordId);

        emit AuditRecorded(
            _recordId,
            msg.sender,
            "Record Deleted"
        );
    }

    // ==========================================================
    // AUDIT LOGS
    // ==========================================================

    function getAuditLogs(
        uint256 _recordId
    )
        external
        view
        returns(AuditLog[] memory)
    {

        if(_recordId==0 ||
            _recordId>metadataCounter)
            revert RecordNotFound();

        return auditLogs[_recordId];
    }

    // ==========================================================
    // SEARCH FUNCTIONS
    // ==========================================================

    function recordExists(
        uint256 _recordId
    )
        public
        view
        returns(bool)
    {
        return (
            _recordId>0 &&
            _recordId<=metadataCounter &&
            metadataStore[_recordId].status
                != RecordStatus.DELETED
        );
    }

    function getRecordStatus(
        uint256 _recordId
    )
        external
        view
        returns(RecordStatus)
    {
        return metadataStore[_recordId].status;
    }

    function getOwner(
        uint256 _recordId
    )
        external
        view
        returns(address)
    {
        return metadataStore[_recordId].owner;
    }

    // ==========================================================
    // STORAGE ANALYTICS
    // ==========================================================

    function totalRecords()
        external
        view
        returns(uint256)
    {
        return metadataCounter;
    }

    function activeRecords()
        external
        view
        returns(uint256 total)
    {
        for(uint256 i=1;i<=metadataCounter;i++)
        {
            if(
                metadataStore[i].status
                == RecordStatus.ACTIVE
            )
            {
                total++;
            }
        }
    }

    function archivedRecords()
        external
        view
        returns(uint256 total)
    {
        for(uint256 i=1;i<=metadataCounter;i++)
        {
            if(
                metadataStore[i].status
                == RecordStatus.ARCHIVED
            )
            {
                total++;
            }
        }
    }

    function deletedRecords()
        external
        view
        returns(uint256 total)
    {
        for(uint256 i=1;i<=metadataCounter;i++)
        {
            if(
                metadataStore[i].status
                == RecordStatus.DELETED
            )
            {
                total++;
            }
        }
    }

    // ==========================================================
    // STORAGE UTILITIES
    // ==========================================================

    function latestRecordId()
        external
        view
        returns(uint256)
    {
        return metadataCounter;
    }

    function latestUploadTime(
        uint256 _recordId
    )
        external
        view
        returns(uint256)
    {
        return metadataStore[_recordId].uploadedAt;
    }

    function recordVersion(
        uint256 _recordId
    )
        external
        view
        returns(uint256)
    {
        return metadataStore[_recordId].version;
    }
    // ==========================================================
    // ADMINISTRATIVE ROLE MANAGEMENT
    // ==========================================================

    function grantStorageAdminRole(
        address _account
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(
            STORAGE_ADMIN_ROLE,
            _account
        );
    }

    function revokeStorageAdminRole(
        address _account
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _revokeRole(
            STORAGE_ADMIN_ROLE,
            _account
        );
    }

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

    function grantAuditorRole(
        address _account
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(
            AUDITOR_ROLE,
            _account
        );
    }

    function revokeAuditorRole(
        address _account
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _revokeRole(
            AUDITOR_ROLE,
            _account
        );
    }

    // ==========================================================
    // PAUSE / UNPAUSE
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
    // ROLE VALIDATION
    // ==========================================================

    function isStorageAdmin(
        address _account
    )
        external
        view
        returns(bool)
    {
        return hasRole(
            STORAGE_ADMIN_ROLE,
            _account
        );
    }

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

    function isAuditor(
        address _account
    )
        external
        view
        returns(bool)
    {
        return hasRole(
            AUDITOR_ROLE,
            _account
        );
    }

    // ==========================================================
    // STORAGE STATISTICS
    // ==========================================================

    function totalAuditEntries(
        uint256 _recordId
    )
        external
        view
        returns(uint256)
    {
        return auditLogs[_recordId].length;
    }

    function latestAuditEntry(
        uint256 _recordId
    )
        external
        view
        returns(AuditLog memory)
    {
        uint256 length =
            auditLogs[_recordId].length;

        require(
            length > 0,
            "No audit logs available"
        );

        return auditLogs[_recordId][length - 1];
    }

    // ==========================================================
    // CONTRACT INFORMATION
    // ==========================================================

    function contractName()
        external
        pure
        returns(string memory)
    {
        return "StorageProvider";
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
        return super.supportsInterface(
            interfaceId
        );
    }
}
