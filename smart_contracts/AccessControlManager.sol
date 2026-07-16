// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title AccessControlManager
 * @author Alock Gupta
 * @notice Role-Based Access Control Manager for AI-Driven Healthcare Blockchain
 * @dev Companion contract for HealthcareQoS.sol
 */

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AccessControlManager is
    AccessControl,
    Pausable,
    ReentrancyGuard
{

    // ==========================================================
    // ROLE DEFINITIONS
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

    bytes32 public constant EMERGENCY_ROLE =
        keccak256("EMERGENCY_ROLE");

    // ==========================================================
    // STRUCTURES
    // ==========================================================

    struct UserProfile{

        address wallet;

        string name;

        string organization;

        string specialization;

        bool active;

        uint256 createdAt;

    }

    struct Consent{

        bool granted;

        uint256 grantedAt;

        uint256 expiry;

    }

    // ==========================================================
    // STORAGE
    // ==========================================================

    mapping(address => UserProfile)

        private profiles;

    mapping(address => bool)

        public registered;

    mapping(address => mapping(address => Consent))

        private patientConsent;

    // ==========================================================
    // EVENTS
    // ==========================================================

    event UserRegistered(

        address indexed wallet,

        string name,

        bytes32 role

    );

    event ConsentGranted(

        address indexed patient,

        address indexed provider

    );

    event ConsentRevoked(

        address indexed patient,

        address indexed provider

    );

    event EmergencyAccessGranted(

        address indexed provider,

        uint256 timestamp

    );

    event EmergencyAccessRevoked(

        address indexed provider,

        uint256 timestamp

    );

    // ==========================================================
    // CUSTOM ERRORS
    // ==========================================================

    error AlreadyRegistered();

    error InvalidUser();

    error ConsentExpired();

    error AccessDenied();

    error InvalidAddress();

    // ==========================================================
    // CONSTRUCTOR
    // ==========================================================

    constructor(){

        _grantRole(

            DEFAULT_ADMIN_ROLE,

            msg.sender

        );

    }
    // ==========================================================
    // USER REGISTRATION
    // ==========================================================

    function registerPatient(
        string memory _name
    )
        external
        whenNotPaused
    {
        if (registered[msg.sender])
            revert AlreadyRegistered();

        profiles[msg.sender] = UserProfile({
            wallet: msg.sender,
            name: _name,
            organization: "",
            specialization: "",
            active: true,
            createdAt: block.timestamp
        });

        registered[msg.sender] = true;

        _grantRole(PATIENT_ROLE, msg.sender);

        emit UserRegistered(
            msg.sender,
            _name,
            PATIENT_ROLE
        );
    }

    function registerDoctor(
        string memory _name,
        string memory _hospital,
        string memory _specialization
    )
        external
        whenNotPaused
    {
        if (registered[msg.sender])
            revert AlreadyRegistered();

        profiles[msg.sender] = UserProfile({
            wallet: msg.sender,
            name: _name,
            organization: _hospital,
            specialization: _specialization,
            active: true,
            createdAt: block.timestamp
        });

        registered[msg.sender] = true;

        _grantRole(DOCTOR_ROLE, msg.sender);

        emit UserRegistered(
            msg.sender,
            _name,
            DOCTOR_ROLE
        );
    }

    function registerHospital(
        string memory _hospitalName
    )
        external
        whenNotPaused
    {
        if (registered[msg.sender])
            revert AlreadyRegistered();

        profiles[msg.sender] = UserProfile({
            wallet: msg.sender,
            name: _hospitalName,
            organization: _hospitalName,
            specialization: "",
            active: true,
            createdAt: block.timestamp
        });

        registered[msg.sender] = true;

        _grantRole(HOSPITAL_ROLE, msg.sender);

        emit UserRegistered(
            msg.sender,
            _hospitalName,
            HOSPITAL_ROLE
        );
    }

    function registerLaboratory(
        string memory _labName
    )
        external
        whenNotPaused
    {
        if (registered[msg.sender])
            revert AlreadyRegistered();

        profiles[msg.sender] = UserProfile({
            wallet: msg.sender,
            name: _labName,
            organization: _labName,
            specialization: "Laboratory",
            active: true,
            createdAt: block.timestamp
        });

        registered[msg.sender] = true;

        _grantRole(LAB_ROLE, msg.sender);

        emit UserRegistered(
            msg.sender,
            _labName,
            LAB_ROLE
        );
    }

    function registerAIEngine(
        address _engine,
        string memory _name
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_engine == address(0))
            revert InvalidAddress();

        profiles[_engine] = UserProfile({
            wallet: _engine,
            name: _name,
            organization: "AI Engine",
            specialization: "QoS Prediction",
            active: true,
            createdAt: block.timestamp
        });

        registered[_engine] = true;

        _grantRole(AI_ENGINE_ROLE, _engine);

        emit UserRegistered(
            _engine,
            _name,
            AI_ENGINE_ROLE
        );
    }

    // ==========================================================
    // USER STATUS MANAGEMENT
    // ==========================================================

    function deactivateUser(
        address _user
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (!registered[_user])
            revert InvalidUser();

        profiles[_user].active = false;
    }

    function activateUser(
        address _user
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (!registered[_user])
            revert InvalidUser();

        profiles[_user].active = true;
    }

    // ==========================================================
    // VIEW FUNCTIONS
    // ==========================================================

    function getUserProfile(
        address _user
    )
        external
        view
        returns (UserProfile memory)
    {
        if (!registered[_user])
            revert InvalidUser();

        return profiles[_user];
    }

    function isRegistered(
        address _user
    )
        external
        view
        returns (bool)
    {
        return registered[_user];
    }

    function isActive(
        address _user
    )
        external
        view
        returns (bool)
    {
        return profiles[_user].active;
    }
    // ==========================================================
    // PATIENT CONSENT MANAGEMENT
    // ==========================================================

    function grantConsent(
        address _provider,
        uint256 _validityPeriod
    )
        external
        whenNotPaused
    {
        if (!registered[msg.sender])
            revert InvalidUser();

        if (!registered[_provider])
            revert InvalidUser();

        patientConsent[msg.sender][_provider] = Consent({
            granted: true,
            grantedAt: block.timestamp,
            expiry: block.timestamp + _validityPeriod
        });

        emit ConsentGranted(
            msg.sender,
            _provider
        );
    }

    function revokeConsent(
        address _provider
    )
        external
        whenNotPaused
    {
        if (!registered[msg.sender])
            revert InvalidUser();

        delete patientConsent[msg.sender][_provider];

        emit ConsentRevoked(
            msg.sender,
            _provider
        );
    }

    // ==========================================================
    // CONSENT VERIFICATION
    // ==========================================================

    function hasConsent(
        address _patient,
        address _provider
    )
        public
        view
        returns(bool)
    {
        Consent memory consent =
            patientConsent[_patient][_provider];

        if(!consent.granted)
            return false;

        if(block.timestamp > consent.expiry)
            return false;

        return true;
    }

    function getConsentDetails(
        address _patient,
        address _provider
    )
        external
        view
        returns(Consent memory)
    {
        return patientConsent[_patient][_provider];
    }

    // ==========================================================
    // EMERGENCY ACCESS
    // ==========================================================

    mapping(address => bool)
        public emergencyAccess;

    function grantEmergencyAccess(
        address _provider
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        emergencyAccess[_provider] = true;

        _grantRole(
            EMERGENCY_ROLE,
            _provider
        );

        emit EmergencyAccessGranted(
            _provider,
            block.timestamp
        );
    }

    function revokeEmergencyAccess(
        address _provider
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        emergencyAccess[_provider] = false;

        _revokeRole(
            EMERGENCY_ROLE,
            _provider
        );

        emit EmergencyAccessRevoked(
            _provider,
            block.timestamp
        );
    }

    function hasEmergencyAccess(
        address _provider
    )
        external
        view
        returns(bool)
    {
        return emergencyAccess[_provider];
    }

    // ==========================================================
    // PERMISSION VALIDATION
    // ==========================================================

    function canAccessPatientRecord(
        address _patient,
        address _provider
    )
        external
        view
        returns(bool)
    {
        if(hasRole(DEFAULT_ADMIN_ROLE,_provider))
            return true;

        if(hasRole(EMERGENCY_ROLE,_provider))
            return true;

        if(hasConsent(_patient,_provider))
            return true;

        return false;
    }

    function isDoctor(
        address _user
    )
        external
        view
        returns(bool)
    {
        return hasRole(
            DOCTOR_ROLE,
            _user
        );
    }

    function isHospital(
        address _user
    )
        external
        view
        returns(bool)
    {
        return hasRole(
            HOSPITAL_ROLE,
            _user
        );
    }

    function isLaboratory(
        address _user
    )
        external
        view
        returns(bool)
    {
        return hasRole(
            LAB_ROLE,
            _user
        );
    }

    function isAIEngine(
        address _user
    )
        external
        view
        returns(bool)
    {
        return hasRole(
            AI_ENGINE_ROLE,
            _user
        );
    }

    function isPatient(
        address _user
    )
        external
        view
        returns(bool)
    {
        return hasRole(
            PATIENT_ROLE,
            _user
        );
    }
    // ==========================================================
    // CONTRACT ADMINISTRATION
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
    // ROLE MANAGEMENT
    // ==========================================================

    function grantDoctorRole(
        address _user
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(DOCTOR_ROLE, _user);
    }

    function revokeDoctorRole(
        address _user
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _revokeRole(DOCTOR_ROLE, _user);
    }

    function grantHospitalRole(
        address _user
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(HOSPITAL_ROLE, _user);
    }

    function revokeHospitalRole(
        address _user
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _revokeRole(HOSPITAL_ROLE, _user);
    }

    function grantLabRole(
        address _user
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(LAB_ROLE, _user);
    }

    function revokeLabRole(
        address _user
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _revokeRole(LAB_ROLE, _user);
    }

    // ==========================================================
    // SYSTEM INFORMATION
    // ==========================================================

    function getSystemRoles(
        address _user
    )
        external
        view
        returns(
            bool isPatientRole,
            bool isDoctorRole,
            bool isHospitalRole,
            bool isLabRole,
            bool isAIRole,
            bool isEmergencyRole
        )
    {
        return (
            hasRole(PATIENT_ROLE, _user),
            hasRole(DOCTOR_ROLE, _user),
            hasRole(HOSPITAL_ROLE, _user),
            hasRole(LAB_ROLE, _user),
            hasRole(AI_ENGINE_ROLE, _user),
            hasRole(EMERGENCY_ROLE, _user)
        );
    }

    function totalRegisteredUsers(
        address[] memory _users
    )
        external
        view
        returns(uint256 total)
    {
        for(uint256 i = 0; i < _users.length; i++)
        {
            if(registered[_users[i]])
            {
                total++;
            }
        }
    }

    // ==========================================================
    // CONTRACT VERSION
    // ==========================================================

    function contractVersion()
        external
        pure
        returns(string memory)
    {
        return "1.0.0";
    }

    function contractName()
        external
        pure
        returns(string memory)
    {
        return "AccessControlManager";
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
