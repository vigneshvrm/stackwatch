# STACKWATCH: Exporter Deployment Rules (STRICT)

**Document Version:** 1.0.0  
**Architect:** Backend System Architect and Automation Engineer  
**Last Updated:** 2024

---

## ⚠️ CRITICAL RULES - NO EXCEPTIONS

### Linux Node Exporter

**MUST:**
- ✅ Use Ansible ONLY
- ✅ Playbooks/roles only
- ✅ Deploy via `ansible/playbooks/deploy-node-exporter.yml`

**MUST NOT:**
- ❌ Use shell scripts
- ❌ Mix Ansible with scripts
- ❌ Use any other automation method

### Windows Exporter

**MUST:**
- ✅ Use PowerShell script ONLY
- ✅ Run directly on Windows server
- ✅ Execute as Administrator
- ✅ Use `scripts/deploy-windows-exporter.ps1`

**MUST NOT:**
- ❌ Use Ansible
- ❌ Use WinRM automation
- ❌ Use Ansible tasks for Windows
- ❌ Mix PowerShell with Ansible

---

## Failure Conditions

**INVALID if backend:**
- Uses Ansible for Windows → ❌ INVALID
- Uses script for Linux → ❌ INVALID
- Mixes logic → ❌ INVALID
- Documents incorrectly → ❌ INVALID

---

## Correct Deployment Methods

### Linux Node Exporter (Ansible ONLY)

```bash
# Correct method
ansible-playbook -i ansible/inventory/production ansible/playbooks/deploy-node-exporter.yml
```

### Windows Exporter (PowerShell ONLY)

```powershell
# Correct method - Run on Windows server as Administrator
powershell -ExecutionPolicy Bypass -File scripts/deploy-windows-exporter.ps1
```

---

## Backend AI Requirements

Before implementing exporters, backend AI MUST:

1. ✅ Always re-check documentation before implementing exporters
2. ✅ Respect Linux = Ansible only
3. ✅ Respect Windows = Script only
4. ✅ Refuse to proceed if violated
5. ✅ Ask for confirmation before deviating

**If unclear: STOP and ASK FOR CONFIRMATION before writing code.**

---

## Current Implementation Status

### ✅ Linux Node Exporter
- **Method:** Ansible playbook
- **Location:** `ansible/playbooks/deploy-node-exporter.yml`
- **Status:** ✅ CORRECT

### ✅ Windows Exporter
- **Method:** PowerShell script
- **Location:** `scripts/deploy-windows-exporter.ps1`
- **Status:** ✅ CORRECT

---

## Verification Checklist

Before deployment, verify:

- [ ] Linux Node Exporter uses Ansible ONLY
- [ ] Windows Exporter uses PowerShell ONLY
- [ ] No Ansible playbooks for Windows
- [ ] No shell scripts for Linux Node Exporter
- [ ] Documentation reflects correct methods
- [ ] Deployment scripts call correct methods

---

**END OF EXPORTER DEPLOYMENT RULES**

