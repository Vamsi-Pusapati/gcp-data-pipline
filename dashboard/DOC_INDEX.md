# 📚 Documentation Index

Complete guide to all project documentation and scripts.

---

## 🚀 Quick Start (Choose One)

| Document | Use Case | Time |
|----------|----------|------|
| **[START_HERE.md](START_HERE.md)** | First time deploying | 5 min |
| **[QUICKSTART.md](QUICKSTART.md)** | Fast deployment | 5 min |
| **[README.md](README.md)** | Complete reference | 30 min |

**→ If you've never deployed before, start with [START_HERE.md](START_HERE.md)**

---

## 📖 Complete Documentation

### For Deployment

| Document | What It Covers |
|----------|----------------|
| **[START_HERE.md](START_HERE.md)** | Absolute beginner guide (3 commands) |
| **[QUICKSTART.md](QUICKSTART.md)** | 5-minute deployment guide |
| **[DEPLOYMENT.md](DEPLOYMENT.md)** | Detailed step-by-step instructions |
| **[README.md](README.md)** | Complete dashboard documentation |
| **[TOOLKIT.md](TOOLKIT.md)** | All scripts and workflows |

### For Management

| Document | What It Covers |
|----------|----------------|
| **[TOOLKIT.md](TOOLKIT.md)** | Daily operations guide |
| **[DEPLOYMENT.md](DEPLOYMENT.md)** | Update procedures |
| **[README.md](README.md)** | Monitoring and troubleshooting |

### For Development

| Document | What It Covers |
|----------|----------------|
| **[README.md](README.md)** | Local development setup |
| **[DEPLOYMENT.md](DEPLOYMENT.md)** | Development workflow |
| **app.py** | Dashboard source code |

---

## 🛠️ Scripts Reference

### Main Scripts (PowerShell)

| Script | Purpose | When to Use |
|--------|---------|-------------|
| **verify-setup.ps1** | Pre-deployment checks | Before first deploy |
| **deploy-gke.ps1** | Full deployment | First deploy or redeploy |
| **build-image.ps1** | Build Docker image | After code changes |
| **manage-dashboard.ps1** | Daily operations | Status, logs, restart, scale |

### Script Details

#### `verify-setup.ps1`
```powershell
.\verify-setup.ps1
```
**Checks:**
- gcloud installed
- kubectl installed
- GCP authentication
- Service account exists
- Required files present
- APIs enabled
- BigQuery dataset

**Documentation:** [TOOLKIT.md#verify-setup](TOOLKIT.md)

#### `deploy-gke.ps1`
```powershell
.\deploy-gke.ps1
```
**Does:**
- Builds image (Cloud Build)
- Creates GKE cluster
- Sets up Workload Identity
- Deploys application
- Creates LoadBalancer

**Documentation:** [QUICKSTART.md](QUICKSTART.md), [DEPLOYMENT.md](DEPLOYMENT.md)

#### `build-image.ps1`
```powershell
.\build-image.ps1 [-ImageTag "v1.0"]
```
**Does:**
- Builds image remotely (Cloud Build)
- Pushes to GCR
- Tags with version

**Documentation:** [TOOLKIT.md#build-image](TOOLKIT.md)

#### `manage-dashboard.ps1`
```powershell
.\manage-dashboard.ps1 -Action <action> [-Replicas N]
```
**Actions:**
- `status` - Show deployment status
- `logs` - View real-time logs
- `restart` - Restart deployment
- `scale` - Scale replicas
- `url` - Get dashboard URL
- `delete` - Delete deployment

**Documentation:** [TOOLKIT.md#manage-dashboard](TOOLKIT.md)

---

## 📁 File Structure

```
dashboard/
├── Documentation/
│   ├── START_HERE.md           ⭐ Start here if new
│   ├── QUICKSTART.md           ⚡ 5-minute guide
│   ├── README.md               📖 Complete reference
│   ├── DEPLOYMENT.md           🔧 Detailed deployment
│   ├── TOOLKIT.md              🛠️ Script reference
│   └── DOC_INDEX.md            📚 This file
│
├── Scripts/
│   ├── verify-setup.ps1        ✅ Pre-deployment checks
│   ├── deploy-gke.ps1          🚀 Full deployment
│   ├── build-image.ps1         🏗️ Build image
│   └── manage-dashboard.ps1    📊 Daily operations
│
├── Application/
│   ├── app.py                  💻 Streamlit app
│   ├── requirements.txt        📦 Dependencies
│   ├── Dockerfile              🐳 Container config
│   └── .dockerignore           🚫 Build exclusions
│
└── Kubernetes/
    ├── k8s/
    │   ├── deployment.yaml     ☸️ K8s deployment
    │   └── service.yaml        🌐 LoadBalancer
    └── ...
```

---

## 🎯 Use Cases

### "I want to deploy for the first time"
1. Read: [START_HERE.md](START_HERE.md)
2. Run: `.\verify-setup.ps1`
3. Run: `.\deploy-gke.ps1`

### "I want to understand everything"
1. Read: [README.md](README.md)
2. Read: [DEPLOYMENT.md](DEPLOYMENT.md)
3. Read: [TOOLKIT.md](TOOLKIT.md)

### "I made code changes and want to update"
1. Read: [DEPLOYMENT.md#updating](DEPLOYMENT.md)
2. Run: `.\build-image.ps1`
3. Run: `.\manage-dashboard.ps1 -Action restart`

### "I want to check if dashboard is running"
1. Run: `.\manage-dashboard.ps1 -Action status`
2. Run: `.\manage-dashboard.ps1 -Action logs`

### "I want to save costs when not using it"
1. Read: [README.md#cost-optimization](README.md)
2. Run: `.\manage-dashboard.ps1 -Action scale -Replicas 0`

### "Something is broken and I need help"
1. Read: [DEPLOYMENT.md#troubleshooting](DEPLOYMENT.md)
2. Run: `.\verify-setup.ps1`
3. Run: `.\manage-dashboard.ps1 -Action logs`

### "I want to develop locally first"
1. Read: [README.md#local-development](README.md)
2. Install: `pip install -r requirements.txt`
3. Run: `streamlit run app.py`

### "I want to add HTTPS and authentication"
1. Read: [DEPLOYMENT.md#production-enhancements](DEPLOYMENT.md)
2. Read: [README.md#security](README.md)

---

## 📊 Decision Tree

```
Are you deploying for the first time?
├─ Yes → START_HERE.md
└─ No
   ├─ Need to update code?
   │  ├─ Yes → build-image.ps1 → manage-dashboard.ps1 restart
   │  └─ No
   │     ├─ Need to check status?
   │     │  ├─ Yes → manage-dashboard.ps1 status
   │     │  └─ No
   │     │     ├─ Having issues?
   │     │     │  ├─ Yes → DEPLOYMENT.md (Troubleshooting)
   │     │     │  └─ No
   │     │     │     └─ Want to learn more?
   │     │     │        └─ Yes → README.md
   │     │     └─ Want to scale/manage?
   │     │        └─ Yes → TOOLKIT.md
   └─ Want complete reference?
      └─ Yes → README.md + DEPLOYMENT.md + TOOLKIT.md
```

---

## 🔍 Finding Information

### By Topic

| Topic | Document | Section |
|-------|----------|---------|
| **First deployment** | START_HERE.md | - |
| **Prerequisites** | QUICKSTART.md | Prerequisites |
| **Installation** | DEPLOYMENT.md | Step-by-Step |
| **Authentication** | README.md | Authentication Methods |
| **Security** | README.md | Security |
| **Costs** | README.md | Cost Estimate |
| **Troubleshooting** | DEPLOYMENT.md | Troubleshooting |
| **Updates** | DEPLOYMENT.md | Updating |
| **Scripts** | TOOLKIT.md | - |
| **Local dev** | README.md | Development |
| **Architecture** | README.md | Architecture |
| **Monitoring** | README.md | Monitoring |

### By Task

| Task | Command/Document |
|------|------------------|
| **Check prerequisites** | `.\verify-setup.ps1` |
| **Deploy** | `.\deploy-gke.ps1` |
| **Check status** | `.\manage-dashboard.ps1 -Action status` |
| **View logs** | `.\manage-dashboard.ps1 -Action logs` |
| **Get URL** | `.\manage-dashboard.ps1 -Action url` |
| **Restart** | `.\manage-dashboard.ps1 -Action restart` |
| **Scale** | `.\manage-dashboard.ps1 -Action scale -Replicas N` |
| **Update code** | `.\build-image.ps1` then restart |
| **Troubleshoot** | DEPLOYMENT.md |
| **Learn more** | README.md |

---

## 📖 Reading Order

### For Quick Deployment (15 minutes)
1. [START_HERE.md](START_HERE.md) - 5 min
2. Run `.\verify-setup.ps1` - 1 min
3. Run `.\deploy-gke.ps1` - 10-15 min
4. Done! 🎉

### For Complete Understanding (1-2 hours)
1. [START_HERE.md](START_HERE.md) - 5 min
2. [QUICKSTART.md](QUICKSTART.md) - 10 min
3. [README.md](README.md) - 30 min
4. [DEPLOYMENT.md](DEPLOYMENT.md) - 30 min
5. [TOOLKIT.md](TOOLKIT.md) - 20 min

### For Daily Operations (5 minutes)
1. [TOOLKIT.md](TOOLKIT.md) - Reference as needed
2. Use `.\manage-dashboard.ps1` for everything

---

## 🎓 Learning Path

### Beginner
1. **Week 1:** Deploy and explore
   - [START_HERE.md](START_HERE.md)
   - Deploy with `.\deploy-gke.ps1`
   - Explore dashboard UI

2. **Week 2:** Understand components
   - [README.md](README.md) - Architecture
   - [DEPLOYMENT.md](DEPLOYMENT.md) - How it works

3. **Week 3:** Make changes
   - Edit `app.py`
   - Test locally
   - Deploy changes

### Intermediate
1. **Month 1:** Master operations
   - [TOOLKIT.md](TOOLKIT.md) - All workflows
   - Practice scaling, monitoring
   - Cost optimization

2. **Month 2:** Add features
   - Add charts to `app.py`
   - Implement caching
   - Add filters

3. **Month 3:** Production hardening
   - Add HTTPS
   - Set up monitoring
   - Implement CI/CD

### Advanced
1. **Quarter 1:** Full customization
   - Custom visualizations
   - Advanced BigQuery queries
   - Performance optimization

2. **Quarter 2:** Enterprise features
   - Multi-environment setup
   - Advanced security
   - Disaster recovery

---

## 🚀 Quick Reference Card

### Deploy
```powershell
cd dashboard
.\deploy-gke.ps1
```

### Status
```powershell
.\manage-dashboard.ps1 -Action status
```

### Logs
```powershell
.\manage-dashboard.ps1 -Action logs
```

### Update
```powershell
.\build-image.ps1
.\manage-dashboard.ps1 -Action restart
```

### Scale
```powershell
.\manage-dashboard.ps1 -Action scale -Replicas 3
```

### URL
```powershell
.\manage-dashboard.ps1 -Action url
```

---

## 📞 Getting Help

### Order of Resources
1. **This index** - Find relevant doc
2. **Specific doc** - Read detailed info
3. **Run verify** - `.\verify-setup.ps1`
4. **Check logs** - `.\manage-dashboard.ps1 -Action logs`
5. **Troubleshooting** - [DEPLOYMENT.md](DEPLOYMENT.md)

### Common Issues
- **Prerequisites:** [QUICKSTART.md#prerequisites](QUICKSTART.md)
- **Authentication:** [README.md#authentication](README.md)
- **Deployment:** [DEPLOYMENT.md#troubleshooting](DEPLOYMENT.md)
- **Costs:** [README.md#cost-estimate](README.md)

---

## ✅ Checklist

### Before First Deployment
- [ ] Read [START_HERE.md](START_HERE.md)
- [ ] Install gcloud SDK
- [ ] Run `.\verify-setup.ps1`
- [ ] Confirm prerequisites met

### After Deployment
- [ ] Test dashboard URL
- [ ] Check all visualizations work
- [ ] Review [TOOLKIT.md](TOOLKIT.md) for operations
- [ ] Set up GCP billing alerts

### Before Going to Production
- [ ] Read [README.md#security](README.md)
- [ ] Review [DEPLOYMENT.md#production](DEPLOYMENT.md)
- [ ] Set up monitoring
- [ ] Configure backups
- [ ] Add HTTPS

---

## 🎯 Summary

**5 Documents, Clear Purpose:**

1. **[START_HERE.md](START_HERE.md)** → First-time deployment (5 min)
2. **[QUICKSTART.md](QUICKSTART.md)** → Fast deployment guide (5 min)
3. **[README.md](README.md)** → Complete reference (30 min)
4. **[DEPLOYMENT.md](DEPLOYMENT.md)** → Detailed guide (30 min)
5. **[TOOLKIT.md](TOOLKIT.md)** → Script reference (20 min)

**4 Scripts, Clear Purpose:**

1. **verify-setup.ps1** → Check prerequisites
2. **deploy-gke.ps1** → Deploy everything
3. **build-image.ps1** → Build after changes
4. **manage-dashboard.ps1** → Daily operations

**Start here:** [START_HERE.md](START_HERE.md)

**Questions?** Find answer in this index, then read relevant document.

---

**Ready to deploy? → [START_HERE.md](START_HERE.md)**
