# StackWatch CI/CD Setup Guide

Complete guide to set up the build and deployment pipeline for StackWatch.

---

## Overview

```
┌─────────────┐      ┌─────────────┐      ┌─────────────────────────────────┐
│   GitLab    │ ──►  │   Jenkins   │ ──►  │   Artifact Server               │
│  (Source)   │      │   (Build)   │      │   (artifact.stackbill.com)      │
└─────────────┘      └─────────────┘      └─────────────────────────────────┘
                                                      │
                                          ┌───────────┼───────────┐
                                          ▼           ▼           ▼
                                       /beta/     /latest/    /archive/
                                     (untested)   (stable)   (old versions)
```

---

## Step 1: GitLab Setup

### 1.1 Create Repository

Your code should be in GitLab at:
```
ssh://git@gitlab.assistanz24x7.com:223/stackwatch/stackwatch.git
```

### 1.2 Push Your Code

```bash
# If starting fresh
cd /path/to/stackwatch
git init
git remote add origin ssh://git@gitlab.assistanz24x7.com:223/stackwatch/stackwatch.git
git add .
git commit -m "Initial commit"
git push -u origin main

# If already have repo, just push
git push origin main
```

### 1.3 Important Files to Commit

Make sure these files are in your repo:
- `Jenkinsfile` - Pipeline configuration
- `package.json` - Node.js configuration
- `scripts/create-prebuilt-package.sh` - Build script
- All source code files

---

## Step 2: Artifact Server Setup

### 2.1 Server Requirements

- Linux server (Ubuntu/CentOS)
- Nginx installed
- Domain: `artifact.stackbill.com` pointing to server IP

### 2.2 Run Setup Script

Copy the `artifact-server/` folder to your server and run:

```bash
# On artifact server
cd /path/to/artifact-server
sudo chmod +x setup-artifact-server.sh
sudo ./setup-artifact-server.sh
```

This will:
- Install Nginx (if not present)
- Create `deploy` user
- Create directory structure
- Configure Nginx
- Create helper scripts

### 2.3 Directory Structure Created

```
/var/www/artifacts/
└── stackwatch/
    └── build/
        └── 2025/              # Year
            └── 01/            # Month
                ├── beta/      # New untested builds
                ├── latest/    # Tested stable builds
                └── archive/   # Old versions
```

### 2.4 Setup SSL

```bash
# Install certbot if not present
sudo apt-get install certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d artifact.stackbill.com
```

---

## Step 3: Jenkins Setup

### 3.1 Prerequisites on Jenkins Server

```bash
# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install jq (for JSON parsing)
sudo apt-get install -y jq

# Verify
node --version
npm --version
jq --version
```

### 3.2 Create SSH Key for Deployment

```bash
# On Jenkins server (as jenkins user)
sudo su - jenkins
ssh-keygen -t rsa -b 4096 -C "jenkins@stackwatch"

# View public key
cat ~/.ssh/id_rsa.pub
```

### 3.3 Add Public Key to Artifact Server

```bash
# On artifact server
sudo nano /home/deploy/.ssh/authorized_keys

# Paste the Jenkins public key and save
```

### 3.4 Add Credentials in Jenkins

1. Go to: **Jenkins > Manage Jenkins > Credentials**
2. Click: **Add Credentials**
3. Fill in:
   - **Kind**: SSH Username with private key
   - **ID**: `stackwatch-deploy`
   - **Username**: `deploy`
   - **Private Key**: Enter directly (paste Jenkins private key)

### 3.5 Create Jenkins Pipeline

1. Go to: **Jenkins > New Item**
2. Enter name: `stackwatch`
3. Select: **Pipeline**
4. Configure:
   - **Build Triggers**: Poll SCM or Webhook
   - **Pipeline Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: `ssh://git@gitlab.assistanz24x7.com:223/stackwatch/stackwatch.git`
   - **Script Path**: `Jenkinsfile`

---

## Step 4: Running Builds

### 4.1 Build Options

When you click "Build with Parameters", you'll see:

| Parameter | Options | Description |
|-----------|---------|-------------|
| RELEASE_TYPE | `beta`, `latest` | Where to deploy |
| VERSION_TAG | (optional) | Custom version name |

### 4.2 Workflow

```
1. Developer pushes code to GitLab
           ▼
2. Run Jenkins build with RELEASE_TYPE = "beta"
           ▼
3. Test the beta build manually
           ▼
4. If tests pass: Run "promote-beta-to-latest.sh" on artifact server
   OR run Jenkins build with RELEASE_TYPE = "latest"
           ▼
5. Previous "latest" automatically moves to "archive"
```

### 4.3 Beta Build (New/Untested)

```
Jenkins > stackwatch > Build with Parameters
  RELEASE_TYPE: beta
  VERSION_TAG: (leave empty)
```

Result:
```
https://artifact.stackbill.com/stackwatch/build/2025/01/beta/stackwatch-beta.tar.gz
```

### 4.4 Latest Build (Tested/Stable)

```
Jenkins > stackwatch > Build with Parameters
  RELEASE_TYPE: latest
  VERSION_TAG: (leave empty)
```

Result:
```
https://artifact.stackbill.com/stackwatch/build/2025/01/latest/stackwatch-latest.tar.gz
```

---

## Step 5: Promoting Beta to Latest

After testing a beta build, promote it to latest:

### Option A: Use Promotion Script (Recommended)

```bash
# SSH to artifact server
ssh deploy@artifact.stackbill.com

# Run promotion script
cd /var/www/artifacts
./promote-beta-to-latest.sh 2025 01   # Year Month
```

### Option B: Re-run Jenkins with "latest"

Just run Jenkins again with `RELEASE_TYPE = latest`

---

## Step 6: Client Downloads

### Download URLs

| Type | URL |
|------|-----|
| Beta | `https://artifact.stackbill.com/stackwatch/build/YYYY/MM/beta/stackwatch-beta.tar.gz` |
| Latest | `https://artifact.stackbill.com/stackwatch/build/YYYY/MM/latest/stackwatch-latest.tar.gz` |
| Browse | `https://artifact.stackbill.com/stackwatch/build/` |

### Download Commands

```bash
# Download latest stable
curl -LO https://artifact.stackbill.com/stackwatch/build/2025/01/latest/stackwatch-latest.tar.gz

# Download beta for testing
curl -LO https://artifact.stackbill.com/stackwatch/build/2025/01/beta/stackwatch-beta.tar.gz

# Check version
curl https://artifact.stackbill.com/stackwatch/build/2025/01/latest/version.txt
```

---

## File Structure Summary

### In Your Repository

```
stackwatch/
├── Jenkinsfile                    # Pipeline config (already created)
├── package.json                   # Node.js config
├── scripts/
│   └── create-prebuilt-package.sh # Build script
├── artifact-server/               # Server config (copy to server)
│   ├── nginx-artifact.conf        # Nginx config
│   ├── setup-artifact-server.sh   # Server setup
│   └── promote-beta-to-latest.sh  # Promotion script
└── (source code...)
```

### On Artifact Server

```
/var/www/artifacts/
├── index.html
├── promote-to-latest.sh
└── stackwatch/
    └── build/
        └── YYYY/
            └── MM/
                ├── beta/
                │   ├── stackwatch-beta.tar.gz -> stackwatch-X.X.X.tar.gz
                │   ├── stackwatch-X.X.X.tar.gz
                │   ├── version.txt
                │   └── metadata.json
                ├── latest/
                │   ├── stackwatch-latest.tar.gz -> stackwatch-X.X.X.tar.gz
                │   ├── stackwatch-X.X.X.tar.gz
                │   ├── version.txt
                │   └── metadata.json
                └── archive/
                    ├── stackwatch-old-version-1.tar.gz
                    └── stackwatch-old-version-2.tar.gz
```

---

## Troubleshooting

### Jenkins can't SSH to artifact server

```bash
# Test connection from Jenkins
sudo su - jenkins
ssh deploy@artifact.stackbill.com "echo 'Connection OK'"
```

### Build fails - npm not found

```bash
# On Jenkins server
sudo apt-get install -y nodejs npm
```

### Artifact server returns 403

```bash
# Check permissions
sudo chown -R deploy:deploy /var/www/artifacts
sudo chmod -R 755 /var/www/artifacts
```

### SSL certificate issues

```bash
# Renew certificate
sudo certbot renew --dry-run
```

---

## Quick Reference

| Task | Command/Action |
|------|----------------|
| New beta build | Jenkins: RELEASE_TYPE=beta |
| New stable build | Jenkins: RELEASE_TYPE=latest |
| Promote beta to latest | `./promote-beta-to-latest.sh YYYY MM` |
| Check latest version | `curl .../latest/version.txt` |
| Browse artifacts | `https://artifact.stackbill.com/stackwatch/build/` |

---

*Created: 2025-12-30*
