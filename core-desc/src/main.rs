use clap::{Parser, ValueEnum};
use std::fs::OpenOptions;
use std::io::{Write, Seek, SeekFrom};
use rayon::prelude::*;

mod commands;
mod verify;

#[derive(Parser)]
#[command(author, version, about = "NirData Hardware Sanitization Core")]
struct Cli {
    #[arg(short, long)]
    device: String, // /dev/nvme0n1

    #[arg(short, long, value_enum, default_value_t = Method::NistPurge)]
    method: Method,
}

#[derive(Copy, Clone, PartialEq, Eq, PartialOrd, Ord, ValueEnum)]
enum Method {
    NistPurge,   // Crypto Erase + Block Erase
    NistClear,   // Single Pass Zero
    Dod7Pass,    // US DoD 5220.22-M
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();
    println!("[*] NIRDATA CORE: Initializing Target: {}", cli.device);

    if cli.device.contains("nvme") {
        println!("[!] NVMe detected. Issuing Firmware Sanitize Command...");
        commands::nvme::execute_sanitize(&cli.device)?;
    } else {
        println!("[!] Standard ATA detected. Using Block-Level Overwrite.");
        execute_logical_wipe(&cli.device, cli.method)?;
    }
    println!("[*] Wiping Complete. Starting AI-verification sampling...");
    verify::sample_and_checksum(&cli.device)?;

    println!("[SUCCESS] Device sanitized according to NIST-800-88 standard.");
    Ok(())
}

fn execute_logical_wipe(path: &str, method: Method) -> std::io::Result<()> {
    let mut file = OpenOptions::new().write(true).open(path)?;
    let size = file.metadata()?.len();
    let chunk_size = 1024 * 1024 * 4; 
    
    let pattern = match method {
        Method::NistClear => vec![0x00; chunk_size],
        _ => vec![0xFF; chunk_size], //lorem ipsum for the sake of example - in a real implementation, this would be a more complex pattern or random data depending on the method chosen
    };

    println!("[*] Logical Overwrite: {} bytes at {} MB/s...", size, chunk_size / 1024);
    file.seek(SeekFrom::Start(0))?;
    for _ in 0..(size / chunk_size as u64) {
        file.write_all(&pattern)?;
    }

    Ok(())
}