# 🚀 START HERE - Deploy Your Dashboard in 5 Minutes

## What This Is

A **production-grade Medicaid drug data dashboard** that you can deploy to Google Cloud in minutes - **without installing Docker!**

---

## ⚡ Quick Deploy (3 Commands)

```powershell
# 1. Go to dashboard folder
cd dashboard

# 2. Verify you're ready (optional but recommended)
.\verify-setup.ps1

# 3. Deploy everything!
.\deploy-gke.ps1
```

**That's it!** ☕ Grab coffee while it deploys (~10-15 minutes first time).

When done, you'll get a URL like:
```
Dashboard URL: http://35.123.45.67:8501
```

Open it in your browser and you're done! 🎉

---

## ✅ Prerequisites (Quick Check)

### Required (5 minutes to install if needed)

1. **Google Cloud SDK (gcloud)**
   - Check: `gcloud --version`
   - Install: https://cloud.google.com/sdk/docs/install
   - Login: `gcloud auth login`

2. **kubectl** (Kubernetes CLI)
   - Check: `kubectl version --client`
   - Install: `gcloud components install kubectl`

3. **GCP Project Access**
   - Project: `gcp-project-deliverable`
   - Check: `gcloud config get-value project`
   - Set: `gcloud config set project gcp-project-deliverable`

### NOT Required ❌

- ❌ Docker (we use Cloud Build!)
- ❌ Python locally (runs in container)
- ❌ Kubernetes cluster (script creates it)

---

## 📖 Documentation (If You Need Help)

### Start Here
- **[QUICKSTART.md](QUICKSTART.md)** - Expanded 5-minute guide

### Detailed Guides
- **[README.md](README.md)** - Complete dashboard documentation
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Step-by-step deployment
- **[TOOLKIT.md](TOOLKIT.md)** - All scripts explained

### Project Overview
- **[../README.md](../README.md)** - Full pipeline architecture
- **[../PROJECT_SUMMARY.md](../PROJECT_SUMMARY.md)** - Complete project summary

---

## 🛠️ Daily Operations (After Deployed)

```powershell
cd dashboard

# Check if everything is running
.\manage-dashboard.ps1 -Action status

# View real-time logs
.\manage-dashboard.ps1 -Action logs

# Get the dashboard URL
.\manage-dashboard.ps1 -Action url

# Restart after making changes
.\manage-dashboard.ps1 -Action restart

# Scale up for more traffic
.\manage-dashboard.ps1 -Action scale -Replicas 3

# Scale down to save costs
.\manage-dashboard.ps1 -Action scale -Replicas 1
```

---

## 🔧 Update After Code Changes

```powershell
# 1. Make changes to app.py

# 2. Rebuild image (uses Cloud Build)
.\build-image.ps1

# 3. Restart deployment
.\manage-dashboard.ps1 -Action restart

# 4. Check logs
.\manage-dashboard.ps1 -Action logs
```

---

## 💰 Cost

- **~$190-200/month** for always-on dashboard
- **~$0/month** when scaled to zero: `.\manage-dashboard.ps1 -Action scale -Replicas 0`

---

## 🚨 Troubleshooting (If Something Goes Wrong)

### "gcloud: command not found"
```powershell
# Install Google Cloud SDK
# https://cloud.google.com/sdk/docs/install
```

### "Not authenticated"
```powershell
gcloud auth login
gcloud auth application-default login
```

### "kubectl: command not found"
```powershell
gcloud components install kubectl
```

### "Permission denied"
```powershell
# Make sure you have project access
gcloud projects get-iam-policy gcp-project-deliverable
```

### Dashboard not loading
```powershell
# Check status
.\manage-dashboard.ps1 -Action status

# View logs for errors
.\manage-dashboard.ps1 -Action logs

# Try restarting
.\manage-dashboard.ps1 -Action restart
```

### "External IP pending"
```powershell
# Wait up to 5 minutes, then check again
.\manage-dashboard.ps1 -Action url
```

---

## 🎯 What You Get

After running `.\deploy-gke.ps1`, you'll have:

- ✅ Interactive dashboard with 4 chart types
- ✅ Real-time BigQuery data
- ✅ Auto-scaling (1-4 replicas)
- ✅ Load balancer with external IP
- ✅ Health checks
- ✅ Secure authentication (Workload Identity)
- ✅ Production-ready deployment

---

## 📊 Dashboard Features

Once deployed, your dashboard will show:

1. **Bar Chart** - Average price by drug
2. **Pie Chart** - Top 10 drugs by price share
3. **Line Chart** - Price trends over time
4. **Scatter Plot** - Price vs. dosage correlation

**Plus:**
- Filter by drug name
- Filter by date range
- Filter by dosage form
- Real-time data refresh

---

## 🎓 Next Steps After Deployment

### Immediate
1. ✅ **Test the dashboard** - Click around, try filters
2. ✅ **Share the URL** - Show to team/stakeholders
3. ✅ **Monitor costs** - Check GCP billing console

### Optional Enhancements
1. **Add HTTPS** - See [DEPLOYMENT.md](DEPLOYMENT.md)
2. **Add authentication** - Use Cloud IAP
3. **Add more charts** - Edit `app.py`
4. **Set up monitoring** - Enable Cloud Monitoring
5. **Add CI/CD** - Automate with Cloud Build triggers

---

## 🤔 FAQ

### Do I need Docker?
**No!** We use Cloud Build to build images remotely on GCP.

### Will this work on Windows?
**Yes!** All scripts are PowerShell (Windows-native).

### How long does deployment take?
**10-15 minutes** first time, **5 minutes** for updates.

### Can I test locally first?
**Yes!** See [README.md](README.md) for local development instructions.

### What if I want to delete everything?
```powershell
# Delete deployment only (keeps cluster)
.\manage-dashboard.ps1 -Action delete

# Delete entire cluster
gcloud container clusters delete medicaid-dashboard-cluster --region=us-central1
```

### How do I save costs?
```powershell
# Scale to zero (stops pods, no compute cost)
.\manage-dashboard.ps1 -Action scale -Replicas 0

# Scale back up when needed
.\manage-dashboard.ps1 -Action scale -Replicas 2
```

---

## 🎉 Ready? Let's Deploy!

```powershell
cd dashboard
.\deploy-gke.ps1
```

**That's all you need!** The script will:
1. ✅ Enable required APIs
2. ✅ Build Docker image (remotely on GCP)
3. ✅ Create GKE cluster
4. ✅ Set up secure authentication
5. ✅ Deploy dashboard
6. ✅ Create load balancer
7. ✅ Give you the URL

---

## 📞 Need Help?

### Quick Answers
- Run `.\verify-setup.ps1` to check prerequisites
- Run `.\manage-dashboard.ps1 -Action help` for options

### Detailed Guides
- **[QUICKSTART.md](QUICKSTART.md)** - 5-minute guide
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Troubleshooting
- **[TOOLKIT.md](TOOLKIT.md)** - Script reference

### GCP Console
- Logs: https://console.cloud.google.com/logs
- GKE: https://console.cloud.google.com/kubernetes
- BigQuery: https://console.cloud.google.com/bigquery

---

## 💡 Pro Tips

1. **Always verify first:**
   ```powershell
   .\verify-setup.ps1
   ```

2. **Check logs after deployment:**
   ```powershell
   .\manage-dashboard.ps1 -Action logs
   ```

3. **Bookmark the dashboard URL:**
   ```powershell
   .\manage-dashboard.ps1 -Action url
   ```

4. **Scale down when not in use:**
   ```powershell
   .\manage-dashboard.ps1 -Action scale -Replicas 0
   ```

---

## ✨ You're All Set!

**3 commands to deploy:**
```powershell
cd dashboard
.\verify-setup.ps1
.\deploy-gke.ps1
```

**1 command to manage:**
```powershell
.\manage-dashboard.ps1 -Action <status|logs|restart|scale|url>
```

**Questions?** Check [QUICKSTART.md](QUICKSTART.md) or [DEPLOYMENT.md](DEPLOYMENT.md)

---

**Now go deploy! 🚀**

```powershell
cd dashboard
.\deploy-gke.ps1
```
