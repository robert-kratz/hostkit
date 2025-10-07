# Multi-Key SSH Management - Workflow Examples

## Complete Workflow Example

```
┌─────────────────────────────────────────────────────────────────────┐
│                    HostKit Multi-Key SSH Workflow                    │
└─────────────────────────────────────────────────────────────────────┘

Step 1: Website Registration (creates default keys)
──────────────────────────────────────────────────
$ hostkit register
  ├── Creates: /opt/domains/example.com/.ssh/id_rsa
  ├── Creates: /opt/domains/example.com/.ssh/id_ed25519
  └── Adds to: /home/deploy-example-com/.ssh/authorized_keys

Step 2: Create Additional Keys for Different Purposes
──────────────────────────────────────────────────────
$ hostkit add-key example.com github-actions
  ├── Creates: key-github-actions.rsa (4096-bit)
  ├── Creates: key-github-actions.ed25519
  └── Auto-adds public keys to authorized_keys

$ hostkit add-key example.com gitlab-ci
  ├── Creates: key-gitlab-ci.rsa (4096-bit)
  ├── Creates: key-gitlab-ci.ed25519
  └── Auto-adds public keys to authorized_keys

$ hostkit add-key example.com jenkins
  ├── Creates: key-jenkins.rsa (4096-bit)
  ├── Creates: key-jenkins.ed25519
  └── Auto-adds public keys to authorized_keys

Step 3: View All Keys
──────────────────────
$ hostkit list-keys example.com

  ╔══════════════════════════════════════════════════════════════════╗
  ║ KEY NAME         ║ RSA       ║ ED25519   ║ CREATED            ║
  ╠══════════════════════════════════════════════════════════════════╣
  ║ github-actions   ║ ✓         ║ ✓         ║ 2025-01-15         ║
  ║ gitlab-ci        ║ ✓         ║ ✓         ║ 2025-01-20         ║
  ║ jenkins          ║ ✓         ║ ✓         ║ 2025-01-22         ║
  ╚══════════════════════════════════════════════════════════════════╝

Step 4: Export Keys to CI/CD Systems
─────────────────────────────────────
$ hostkit show-key example.com github-actions

  RSA Private Key:
  cat << 'EOF' > ~/.ssh/hostkit-example-com-github-actions-rsa
  -----BEGIN OPENSSH PRIVATE KEY-----
  ...
  -----END OPENSSH PRIVATE KEY-----
  EOF
  chmod 600 ~/.ssh/hostkit-example-com-github-actions-rsa

  → Copy this to GitHub Secrets as DEPLOY_SSH_KEY

Step 5: Use in GitHub Actions Workflow
───────────────────────────────────────
# .github/workflows/deploy.yml
- name: Deploy to VPS
  run: |
    echo "${{ secrets.DEPLOY_SSH_KEY }}" > private_key
    chmod 600 private_key
    scp -i private_key image.tar deploy-example-com@vps:/opt/domains/example.com/deploy/

Step 6: Key Rotation (after 90 days)
─────────────────────────────────────
$ hostkit remove-key example.com github-actions-old
  ├── Removes from authorized_keys
  └── Deletes key files

$ hostkit add-key example.com github-actions-new
  ├── Creates new key pair
  └── Adds to authorized_keys

$ hostkit show-key example.com github-actions-new
  → Update GitHub Secret with new key

Step 7: View Complete Website Info
───────────────────────────────────
$ hostkit info example.com

  SSH KEYS (Default)
    RSA Key:             ✓ Present (4096 bit)
    Ed25519 Key:         ✓ Present

  SSH KEYS (Additional)
    Total Keys:          3 key(s)
    • github-actions:    RSA: ✓  Ed25519: ✓
    • gitlab-ci:         RSA: ✓  Ed25519: ✓
    • jenkins:           RSA: ✓  Ed25519: ✓
```

## Use Case: Multiple CI/CD Pipelines

```
┌──────────────────────────────────────────────────────────────┐
│            Different Keys for Different Pipelines             │
└──────────────────────────────────────────────────────────────┘

Production Pipeline (GitHub Actions)
────────────────────────────────────
Key: github-actions-prod
Purpose: Deploy to production from main branch
Workflow: .github/workflows/deploy-prod.yml

Staging Pipeline (GitHub Actions)
──────────────────────────────────
Key: github-actions-staging
Purpose: Deploy to staging from develop branch
Workflow: .github/workflows/deploy-staging.yml

GitLab Mirror Pipeline (GitLab CI)
───────────────────────────────────
Key: gitlab-ci-mirror
Purpose: Backup deployments from GitLab
Workflow: .gitlab-ci.yml

Jenkins Build Pipeline
───────────────────────
Key: jenkins-build
Purpose: Continuous integration builds
Config: Jenkinsfile

Each key can be independently:
  ✓ Created
  ✓ Rotated
  ✓ Revoked
  ✓ Monitored
```

## Use Case: Team Access Management

```
┌──────────────────────────────────────────────────────────────┐
│              Individual Keys for Team Members                 │
└──────────────────────────────────────────────────────────────┘

Team Lead
─────────
Key: dev-alice-lead
Access: Full deployment rights
Created: 2025-01-10

Senior Developer
────────────────
Key: dev-bob-senior
Access: Production deployment
Created: 2025-01-15

Junior Developer
────────────────
Key: dev-charlie-junior
Access: Staging deployment only
Created: 2025-01-20

DevOps Engineer
───────────────
Key: ops-david
Access: Emergency deployment
Created: 2025-01-25

When someone leaves the team:
$ hostkit remove-key example.com dev-charlie-junior
  → Access immediately revoked
  → Other team members unaffected
```

## Use Case: Key Rotation Schedule

```
┌──────────────────────────────────────────────────────────────┐
│              Quarterly Key Rotation Schedule                  │
└──────────────────────────────────────────────────────────────┘

Q1 2025 (Jan-Mar)
─────────────────
Keys Created:
  - github-actions-q1
  - gitlab-ci-q1
  - jenkins-q1

Q2 2025 (Apr-Jun)
─────────────────
Actions:
  1. Create: github-actions-q2, gitlab-ci-q2, jenkins-q2
  2. Update CI/CD secrets
  3. Remove: github-actions-q1, gitlab-ci-q1, jenkins-q1

Q3 2025 (Jul-Sep)
─────────────────
Actions:
  1. Create: github-actions-q3, gitlab-ci-q3, jenkins-q3
  2. Update CI/CD secrets
  3. Remove: github-actions-q2, gitlab-ci-q2, jenkins-q2

Benefits:
  ✓ Regular key rotation improves security
  ✓ Predictable maintenance schedule
  ✓ Easy to track key age
  ✓ Clear naming convention
```

## Use Case: Environment-Specific Keys

```
┌──────────────────────────────────────────────────────────────┐
│         Different Keys for Different Environments             │
└──────────────────────────────────────────────────────────────┘

Development Environment
───────────────────────
Website: dev.example.com
Keys:
  - deploy-dev-ci
  - deploy-dev-manual

Staging Environment
───────────────────
Website: staging.example.com
Keys:
  - deploy-staging-ci
  - deploy-staging-qa

Production Environment
──────────────────────
Website: example.com
Keys:
  - deploy-prod-ci (GitHub Actions)
  - deploy-prod-emergency (Manual deployments)
  - deploy-prod-backup (Failover system)

Setup:
$ hostkit add-key dev.example.com deploy-dev-ci
$ hostkit add-key staging.example.com deploy-staging-ci
$ hostkit add-key example.com deploy-prod-ci
$ hostkit add-key example.com deploy-prod-emergency
```

## File Structure Overview

```
/opt/domains/example.com/
├── .ssh/
│   ├── id_rsa                         # Default RSA key
│   ├── id_rsa.pub
│   ├── id_ed25519                     # Default Ed25519 key
│   ├── id_ed25519.pub
│   └── keys/                          # Additional keys directory
│       ├── key-github-actions.rsa
│       ├── key-github-actions.rsa.pub
│       ├── key-github-actions.ed25519
│       ├── key-github-actions.ed25519.pub
│       ├── key-gitlab-ci.rsa
│       ├── key-gitlab-ci.rsa.pub
│       ├── key-gitlab-ci.ed25519
│       ├── key-gitlab-ci.ed25519.pub
│       ├── key-jenkins.rsa
│       ├── key-jenkins.rsa.pub
│       ├── key-jenkins.ed25519
│       └── key-jenkins.ed25519.pub

/home/deploy-example-com/
└── .ssh/
    └── authorized_keys                # All public keys (auto-synced)
        ├── [default id_rsa.pub]
        ├── [default id_ed25519.pub]
        ├── [key-github-actions.rsa.pub]
        ├── [key-github-actions.ed25519.pub]
        ├── [key-gitlab-ci.rsa.pub]
        ├── [key-gitlab-ci.ed25519.pub]
        ├── [key-jenkins.rsa.pub]
        └── [key-jenkins.ed25519.pub]
```

## Tab Completion Examples

```bash
# Command completion
$ hostkit <TAB><TAB>
list-keys  add-key  show-key  remove-key  [... other commands]

# Domain/ID completion
$ hostkit list-keys <TAB><TAB>
example.com  example2.com  0  1  2

# Key name completion (for show-key and remove-key)
$ hostkit show-key example.com <TAB><TAB>
github-actions  gitlab-ci  jenkins

$ hostkit remove-key 0 <TAB><TAB>
github-actions  gitlab-ci  jenkins
```

## Integration with Existing Commands

```
┌──────────────────────────────────────────────────────────────┐
│        Multi-Key Management fits seamlessly into HostKit      │
└──────────────────────────────────────────────────────────────┘

hostkit list
────────────────
Shows all websites with IDs
  → Use IDs for quick key management

hostkit info <domain|id>
─────────────────────────────
Shows comprehensive info including:
  - Default SSH keys status
  - Additional keys count and list
  - Quick action commands

hostkit list-users
──────────────────────
Shows all deployment users
  → Each user can have multiple keys

hostkit show-keys <domain|id>
──────────────────────────────────
Shows default keys (original command)
  → Use for backward compatibility

hostkit list-keys <domain|id>
──────────────────────────────────
Shows all additional keys (new command)
  → Use for multi-key overview

hostkit uninstall
─────────────────────
Cleanup includes all keys
  → Additional keys are properly removed
```
