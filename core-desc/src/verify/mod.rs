use std::fs::File;
use std::io::{Read, Seek, SeekFrom};
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

pub fn sample_and_checksum(path: &str) -> std::io::Result<String> {
    let mut file = File::open(path)?;
    let mut buffer = [0u8; 4096]; 
    let mut hasher = DefaultHasher::new();
    let locations = [0, 1024 * 1024 * 100, 1024 * 1024 * 500]; 
    
    for loc in locations {
        file.seek(SeekFrom::Start(loc))?;
        file.read_exact(&mut buffer)?;
        buffer.hash(&mut hasher);
   
    }
//hook for AI analysis - the resulting hash can be used to verify the integrity of the wipe process and detect any anomalies in the sampled data.
    let result_hash = format!("{:x}", hasher.finish());
    println!("[*] Block Verification Signature: {}", result_hash);
    
    Ok(result_hash)
}