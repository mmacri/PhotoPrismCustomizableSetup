# PhotoPrism and Portainer Setup Script

This repository provides a comprehensive script to set up the PhotoPrism stack, including:

- **PhotoPrism**: A photo management platform.
- **MariaDB**: A relational database to store PhotoPrism data.
- **Nginx**: A reverse proxy with automatically generated self-signed SSL certificates.
- **Portainer** (optional): A web-based Docker container management tool.
- **Backup and Restore Scripts**: Automates MariaDB backups and provides a restoration script.

The script is designed to work seamlessly on **Linux**, **macOS**, and **Windows** (via Docker Desktop and Git Bash).

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Usage Instructions](#usage-instructions)
4. [Features](#features)
5. [Customization Prompts](#customization-prompts)
6. [Generated Outputs](#generated-outputs)
7. [Backup and Restore Instructions](#backup-and-restore-instructions)
8. [Troubleshooting](#troubleshooting)
9. [Security Considerations](#security-considerations)
10. [Recommendations for Advanced Users](#recommendations-for-advanced-users)
11. [Testing Status](#testing-status)
12. [License](#license)
13. [Contributing](#contributing)

---

## Overview

This script automates the deployment of a PhotoPrism stack, ensuring that all required components are configured and ready to use. The setup includes automated SSL certificate generation, Docker Compose configuration, and an optional Portainer installation. It also provides database backup and restoration scripts to secure and recover your data.

---

## Prerequisites

Before running the script, ensure the following software is installed:

1. **Docker**: Required to run containers.
   - **Linux**: Install using your package manager (e.g., `sudo apt install docker.io`).
   - **macOS**: Install using Homebrew (`brew install --cask docker`).
   - **Windows**: Install [Docker Desktop](https://www.docker.com/products/docker-desktop) and ensure it is running.

2. **Docker Compose**: Required for orchestrating containers.
   - **Linux**: Install using `sudo apt install docker-compose`.
   - **macOS & Windows**: Included with Docker Desktop.

3. **OpenSSL**: Required for generating SSL certificates.
   - **Linux**: Install using `sudo apt install openssl`.
   - **macOS**: Install using Homebrew (`brew install openssl`).
   - **Windows**: Install using [Chocolatey](https://chocolatey.org/) (`choco install openssl`).

---

## Usage Instructions

### Step 1: Clone the Repository

```bash
git clone https://github.com/mmacri/PhotoPrismCustomizedSetup.git
cd PhotoPrismCustomizedSetup
```

### Step 2: Run the Setup Script

```bash
bash setup_photoprism_public.sh
```

### Step 3: Follow the Prompts

The script will prompt you to:

1. Specify a Docker network name.
2. Enter paths for storage and originals.
3. Provide admin credentials for PhotoPrism.
4. Enter a local IP or domain for SSL and Nginx configuration.
5. Choose whether to include Portainer.

Answer each prompt based on your environment and preferences.

---

## Features

1. **Self-Signed SSL Certificates**:
   - Automatically generated for the provided domain or IP.
   - Ensures secure access to PhotoPrism and Portainer.

2. **Dynamic Docker Compose Configuration**:
   - Automatically creates a `docker-compose.yml` file tailored to your inputs.

3. **Backup and Restore Scripts**:
   - Automates MariaDB backups with a default retention of 7 days.
   - Includes a `restore_photoprism.sh` script to restore the database.

4. **Cross-Platform Support**:
   - Works seamlessly on Linux, macOS, and Windows (via Git Bash).

---

## Customization Prompts

### Example Inputs
1. **Docker Network Name**: Enter `my_docker_network` or press Enter for the default (`photoprism_network`).
2. **Storage Directory Path**: Provide the full path to a directory where PhotoPrism will store its data, e.g., `/home/user/photos/storage`.
3. **Originals Directory Path**: Provide the full path to a directory containing your original photos, e.g., `/home/user/photos/originals`.
4. **Local IP or Domain**: Enter `192.168.1.100` (for local use) or a domain like `photos.example.com`.
5. **Include Portainer**: Type `yes` to include Portainer or `no` to skip it.

---

## Generated Outputs

### Folder Structure
After running the script, the following structure is created:

```
PhotoPrismCustomizedSetup/
├── config/
│   ├── photoprism.env
│   ├── ssl/
│       ├── photoprism.crt
│       ├── photoprism.key
│       ├── openssl-san.cnf
├── scripts/
│   ├── backup_photoprism.sh
│   ├── restore_photoprism.sh
├── docker-compose.yml
├── setup_photoprism_public.sh
├── setup_photoprism.log
```

### Key Files
- **`docker-compose.yml`**: Defines Docker services.
- **`photoprism.env`**: Contains environment variables for PhotoPrism.
- **`ssl/`**: Contains SSL certificates.
- **`backup_photoprism.sh`**: Automates database backups.
- **`restore_photoprism.sh`**: Automates database restoration.

---

## Backup and Restore Instructions

### Backup Instructions
- The script `scripts/backup_photoprism.sh` automates backups for the MariaDB database.
- Backups are stored in the `backups/` directory and retained for 7 days by default.

To schedule automated backups:
- **Linux/macOS**: Use `cron` to schedule the script.
  ```bash
  crontab -e
  ```
  Add the following line to run the backup daily at midnight:
  ```
  0 0 * * * /path/to/scripts/backup_photoprism.sh
  ```
- **Windows**: Use Task Scheduler to run the script periodically.

### Restore Instructions
- Use the `restore_photoprism.sh` script to restore the database from a backup file:
  ```bash
  bash scripts/restore_photoprism.sh <backup-file.sql>
  ```
- **Important**: Ensure the target database is not in use during restoration.

---

## Troubleshooting

### Common Issues

1. **Docker Not Running**:
   - Ensure Docker Desktop or the Docker service is running before executing the script.

2. **Invalid Paths**:
   - Verify that the storage and originals directories exist.

3. **SSL Certificate Errors**:
   - Ensure OpenSSL is installed and accessible.

4. **Portainer Not Accessible**:
   - Verify that Docker is exposing Portainer on port `9000`.

### Viewing Logs

Logs for the script are saved in `setup_photoprism.log`. Review this file for detailed error messages.

---

## Security Considerations

1. **Change Default Passwords**:
   - Update the default MariaDB password in `photoprism.env`.

2. **Secure Secrets**:
   - Avoid storing secrets directly in `.env`. Use a secret manager for production setups.

3. **SSL Certificates**:
   - Self-signed certificates are suitable for internal use. Use a trusted CA for production environments.

---

## Recommendations for Advanced Users

1. **Scaling and Load Balancing**:
   - Use external database services like Amazon RDS or Google Cloud SQL for scalability.
   - Configure Nginx as a load balancer for multiple PhotoPrism instances.

2. **Production Secrets Management**:
   - Use tools like HashiCorp Vault or AWS Secrets Manager to store sensitive credentials.

3. **Custom SSL Certificates**:
   - Replace self-signed certificates with Let’s Encrypt or other CA-provided certificates by placing them in the `config/ssl` directory.

4. **Firewall and Port Security**:
   - Restrict access to sensitive ports using firewall rules or Docker network policies.

---

## Testing Status

This script has been tested on the following platforms:

- **Linux**: Ubuntu 20.04 with Docker 20.10.
- **macOS**: macOS Monterey with Docker Desktop 4.5.
- **Windows**: Windows 11 Pro with Docker Desktop 4.5 and Git Bash.

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

---

## Contributing

We welcome contributions! Please refer to `CONTRIBUTING.md` for detailed guidelines on how to contribute to this project.

