use std::fs::File;
use std::os::unix::io::AsRawFd;
use nix::libc;

const NVME_ADMIN_SANITIZE_NVM: u8 = 0x84;
const NVME_IOCTL_ADMIN_CMD: u64 = 0xC0484E41; 

#[repr(C)]
pub struct NvmeAdminCmd {
    pub opcode: u8,
    pub flags: u8,
    pub reserved1: u16,
    pub nsid: u32,
    pub cdw2: u32,
    pub cdw3: u32,
    pub metadata: u64,
    pub addr: u64,
    pub metadata_len: u32,
    pub data_len: u32,
    pub cdw10: u32, 
    pub cdw11: u32,
    pub cdw12: u32,
    pub cdw13: u32,
    pub cdw14: u32,
    pub cdw15: u32,
    pub timeout_ms: u32,
    pub result: u32,
}

pub fn execute_sanitize(device: &str) -> std::io::Result<()> {
    let file = File::open(device)?;
    let fd = file.as_raw_fd();
    let mut cmd = unsafe { std::mem::zeroed::<NvmeAdminCmd>() };
    cmd.opcode = NVME_ADMIN_SANITIZE_NVM;
    cmd.cdw10 = 0x02;

    unsafe {
        let ret = libc::ioctl(fd, NVME_IOCTL_ADMIN_CMD as libc::c_ulong, &cmd);
        if ret != 0 {
            eprintln!("[ERROR] IOCTL Failure: Drive might be frozen or locked.");
            return Err(std::io::Error::last_os_error());
        }
    }

    println!("[+] Firmware acknowledged Sanitize command. Wiping NVMe NAND cells...");
    Ok(())
}