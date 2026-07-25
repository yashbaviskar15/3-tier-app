# Deployment Guide — Enterprise Three-Tier Web Application

This guide covers local execution, database configuration, containerization, and production deployment for the Enterprise Three-Tier Web Application.

---

## 1. Local Quick Start

```powershell
# 1. Navigate to the application directory
cd "c:\Users\SHUBHAM\Desktop\AWS Three-Tier Web Application\src\app"

# 2. Install dependencies
npm install

# 3. Start the Operations Console
npm start
```

Open **`http://localhost:8080`** in your browser to access the dashboard.

> Without an external database host, the app automatically initializes the **In-Memory Fallback Database Emulator** — all features, metrics, topology visualizations, and CLI terminal commands remain fully functional.

---

## 2. Database Connection Configuration

### MySQL / PostgreSQL Database Setup
1. Open **`http://localhost:8080`** in your browser.
2. Under **Database Cluster Configuration**, choose your Database Engine:
   - **MySQL** (Port 3306)
   - **PostgreSQL** (Port 5432)
3. Input your Database Host Endpoint (e.g. `db-primary.prod.internal`), Database Name (`appdb`), Username, and Password.
4. Click **Connect Database**.

---

## 3. Docker Containerization

```bash
cd src/app

# Build Docker image
docker build -t enterprise-3tier-app:latest .

# Run Docker container
docker run -p 8080:8080 enterprise-3tier-app:latest
```

---

## 4. Operational CLI Commands Reference

| Command | Action |
|---------|--------|
| `health` | Inspect health status across all 3 tiers |
| `db-status` | Inspect active database engine status |
| `info` | Display host and region metadata |
| `ls` / `dir` | List local directory contents |
| `pwd` | Print working directory |
| `whoami` | Show current OS user |
| `help` | Show command reference |
| `clear` | Clear terminal output |
