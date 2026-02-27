# NIRDATA: CRYPTOGRAPHICALLY VERIFIED HARDWARE SANITIZATION FRAMEWORK

OPERATIONAL SUMMARY
NirData is an industrial-grade data sanitization solution engineered for secure IT asset decommissioning. 
The system bridges the gap between physical disk erasure and digital trust by combining 
hardware-level execution (Rust), AI-driven anomaly detection (AMD ROCm), and immutable 
anchoring (Ethereum/Sepolia).

CORE PHASES OF OPERATION
1. KERNEL INITIALIZATION:
The system boots a custom Alpine-based Linux kernel (v6.x) configured with the copytoram flag. 
All operations occur in a volatile memory environment to prevent host-os interception or 
malware persistence.

2. SANITIZATION ENGINE (RUST):
The engine targets the block device directly, bypassing filesystem layers. 
- NVMe: Executes the 'Sanitize' command for Cryptographic Scramble or Block Erase.
- ATA: Issues 'Secure Erase Unit' (SEU) commands to the firmware.
- Fallback: NIST SP 800-88 compliant logical overwrite with multi-threaded entropy seeding.

3. AI ATTESTATION LAYER (AMD OPTIMIZED):
Standard bit-verification is insufficient. NirData implements an Anomaly Detection model 
accelerated by AMD ROCm. After erasure, the model performs high-frequency sampling of 
storage sectors. It analyzes the entropy distribution to ensure the resulting state is 
statistically indistinguishable from random noise, flagging non-random clusters that 
suggest hidden data fragments (DCO/HPA areas).

4. BLOCKCHAIN CERTIFICATION:
Successful sanitization generates a unique proof payload containing the device hardware UUID, 
wipe timestamp, and entropy score. This payload is hashed and stored in a Sepolia-anchored 
Smart Contract, providing an immutable "Certificate of Destruction" verifiable by any third-party.

TECHNICAL STACK
- Systems: Rust (Zero-cost abstractions, direct FFI to Linux ioctls)
- AI/ML: Python + PyTorch + AMD ROCm (GCN/RDNA architecture optimization)
- OS: Alpine Linux (musl libc, BusyBox-less execution loop)
- Trust: Solidity (EIP-721 compatible anchoring), Ethers.js