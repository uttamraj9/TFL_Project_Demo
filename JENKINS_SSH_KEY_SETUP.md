# Jenkins SSH Key Configuration Guide

## 🔑 Where to Find/Add SSH Private Key in Jenkins

### Option A: Add SSH Private Key Through Jenkins UI

#### Step 1: Navigate to Credentials
```
http://51.24.13.205:8081/
→ Manage Jenkins
→ Manage Credentials
→ Click "(global)" under "Stores scoped to Jenkins"
→ Click "Add Credentials"
```

#### Step 2: Configure SSH Credential

**Select:**
- **Kind:** `SSH Username with private key`
- **ID:** `cloudera-cluster-ssh` (or any unique ID)
- **Description:** `Cloudera Cluster SSH Access`
- **Username:** Your Cloudera username (e.g., `hduser`, `admin`, etc.)

**Private Key Options:**

**Option 1 - Enter Directly (Recommended):**
```
Select: ⚫ Enter directly
Click [Add] button

Paste your private key in this format:
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA...
(your key content here)
...
-----END RSA PRIVATE KEY-----

Passphrase: (enter if your key has a passphrase)
```

**Option 2 - From Jenkins Controller:**
```
Select: ⚫ From the Jenkins controller ~/.ssh
(This uses Jenkins server's SSH key at /var/lib/jenkins/.ssh/id_rsa)
```

**Option 3 - From File:**
```
Select: ⚫ From a file on Jenkins controller
File: /path/to/your/key.pem
```

---

## 📂 Where Keys are Located

### On Your Local Machine (Mac)
```bash
# List your SSH keys
ls -la ~/.ssh/

# Common key filenames:
~/.ssh/id_rsa        # Default RSA private key
~/.ssh/id_ed25519    # ED25519 private key
~/.ssh/cloudera.pem  # Custom named key
~/.ssh/cloudera_key  # Custom named key
```

### View Your Public Key
```bash
# View public key (to verify it matches Cloudera cluster)
cat ~/.ssh/id_rsa.pub

# Or
cat ~/.ssh/cloudera.pem.pub
```

### On Jenkins Server (need SSH access to Jenkins machine)
```bash
# SSH into Jenkins server
ssh ubuntu@51.24.13.205

# Jenkins home directory
cd /var/lib/jenkins

# Jenkins SSH directory
ls -la /var/lib/jenkins/.ssh/
```

---

## 🔧 How to Copy Your SSH Key to Jenkins

### Method 1: Copy-Paste Through Browser (Easiest)

1. **On your Mac, copy your private key:**
   ```bash
   # Copy private key to clipboard
   cat ~/.ssh/id_rsa | pbcopy
   
   # Or if you have a specific key for Cloudera
   cat ~/.ssh/cloudera.pem | pbcopy
   ```

2. **In Jenkins:**
   - Go to: Add Credentials → SSH Username with private key
   - Select "Enter directly"
   - Click [Add]
   - **Paste** from clipboard (Cmd+V)
   - Click OK

### Method 2: Upload Key File to Jenkins Server

If you need to place the key on Jenkins server:

```bash
# From your Mac, copy key to Jenkins server
scp ~/.ssh/id_rsa jenkins@51.24.13.205:/var/lib/jenkins/.ssh/cloudera_key

# SSH into Jenkins server
ssh jenkins@51.24.13.205

# Set proper permissions
chmod 600 /var/lib/jenkins/.ssh/cloudera_key
chown jenkins:jenkins /var/lib/jenkins/.ssh/cloudera_key
```

Then in Jenkins:
- Add Credentials → From a file on Jenkins controller
- File: `/var/lib/jenkins/.ssh/cloudera_key`

---

## ✅ Verify SSH Key Setup

### Test 1: Through Jenkins Credentials

After adding the credential:
1. Go to: `Manage Jenkins → Configure System → SSH remote hosts`
2. Add your Cloudera server:
   ```
   Hostname: <cloudera_hostname>
   Port: 22
   Credentials: Select "cloudera-cluster-ssh"
   ```
3. Click **Check connection**
   - ✓ Should show: "Successfull connection"
   - ✗ If failed: Check key, username, hostname

### Test 2: Create Test Jenkins Job

**Create new Freestyle project: `test-ssh-connection`**

Build Step → Execute shell script on remote host using ssh:
```bash
#!/bin/bash
echo "=== Testing SSH Connection ==="
whoami
hostname
date
echo "✓ SSH connection successful!"
```

Save and **Build Now**

Check Console Output:
```
=== Testing SSH Connection ===
hduser
cloudera-edge-node
Mon Jun  2 10:30:00 UTC 2026
✓ SSH connection successful!
```

---

## 🐛 Troubleshooting

### Issue: "test_key.pm not found"

If you're looking for a specific file named `test_key.pm`:

**This is likely:**
1. A **Perl module** (.pm extension = Perl Module)
2. Or a **typo** - did you mean `test_key.pem`? (.pem = Privacy Enhanced Mail format for keys)

**Check if file exists:**
```bash
# On Jenkins server
find /var/lib/jenkins -name "test_key.pm" 2>/dev/null
find /var/lib/jenkins -name "test_key.pem" 2>/dev/null
find /var/lib/jenkins -name "*test_key*" 2>/dev/null

# On your Mac
find ~ -name "test_key.pm" 2>/dev/null
find ~ -name "test_key.pem" 2>/dev/null
```

### Issue: "Permission denied (publickey)"

**Cause:** SSH key not configured or wrong key used

**Solutions:**

1. **Verify the key is correct:**
   ```bash
   # On your Mac, test SSH to Cloudera directly
   ssh -i ~/.ssh/id_rsa <user>@<cloudera_host>
   
   # If this works, the key is correct
   ```

2. **Check public key on Cloudera:**
   ```bash
   # SSH into Cloudera cluster
   ssh <user>@<cloudera_host>
   
   # Check authorized keys
   cat ~/.ssh/authorized_keys
   
   # Your public key should be listed here
   ```

3. **Add your public key to Cloudera:**
   ```bash
   # On your Mac
   cat ~/.ssh/id_rsa.pub | ssh <user>@<cloudera_host> 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'
   
   # Set proper permissions on Cloudera
   ssh <user>@<cloudera_host> 'chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys'
   ```

### Issue: "Host key verification failed"

**Cause:** Jenkins doesn't trust Cloudera server's host key

**Solution 1 - Add to known_hosts (on Jenkins server):**
```bash
# SSH into Jenkins server
ssh jenkins@51.24.13.205

# As jenkins user, SSH to Cloudera once
sudo -u jenkins ssh <user>@<cloudera_host>
# Type "yes" to accept host key
# Then exit

# This adds Cloudera to Jenkins' known_hosts
```

**Solution 2 - In Jenkins job:**
```bash
# Add to beginning of build script
export JENKINS_HOME=/var/lib/jenkins
mkdir -p $JENKINS_HOME/.ssh
ssh-keyscan -H <cloudera_host> >> $JENKINS_HOME/.ssh/known_hosts
```

---

## 🔐 Security Best Practices

### 1. Use Dedicated Key for Jenkins
```bash
# On your Mac, create dedicated key for Jenkins
ssh-keygen -t rsa -b 4096 -f ~/.ssh/jenkins_cloudera -C "jenkins@tfl-pipeline"

# Copy public key to Cloudera
ssh-copy-id -i ~/.ssh/jenkins_cloudera.pub <user>@<cloudera_host>

# Copy private key to Jenkins (through UI)
cat ~/.ssh/jenkins_cloudera
```

### 2. Protect Private Key
- ✅ Private key: 600 permissions (readable only by owner)
- ✅ .ssh directory: 700 permissions
- ✅ Never commit private keys to Git
- ✅ Use Jenkins credentials (encrypted storage)

### 3. Use Key Passphrase
```bash
# Create key with passphrase
ssh-keygen -t rsa -b 4096 -f ~/.ssh/jenkins_key

# Enter passphrase when prompted
# Store passphrase in Jenkins credential
```

---

## 📋 Quick Checklist

Before your Jenkins job can SSH to Cloudera:

- [ ] SSH private key exists (on your Mac or Jenkins server)
- [ ] Corresponding public key added to Cloudera `~/.ssh/authorized_keys`
- [ ] Private key added to Jenkins credentials (Manage Credentials)
- [ ] SSH remote host configured in Jenkins (Configure System)
- [ ] Connection test passed (Check connection)
- [ ] Jenkins job build step uses correct credentials
- [ ] Test job executed successfully

---

## 📞 Need Help?

### If you can't find your key file:

**Check common locations:**
```bash
# On Mac
ls -la ~/.ssh/
ls -la ~/Downloads/
ls -la ~/Documents/

# Search for all .pem and .key files
find ~ -name "*.pem" 2>/dev/null
find ~ -name "*.key" 2>/dev/null
find ~ -name "*cloudera*" 2>/dev/null
```

### If you need to generate a new key:

```bash
# Generate new SSH key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/tfl_jenkins

# Copy to Cloudera
ssh-copy-id -i ~/.ssh/tfl_jenkins.pub <user>@<cloudera_host>

# Use the private key in Jenkins
cat ~/.ssh/tfl_jenkins
# Copy this output to Jenkins credentials
```

---

## 🎯 Summary

**Where SSH Keys are in Jenkins:**
1. **UI:** Manage Jenkins → Manage Credentials → (global) → [Your credential]
2. **Filesystem:** `/var/lib/jenkins/.ssh/` (if stored as file)
3. **Encrypted DB:** `/var/lib/jenkins/credentials.xml` (internal storage)

**For TfL Pipeline:**
- Use the SSH key that works with your Cloudera cluster
- Add it through Jenkins UI (Manage Credentials)
- Reference it in SSH remote hosts configuration
- Use in Jenkins build steps with "Execute shell script on remote host"

---

*Last Updated: June 2, 2026*
