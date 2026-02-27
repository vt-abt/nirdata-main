import subprocess
import asyncio
from fastapi import FastAPI, BackgroundTasks, HTTPException
from pydantic import BaseModel
from typing import Dict, Optional
import uuid
from bridge.blockchain_client import anchor_wipe_to_blockchain
from bridge.entropy_checker import run_ai_verification

app = FastAPI(title="NirData Orchestrator API")

# In-memory store for session tracking during Live Boot
wipe_sessions: Dict[str, dict] = {}

class WipeRequest(BaseModel):
    target_device: str  # e.g., /dev/nvme0n1 or /dev/sda
    method: str         # NIST_800_88_PURGE or CRYPTO_ERASE
    operator_id: str
    manufacturer: str
    model: str
    serial: str

@app.post("/api/v1/wipe/start")
async def start_wipe(request: WipeRequest, background_tasks: BackgroundTasks):
    session_id = str(uuid.uuid4())
    wipe_sessions[session_id] = {
        "status": "INITIALIZING",
        "progress": 0,
        "device": request.dict(),
        "blockchain_tx": None
    }
    
    background_tasks.add_task(execute_wipe_workflow, session_id, request)
    return {"session_id": session_id, "status": "QUEUED"}

async def execute_wipe_workflow(session_id: str, request: WipeRequest):
    try:
        # 1. SYSTEMS LAYER: Execute Rust Wiping Engine
        wipe_sessions[session_id]["status"] = "WIPING"
        # Calling the compiled Rust binary with sub-process management
        process = subprocess.run(
            ["/usr/bin/nirdata-core", request.target_device],
            capture_output=True, text=True, check=True
        )
        
        # 2. AI LAYER: Perform AMD ROCm-accelerated Entropy Analysis
        wipe_sessions[session_id]["status"] = "VERIFYING_ENTROPY"
        # Sampling the first 1GB of the disk for verification
        is_clean, entropy_hash = run_ai_verification(request.target_device)
        
        if not is_clean:
            wipe_sessions[session_id]["status"] = "VERIFICATION_FAILED"
            return

        # 3. TRUST LAYER: Anchor to Blockchain (Sepolia)
        wipe_sessions[session_id]["status"] = "ANCHORING_BLOCKCHAIN"
        tx_hash = anchor_wipe_to_blockchain(
            request.manufacturer,
            request.model,
            request.serial,
            "SSD" if "nvme" in request.target_device else "HDD",
            request.method,
            entropy_hash,
            request.operator_id,
            is_clean
        )
        
        wipe_sessions[session_id]["status"] = "COMPLETED"
        wipe_sessions[session_id]["blockchain_tx"] = tx_hash
        
    except subprocess.CalledProcessError as e:
        wipe_sessions[session_id]["status"] = "HARDWARE_FAILURE"
        wipe_sessions[session_id]["error"] = str(e.stderr)
    except Exception as e:
        wipe_sessions[session_id]["status"] = "SYSTEM_ERROR"
        wipe_sessions[session_id]["error"] = str(e)

@app.get("/api/v1/certificate/{cert_hash}")
async def get_frontend_certificate(cert_hash: str):
    # This queries your Solidity contract via getCertificate(_id)
    # and returns the JSON specifically for the Tailwind frontend above
    raw_data = get_from_blockchain(cert_hash)
    return {
        "manufacturer": raw_data['device']['manufacturer'],
        "model": raw_data['device']['model'],
        "tx_hash": cert_hash,
        "timestamp": raw_data['audit']['timestamp']
    }
import subprocess

async def wipe_android_device(device_id: str):
    """
    Advanced Android Sanitization Workflow.
    Uses ADB to zero-fill user-data partitions before triggering TEE-key destruction.
    """
    try:
        # 1. Capture metadata for the Blockchain Certificate
        imei = subprocess.check_output(f"adb -s {device_id} shell service call iphonesubinfo 1", shell=True)
        
        # 2. Overwrite /data partition to prevent chip-off recovery
        # This fills the free space with a large zero file until the disk is full
        print(f"[*] Zero-filling storage on {device_id}...")
        subprocess.run(f"adb -s {device_id} shell 'dd if=/dev/zero of=/data/local/tmp/wipefile bs=1M'", shell=True)
        subprocess.run(f"adb -s {device_id} shell 'rm /data/local/tmp/wipefile'", shell=True)
        
        # 3. Trigger Factory Reset (Destroys FBE keys)
        print("[!] Triggering Master Clear (Factory Reset)...")
        subprocess.run(f"adb -s {device_id} shell am broadcast -a android.intent.action.MASTER_CLEAR", shell=True)
        
        return True, "NIST_800_88_MOBILE_PURGE"
    except Exception as e:
        return False, str(e)