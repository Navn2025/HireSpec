# 🚀 Microservices Interview & Assessment Platform - Setup Guide

This platform uses a **microservices architecture** with three main services:

## 📐 Architecture Overview

```
┌─────────────────────────────────────────────────┐
│              Frontend (React + Vite)            │
│                 Port: 5173                      │
└────────────┬────────────────────┬────────────────┘
             │                    │
             │                    │
    ┌────────▼────────┐   ┌──────▼──────────┐
    │  Node.js Backend│   │  Python Backend │
    │    Port: 5000   │   │   Port: 5001    │
    │                 │   │                 │
    │ - Interviews    │   │ - Auth          │
    │ - Coding Tests  │   │ - Face ID       │
    │ - AI Features   │   │ - Hiring        │
    │ - Axiom Chat    │   │ - Assessments   │
    └────────┬────────┘   └────────┬────────┘
             │                     │
             └──────────┬──────────┘
                        │
                 ┌──────▼──────┐
                 │    MySQL    │
                 │  Port: 3306 │
                 └─────────────┘
```

## 🛠️ Prerequisites

- **Node.js** 18+ ([Download](https://nodejs.org/))
- **Python** 3.11+ ([Download](https://www.python.org/))
- **MySQL** 8.0+ ([Download](https://dev.mysql.com/downloads/))
- **Docker** (Optional, recommended) ([Download](https://www.docker.com/))

## 🏃 Quick Start

### Option 1: Using Docker (Recommended)

1. **Clone and navigate to the project:**

   ```bash
   cd c:\Users\navne\Desktop\IIT
   ```

2. **Create `.env` file in the root:**

   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Start all services:**

   ```bash
   docker-compose up -d
   ```

4. **Initialize the database** (first time only):

   ```bash
   docker-compose exec mysql mysql -uroot -p < database/unified-schema.sql
   ```

5. **Access the application:**
   - Frontend: http://localhost:5173
   - Node.js API: http://localhost:5000
   - Python API: http://localhost:5001

### Option 2: Manual Setup

#### Step 1: Set up MySQL Database

1. **Start MySQL server**

2. **Create the database:**

   ```bash
   mysql -u root -p < database/unified-schema.sql
   ```

3. **Verify tables created:**
   ```bash
   mysql -u root -p interview_platform_db -e "SHOW TABLES;"
   ```

#### Step 2: Configure Environment Variables

1. **Node.js Backend (.env):**

   ```bash
   cd backend
   cp .env.example .env
   ```

   Edit `backend/.env`:

   ```env
   PORT=5000
   DB_HOST=localhost
   DB_PORT=3306
   DB_USER=root
   DB_PASSWORD=your_password
   DB_NAME=interview_platform_db
   GROQ_API_KEY=your_groq_key
   GEMINI_API_KEY=your_gemini_key
   ```

2. **Python Backend (.env):**

   ```bash
   cd Hiring-and-Assesment-Portal/backend
   cp .env.example .env
   ```

   Edit `Hiring-and-Assesment-Portal/backend/.env`:

   ```env
   DB_HOST=localhost
   DB_PORT=3306
   DB_USER=root
   DB_PASSWORD=your_password
   DB_NAME=interview_platform_db
   SECRET_KEY=your_secret_key
   ```

#### Step 3: Install Dependencies

1. **Node.js Backend:**

   ```bash
   cd backend
   npm install
   ```

2. **Python Backend:**

   ```bash
   cd Hiring-and-Assesment-Portal/backend
   python -m venv venv
   venv\Scripts\activate  # Windows
   # source venv/bin/activate  # Linux/Mac
   pip install -r requirements.txt
   pip install mysql-connector-python
   ```

3. **Frontend:**
   ```bash
   cd frontend
   npm install
   ```

#### Step 4: Start All Services

Open **3 separate terminals**:

**Terminal 1 - Node.js Backend:**

```bash
cd backend
node server.js
```

**Terminal 2 - Python Backend:**

```bash
cd Hiring-and-Assesment-Portal/backend
python app.py
```

**Terminal 3 - Frontend:**

```bash
cd frontend
npm run dev
```

#### Step 5: Access the Application

- **Frontend:** http://localhost:5173
- **Node.js API:** http://localhost:5000
- **Python API:** http://localhost:5001

## 📊 Database Schema

The platform uses a **unified MySQL database** with the following key tables:

### Core Tables:

- **users** - User accounts (candidates, HR, admins)
- **companies** - Company profiles
- **jobs** - Job postings
- **applications** - Job applications

### Assessment Tables:

- **assessments** - Assessment records
- **interviews** - Interview sessions
- **coding_sessions** - Coding practice sessions
- **coding_problems** - Problem bank
- **coding_submissions** - Code submissions

### Monitoring Tables:

- **proctor_logs** - Proctoring events
- **ai_detection_logs** - AI content detection
- **candidate_reports** - Assessment reports

### Chat & Support:

- **axiom_chats** - AI chat conversations
- **axiom_messages** - Chat messages

## 🔌 API Endpoints

### Node.js Backend (Port 5000)

| Endpoint                 | Description             |
| ------------------------ | ----------------------- |
| `/api/interview/*`       | Interview management    |
| `/api/questions/*`       | Question bank           |
| `/api/coding-practice/*` | Coding practice         |
| `/api/cp/*`              | Coding practice modules |
| `/api/ai-interview/*`    | AI interview system     |
| `/api/axiom/*`           | AI chat assistant       |
| `/api/proctoring/*`      | Proctoring features     |
| `/api/ai/*`              | AI analysis             |

### Python Backend (Port 5001)

| Endpoint              | Description           |
| --------------------- | --------------------- |
| `/api/auth/*`         | Authentication        |
| `/api/register`       | User registration     |
| `/api/login`          | User login            |
| `/api/face/*`         | Face recognition      |
| `/api/jobs/*`         | Job management        |
| `/api/applications/*` | Applications          |
| `/api/assessments/*`  | Assessment management |

## 🔐 Environment Variables

Create a `.env` file in the project root:

```env
# Database
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=interview_platform_db

# Node.js Backend
PORT=5000
FRONTEND_URL=http://localhost:5173

# AI Services
GROQ_API_KEY=your_groq_api_key
GEMINI_API_KEY=your_gemini_api_key
PINECONE_API_KEY=your_pinecone_api_key
PINECONE_INDEX=axiom-chat-memory

# Python Backend
SECRET_KEY=your_secret_key_here
MAIL_SERVER=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your_email@gmail.com
MAIL_PASSWORD=your_app_password
```

## 🧪 Testing the Setup

### 1. Test Node.js Backend:

```bash
curl http://localhost:5000/api/health
# Expected: {"status":"ok","message":"Server is running"}
```

### 2. Test Python Backend:

```bash
curl http://localhost:5001/api/health
# Expected: {"status":"ok"}
```

### 3. Test Database Connection:

```bash
mysql -u root -p interview_platform_db -e "SELECT COUNT(*) FROM users;"
```

## 📁 Project Structure

```
IIT/
├── backend/                    # Node.js Backend
│   ├── db/
│   │   └── database.js        # MySQL connection
│   ├── routes/                # API routes
│   ├── services/              # Business logic
│   ├── socket/                # WebSocket handlers
│   ├── server.js              # Entry point
│   ├── package.json
│   └── Dockerfile
│
├── Hiring-and-Assesment-Portal/  # Python Backend
│   └── backend/
│       ├── app.py             # Flask entry point
│       ├── face_recognition_engine.py
│       ├── database_mysql.py  # MySQL connection
│       ├── requirements.txt
│       └── Dockerfile
│
├── frontend/                   # React Frontend
│   ├── src/
│   │   ├── pages/             # Page components
│   │   ├── components/        # Reusable components
│   │   └── services/          # API clients
│   ├── package.json
│   └── Dockerfile
│
├── database/
│   └── unified-schema.sql     # Database schema
│
├── docker-compose.yml         # Docker orchestration
└── MICROSERVICES_SETUP.md    # This file
```

## 🐛 Troubleshooting

### Database Connection Issues:

**MySQL not running:**

```bash
# Check MySQL status
mysql --version
# Start MySQL service (Windows)
net start MySQL80
```

**Permission denied:**

```bash
# Grant permissions
mysql -u root -p
GRANT ALL PRIVILEGES ON interview_platform_db.* TO 'root'@'localhost';
FLUSH PRIVILEGES;
```

### Port Already in Use:

**Kill process on port:**

```powershell
# Windows
netstat -ano | findstr :5000
taskkill /PID <PID> /F

# Linux/Mac
lsof -i :5000
kill -9 <PID>
```

### Python Dependencies:

```bash
pip install --upgrade pip
pip install -r requirements.txt
pip install mysql-connector-python python-dotenv
```

### Node.js Dependencies:

```bash
cd backend
rm -rf node_modules package-lock.json
npm install
```

## 📝 Common Tasks

### Add a New User (Direct Database):

```sql
INSERT INTO users (username, email, password, role)
VALUES ('testuser', 'test@example.com', '$2b$12$...', 'candidate');
```

### View Recent Activity:

```sql
SELECT * FROM activity_logs ORDER BY created_at DESC LIMIT 10;
```

### Check Active Assessments:

```sql
SELECT * FROM v_active_assessments;
```

### Reset Database:

```bash
mysql -u root -p interview_platform_db < database/unified-schema.sql
```

## 🚀 Production Deployment

### Using Docker (Recommended):

1. **Build images:**

   ```bash
   docker-compose build
   ```

2. **Deploy with nginx:**

   ```bash
   docker-compose --profile production up -d
   ```

3. **Configure SSL:**
   - Add SSL certificates to `nginx/ssl/`
   - Update `nginx/nginx.conf`

### Manual Deployment:

1. Set `NODE_ENV=production`
2. Use process manager (PM2, systemd)
3. Set up reverse proxy (Nginx, Apache)
4. Enable HTTPS
5. Configure firewall rules

## 🆘 Support

**Issues?**

- Check logs: `docker-compose logs -f`
- Verify ports: `netstat -ano | findstr "5000 5001 5173 3306"`
- Test endpoints individually
- Check `.env` configuration

**Need Help?**

- Review error messages carefully
- Check database schema is loaded
- Verify API keys are valid
- Ensure all services are running

## ✅ Verification Checklist

- [ ] MySQL server running
- [ ] Database `interview_platform_db` created
- [ ] Tables created from schema
- [ ] Node.js backend running on port 5000
- [ ] Python backend running on port 5001
- [ ] Frontend running on port 5173
- [ ] All environment variables configured
- [ ] API health checks passing
- [ ] Frontend can reach both backends

---

**🎉 You're all set!** Visit http://localhost:5173 to start using the platform.
