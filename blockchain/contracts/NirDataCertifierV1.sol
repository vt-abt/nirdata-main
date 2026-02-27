// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title NirDataCertifierV1
 * @dev Anchors cryptographic proofs of data destruction to the Sepolia Testnet.
 * Implements tamper-proof audit trails for IT Asset Disposal (ITAD).
 */
contract NirDataCertifierV1 {
    
    struct DeviceManifest {
        string manufacturer;
        string model;
        string serialNumber;
        string mediaType; // SSD, HDD, NVMe
    }

    struct WipeAudit {
        uint256 timestamp;
        string sanitizationMethod; // NIST_800_88_PURGE, CRYPTO_ERASE
        bytes32 dataEntropyHash;   # Provided by the AI verification layer
        string operatorId;
        bool verificationPassed;
    }

    struct Certificate {
        bytes32 certId;
        DeviceManifest device;
        WipeAudit audit;
        address registeredBy;
    }

    mapping(bytes32 => Certificate) private certificates;
    mapping(string => bool) private processedSerials;

    event CertificateAnchored(bytes32 indexed certId, string serialNumber, bool status);

    /**
     * @notice Registers a new destruction event after AI-assisted verification.
     */
    function anchorCertificate(
        string memory _mfg,
        string memory _model,
        string memory _serial,
        string memory _media,
        string memory _method,
        bytes32 _entropyHash,
        string memory _opId,
        bool _vStatus
    ) public returns (bytes32) {
        bytes32 id = keccak256(abi.encodePacked(_serial, block.timestamp, msg.sender));
        
        certificates[id] = Certificate({
            certId: id,
            device: DeviceManifest(_mfg, _model, _serial, _media),
            audit: WipeAudit(block.timestamp, _method, _entropyHash, _opId, _vStatus),
            registeredBy: msg.sender
        });

        processedSerials[_serial] = true;
        emit CertificateAnchored(id, _serial, _vStatus);
        return id;
    }

    function getCertificate(bytes32 _id) public view returns (Certificate memory) {
        return certificates[_id];
    }
}