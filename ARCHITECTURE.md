# 🏗️ Unified Interview Platform Architecture

## Overview

This architecture separates authentication (Python) from business logic (Node.js) while sharing a single MySQL database.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     FRONTEND (React)                         │
│                    Port: 5173 (dev)                          │
└───────────┬─────────────────────────────────┬───────────────┘
            │                                   │
            │ Auth Requests                     │ App Requests
            │ (/auth/*, /api/user/*)           │ (/api/*)
            │                                   │
┌───────────▼────────────┐           ┌────────▼──────────────┐
│  PYTHON AUTH SERVICE   │           │  NODE.js APP SERVICE  │
│     Port: 5000         │◄─────────►│     Port: 5001        │
│                        │   Verify  │                       │
│  - Registration        │   Token   │  - Jobs Management    │
│  - Login (User/Face)   │           │  - Assessments        │
│  - OTP Verification    │           │  - Interviews         │
│  - Password Reset      │           │  - Coding Practice    │
│  - Face Recognition    │           │  - Proctoring         │
│  - Session Management  │           │  - Reports            │
│  - Token Generation    │           │  - Notifications      │
└───────────┬────────────┘           └────────┬──────────────┘
            │                                   │
            │                                   │
            └───────────────┬───────────────────┘
                            │
                   ┌────────▼─────────┐
                   │  MySQL Database  │
                   │   Port: 3306     │
                   │                  │
                   │ interview_       │
                   │ platform_unified │
                   └──────────────────┘
```

## Service Breakdown

### 🐍 Python Authentication Service (Port 5000)

**Responsibilities:**

- User registration with face recognition (Pinecone + FaceNet)
- Login (traditional username/password + face recognition)
- OTP generation and verification (email)
- Password reset flow
- JWT token generation and validation
- Session management
- Face embedding storage and verification

**Technology Stack:**

- Flask (REST API)
- Pinecone (Vector database for face embeddings)
- FaceNet (InceptionResnetV1) - 512-dimensional face encoding
- MediaPipe + MTCNN (Face detection)
- Flask-Mail (Email OTP)
- JWT (Token generation)
- bcrypt (Password hashing)

**Key Endpoints:**

```
POST   /api/auth/send-otp              # Send OTP to email
POST   /api/auth/verify-otp            # Verify OTP code
POST   /api/auth/register              # Register with face + credentials
POST   /api/auth/login                 # Traditional login
POST   /api/auth/face-login            # Face recognition login
POST   /api/auth/logout                # Logout user
POST   /api/auth/forgot-password       # Initiate password reset
POST   /api/auth/reset-password        # Complete password reset
POST   /api/auth/reset-face            # Re-register face data
POST   /api/auth/verify-token          # Verify JWT token (for Node.js)
GET    /api/user/me                    # Get current user info
POST   /detect_face                    # Check face presence
GET    /health                         # Health check
```

**Database Tables Used:**

- `users` (read/write)
- `otp_codes` (read/write)
- `user_sessions` (read/write)

---

### 🟢 Node.js Application Service (Port 5001)

**Responsibilities:**

- All business logic after authentication
- Job posting and management
- Application tracking
- Assessment creation and management
- Live and AI interviews
- Coding practice problems
- Code execution and analysis
- Proctoring and security monitoring
- Report generation
- Notifications

**Technology Stack:**

- Express.js (REST API)
- Socket.io (Real-time communication)
- Docker (Code execution sandbox)
- Groq AI (LLM for interviews and analysis)
- WebRTC (Video interviews)

**Key Endpoints:**

```
# Job Management
POST   /api/jobs                       # Create job posting
GET    /api/jobs                       # List jobs
GET    /api/jobs/:id                   # Get job details
PUT    /api/jobs/:id                   # Update job
DELETE /api/jobs/:id                   # Delete job

# Applications
POST   /api/applications               # Apply to job
GET    /api/applications               # List applications
GET    /api/applications/:id           # Get application details
PUT    /api/applications/:id/status    # Update application status

# Assessments
POST   /api/assessments                # Create assessment
GET    /api/assessments/:id            # Get assessment
POST   /api/assessments/:id/start      # Start assessment
POST   /api/assessments/:id/submit     # Submit assessment

# Interviews
POST   /api/interviews                 # Schedule interview
GET    /api/interviews/:id             # Get interview details
POST   /api/interviews/:id/join        # Join interview room
WebSocket /interview/:roomId           # Real-time interview

# Coding Practice
GET    /api/problems                   # List coding problems
GET    /api/problems/:id               # Get problem details
POST   /api/code/execute               # Execute code
POST   /api/code/submit                # Submit solution

# Proctoring
POST   /api/proctor/log                # Log proctoring event
GET    /api/proctor/violations/:id     # Get violations

# Reports
GET    /api/reports/candidate/:id      # Get candidate report
POST   /api/reports/generate           # Generate report
```

**Database Tables Used:**

- `users` (read only - verified via Python service)
- `companies`
- `company_members`
- `jobs`
- `applications`
- `assessments`
- `interviews`
- `coding_problems`
- `coding_sessions`
- `coding_submissions`
- `proctor_logs`
- `ai_detection_logs`
- `candidate_reports`
- `notifications`

---

## Authentication Flow

### 1. Registration Flow

```
Frontend → Python Service
  POST /api/auth/send-otp
  { email: "user@example.com", purpose: "register" }

  ↓ OTP sent to email

Frontend → Python Service
  POST /api/auth/verify-otp
  { email, otp, purpose: "register" }

  ↓ OTP verified

Frontend → Python Service (with webcam images)
  POST /api/auth/register
  {
    username, email, password,
    images: [base64_1, base64_2, base64_3],  // 3+ face angles
    role: "candidate"
  }

  ↓ Face embeddings stored in Pinecone + User in DB

Response: { user, token }
```

### 2. Login Flow (Traditional)

```
Frontend → Python Service
  POST /api/auth/login
  { username, password }

  ↓ Verify credentials

Response: { user, token }
```

### 3. Login Flow (Face Recognition)

```
Frontend → Python Service (with webcam image)
  POST /api/auth/face-login
  { image: base64_image }

  ↓ Match face in Pinecone, verify user

Response: { user, token }
```

### 4. Node.js Service Integration

```
Frontend → Node.js Service
  GET /api/jobs
  Headers: { Authorization: "Bearer <token>" }

Node.js → Python Service (Internal)
  POST /api/auth/verify-token
  { token }

  ↓ Validate token

Response: { valid: true, userId, role }

Node.js → Process Request with user context
```

---

## Frontend Integration

### API Service Configuration

```javascript
// src/lib/api.js
const API_ENDPOINTS = {
  AUTH: 'http://localhost:5000',     // Python Auth Service
  APP: 'http://localhost:5001'        // Node.js App Service
};

// Auth requests go to Python
export const authApi = {
  register: (data) => fetch(`${API_ENDPOINTS.AUTH}/api/auth/register`, {...}),
  login: (data) => fetch(`${API_ENDPOINTS.AUTH}/api/auth/login`, {...}),
  faceLogin: (data) => fetch(`${API_ENDPOINTS.AUTH}/api/auth/face-login`, {...}),
  // ...
};

// App requests go to Node.js (with auth token)
export const appApi = {
  getJobs: () => fetch(`${API_ENDPOINTS.APP}/api/jobs`, {
    headers: { 'Authorization': `Bearer ${token}` }
  }),
  // ...
};
```

---

## Database Setup

### Single Shared Database

Both services connect to the same MySQL database: `interview_platform_unified`

**Python Service Connection:**

```python
# backend_python/config.py
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': int(os.getenv('DB_PORT', '3306')),
    'user': os.getenv('DB_USER', 'root'),
    'password': os.getenv('DB_PASSWORD', ''),
    'database': 'interview_platform_unified'
}
```

**Node.js Service Connection:**

```javascript
// backend_nodejs/config.js
const DB_CONFIG = {
  host: process.env.DB_HOST || "localhost",
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "",
  database: "interview_platform_unified",
};
```

---

## Security Considerations

### 1. Token-Based Authentication

- Python service generates JWT tokens
- Tokens include: userId, username, role, email
- Node.js service validates tokens via Python service endpoint

### 2. Session Management

- Sessions stored in `user_sessions` table
- Automatic expiry and cleanup
- Device fingerprinting for security

### 3. Face Recognition Security

- Multi-angle capture (minimum 3 images)
- 512-dimensional embeddings in Pinecone
- Cosine similarity matching with adaptive thresholding
- Duplicate face detection

### 4. Proctoring

- Real-time monitoring via Node.js service
- Multiple detection types (face, tab switch, violations)
- Severity levels and automatic flagging

---

## Environment Variables

### Python Service (.env)

```bash
# Server
PORT=5000
FLASK_ENV=production

# Database
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=interview_platform_unified

# Face Recognition
PINECONE_API_KEY=your_pinecone_key
PINECONE_INDEX=face-auth-index
PINECONE_HOST=your_host
FACE_MIN_SCORE=0.35
FACE_RATIO_THRESHOLD=0.18

# Email (OTP)
MAIL_SERVER=smtp.gmail.com
MAIL_PORT=587
MAIL_USE_TLS=true
MAIL_USERNAME=your_email@gmail.com
MAIL_PASSWORD=your_app_password
MAIL_DEFAULT_SENDER=noreply@interview-platform.com

# JWT
JWT_SECRET_KEY=your_secret_key_here
JWT_EXPIRY_HOURS=24

# CORS
FRONTEND_ORIGIN=http://localhost:5173
NODE_SERVICE_URL=http://localhost:5001
```

### Node.js Service (.env)

```bash
# Server
PORT=5001
NODE_ENV=production

# Database
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=interview_platform_unified

# Python Auth Service
AUTH_SERVICE_URL=http://localhost:5000
AUTH_SERVICE_SECRET=shared_secret_key

# AI Services
GROQ_API_KEY=your_groq_key
OPENAI_API_KEY=your_openai_key

# Code Execution
DOCKER_ENABLED=true
CODE_TIMEOUT_MS=10000
CODE_MEMORY_LIMIT=512m

# WebRTC/Socket
SOCKET_PORT=5002

# Frontend
FRONTEND_URL=http://localhost:5173
```

---

## Deployment

### Development

```bash
# Terminal 1: Start Python Auth Service
cd Hiring-and-Assesment-Portal/backend
python app.py

# Terminal 2: Start Node.js App Service
cd backend
npm start

# Terminal 3: Start Frontend
cd frontend
npm run dev
```

### Production

- Python Service: Gunicorn + Nginx
- Node.js Service: PM2 + Nginx
- Database: MySQL 8.0+
- Frontend: Vite build → Static hosting

---

## API Communication Example

```javascript
// User registration (Frontend → Python)
const response = await fetch("http://localhost:5000/api/auth/register", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    username: "john_doe",
    email: "john@example.com",
    password: "password123",
    images: [image1, image2, image3],
    role: "candidate",
  }),
});

const { user, token } = await response.json();
localStorage.setItem("authToken", token);

// Create job application (Frontend → Node.js)
const applyResponse = await fetch("http://localhost:5001/api/applications", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    Authorization: `Bearer ${token}`, // Token from Python service
  },
  body: JSON.stringify({
    job_id: 123,
    cover_letter: "I am very interested...",
  }),
});
```

---

## Benefits of This Architecture

✅ **Separation of Concerns**: Auth logic isolated from business logic  
✅ **Scalability**: Scale services independently based on load  
✅ **Security**: Face recognition and sensitive auth in dedicated service  
✅ **Flexibility**: Use best tools for each domain (Python for ML, Node for I/O)  
✅ **Maintainability**: Clear boundaries, easier debugging  
✅ **Single Source of Truth**: One database, consistent data

---

## Next Steps

1. ✅ Create unified database schema
2. 🔄 Setup Python authentication service
3. 🔄 Update Node.js service for token validation
4. 🔄 Create frontend API integration layer
5. 🔄 Test end-to-end authentication flow
6. 🔄 Deploy and monitor
