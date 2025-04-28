# Intro

The scripts addresses a minor inconvenience that I face in my life. Running computationally intensive pipelines and projects often requires the use of remote computers, as my personal laptop lacks the necessary power. I rely on designated PCs provided by the faculty/university, accessible via SSH. However, these PCs frequently go online or offline, or may not have nvdia-gpu accessible making it a hassle to find a working one. One of the script pings the PC addresses and  identifies which PCs are currently online and accessible via SSH. Another script checks if NVDIA hardware is present and drivers are correctly accessible.


# Server Status Checkers

This repository contains scripts to check the status of a range of servers.

## Scripts

1.  **`check_gpu_driver.sh`**: Checks for NVIDIA GPU presence and driver health via SSH.
2.  **`check_server_status.sh`**: Checks basic server reachability using `ping`.

---

## `check_gpu_driver.sh` - GPU and Driver Status Checker

This script checks a range of servers for the presence of NVIDIA GPUs and the status of their drivers.

### Features

*   Checks a configurable range of servers.
*   Uses SSH to connect (requires `sshpass` for non-interactive password authentication).
*   Detects NVIDIA hardware using `lspci`.
*   Checks NVIDIA driver status using `nvidia-smi`.
*   Reports detailed status including hardware presence, driver health (OK, Mismatch, Not Installed), and connection errors.
*   Reads credentials securely from environment variables (`CHECK_GPU_USER`, `CHECK_GPU_PASS`).
*   Provides debug output (`-d` flag) for troubleshooting.

### Dependencies

*   `bash`, `ssh`, `sshpass`, `seq`, `grep`, `awk`.
*   Remote servers need `lspci` (usually part of `pciutils`).

### Setup

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd <repository-directory>
    ```

2.  **Install Dependencies:** Ensure `sshpass` is installed locally.

3.  **Configure Credentials:**
    *   Copy the example environment file:
        ```bash
        cp .env.example .env
        ```
    *   **Edit `.env`** and fill in your actual SSH username and password for `CHECK_GPU_USER` and `CHECK_GPU_PASS`.
        ```dotenv
        export CHECK_GPU_USER="your_real_username"
        export CHECK_GPU_PASS="your_real_password"
        ```
    *   **IMPORTANT:** The `.env` file is listed in `.gitignore` and should **never** be committed to version control.

4.  **Set Optional Configuration (Optional):**
    *   You can override the default server prefix, range, and address for this script by setting `CHECK_GPU_PREFIX`, `CHECK_GPU_START`, `CHECK_GPU_END`, `CHECK_GPU_ADDRESS` in your `.env` file (with `export`).

5.  **Make the script executable:**
    ```bash
    chmod +x check_gpu_driver.sh
    ```

### Usage

*The script will automatically detect and load environment variables from a `.env` file located in the same directory if it exists.* Alternatively, you can pre-export the required variables (`CHECK_GPU_USER`, `CHECK_GPU_PASS`) in your shell.

1.  **Run the script:**
    *   Standard: `./check_gpu_driver.sh`
    *   Debug: `./check_gpu_driver.sh -d`
    *   Help: `./check_gpu_driver.sh -h`

2.  **Check Results:** Output printed to terminal. Detailed results saved to `gpu_detailed_status.txt`.

### Output Format (`gpu_detailed_status.txt`)

*   **Success:** `server.example.com: <Hardware Status>; Driver: <Driver Status>`
*   **Connection Failure:** `server.example.com: <Connection Error>`

---

## `check_server_status.sh` - Basic Server Ping Status

This script checks if a range of servers are reachable via `ping`.

### Features

*   Checks a configurable range of servers.
*   Uses `ping` to determine reachability.
*   Reports status as `Online` or `Offline`.
*   Reads server configuration from environment variables (`CHECK_SERVER_PREFIX`, `CHECK_SERVER_START`, etc.).
*   Provides debug output (`-d` flag).

### Dependencies

*   `bash`, `ping`, `seq`.

### Setup

1.  **(If not already done) Clone the repository.**
2.  **Set Optional Configuration (Optional):**
    *   You can override the default server prefix, range, and address for this script by setting `CHECK_SERVER_PREFIX`, `CHECK_SERVER_START`, `CHECK_SERVER_END`, `CHECK_SERVER_ADDRESS` in your `.env` file (remember to add `export`) or by pre-exporting them in your shell.
3.  **Make the script executable:**
    ```bash
    chmod +x check_server_status.sh
    ```

### Usage

*The script will automatically detect and load environment variables from a `.env` file located in the same directory if it exists.* Alternatively, you can pre-export any optional variables (`CHECK_SERVER_*`) in your shell.

1.  **Run the script:**
    *   Standard: `./check_server_status.sh`
    *   Debug: `./check_server_status.sh -d`
    *   Help: `./check_server_status.sh -h`

2.  **Check Results:** Output printed to terminal. Results saved to `server_status.txt`.

### Output Format (`server_status.txt`)

*   `server.example.com: Online`
*   `server.example.com: Offline`

