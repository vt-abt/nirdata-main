import os
from web3 import Web3
from dotenv import load_dotenv

load_dotenv()

RPC_URL = "https://sepolia.infura.io/v3/YOUR_INFURA_KEY" # Replace with your Infura Project ID or other Ethereum node URL
CONTRACT_ADDRESS = "0xb259ef889Be5cDa88E56096AD98592C05A7A6F18"
PRIVATE_KEY = os.getenv("WIPE_OPERATOR_KEY")

ABI = [...] # The ABI of the NirDataCertifier contract, which should be defined here or imported from a separate file

w3 = Web3(Web3.HTTPProvider(RPC_URL))
contract = w3.eth.contract(address=CONTRACT_ADDRESS, abi=ABI)

def anchor_wipe_to_blockchain(mfg, model, serial, media, method, entropy_hash, op_id, status):
    """
    Signs and sends a transaction to the NirDataCertifier contract.
    Returns the Transaction Hash.
    """
    account = w3.eth.account.from_key(PRIVATE_KEY)
    
    # Construct Transaction
    nonce = w3.eth.get_transaction_count(account.address)
    
    tx = contract.functions.anchorCertificate(
        mfg, model, serial, media, method, entropy_hash, op_id, status
    ).build_transaction({
        'chainId': 11155111, # Sepolia
        'gas': 300000,
        'gasPrice': w3.eth.gas_price,
        'nonce': nonce,
    })

    # Sign and Send
    signed_tx = w3.eth.account.sign_transaction(tx, private_key=PRIVATE_KEY)
    tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
    return w3.to_hex(tx_hash)