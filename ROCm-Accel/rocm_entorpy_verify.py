import torch
import math

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

class EntropyVerifier:
    """
    Utilizes GPU-accelerated bit-distribution analysis to verify 
    the probability of successful data destruction.
    """
    def __init__(self, threshold=0.9998):
        self.threshold = threshold

    def calculate_shannon_entropy(self, byte_tensor):
        """
        Ingests a 1D tensor of bytes. High-speed computation on AMD APU/GPU.
        """
        tensor_size = byte_tensor.size(0)
        _, counts = torch.unique(byte_tensor, return_counts=True)
        probs = counts.float() / tensor_size
        entropy = -torch.sum(probs * torch.log2(probs))
        return (entropy / 8.0).item() # Max entropy for byte = 8 bits

    def verify_buffer(self, buffer):
        data = torch.ByteTensor(list(buffer)).to(DEVICE)
        score = self.calculate_shannon_entropy(data)
        
        is_clean = score >= self.threshold
        return is_clean, score
