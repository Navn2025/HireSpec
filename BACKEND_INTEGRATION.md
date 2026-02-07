# Backend Integration & ATS Scoring System

## Overview

This document describes the integrated backend system for the Hiring & Assessment Platform, including:
- Database-backed authentication
- Resume upload and parsing
- ATS (Applicant Tracking System) scoring
- Candidate filtering and ranking
- Company HR dashboard features
- Results storage and reporting

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Frontend (React)                         │
│    ┌──────────┐  ┌───────────┐  ┌──────────┐  ┌─────────────┐  │
│    │ Candidate│  │  Company  │  │   Auth   │  │  Interview  │  │
│    │   App    │  │    HR     │  │  Pages   │  │   System    │  │
│    └────┬─────┘  └─────┬─────┘  └────┬─────┘  └──────┬──────┘  │
└─────────┼──────────────┼─────────────┼───────────────┼──────────┘
          │              │             │               │
          ▼              ▼             ▼               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Node.js Backend                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │ /resume  │ │ /hiring  │ │/companies│ │/portal-  │           │
│  │          │ │          │ │          │ │  auth    │           │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘           │
│       │            │            │            │                  │
│  ┌────┴────────────┴────────────┴────────────┴────────────┐    │
│  │                    Services Layer                       │    │
│  │  resumeParser.js  │  candidateFilter.js  │ resultsStorage│   │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│                     MySQL Database                               │
│  users │ jobs │ applications │ ats_scores │ candidate_resumes   │
└─────────────────────────────────────────────────────────────────┘
```

## Setup

### 1. Database Setup

Run the migration to create ATS-related tables:

```bash
mysql -u root -p interview_platform_db < database/ats_migration.sql
```

Or run the unified schema:
```bash
mysql -u root -p < database/unified-schema.sql
```

### 2. Install Dependencies

```bash
cd backend
npm install
```

### 3. Environment Variables

Create `.env` in the backend folder:

```env
# Database
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=interview_platform_db

# AI (for resume parsing)
GEMINI_API_KEY=your_gemini_api_key

# Server
PORT=5000
FRONTEND_URL=http://localhost:5173
```

### 4. Start the Server

```bash
npm run dev
```

## API Endpoints

### Authentication (`/api/portal-auth`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/register` | Register new user |
| POST | `/login` | Login with username/password |
| GET | `/me` | Get current user profile |
| PUT | `/profile` | Update user profile |
| POST | `/logout` | Logout |
| POST | `/send-otp` | Send OTP for verification |
| POST | `/verify-otp` | Verify OTP |
| POST | `/forgot-password` | Request password reset |
| POST | `/reset-password` | Reset password with OTP |
| POST | `/change-password` | Change password (authenticated) |
| GET | `/notifications` | Get user notifications |

### Resume (`/api/resume`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/upload` | Upload and parse resume |
| GET | `/:user_id` | Get resume info |
| GET | `/:user_id/download` | Download resume file |
| POST | `/ats-score` | Calculate ATS score |
| POST | `/analyze` | Get AI analysis |
| DELETE | `/:user_id` | Delete resume |

### Hiring (`/api/hiring`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/jobs` | Create job posting |
| GET | `/jobs` | Get all jobs |
| PUT | `/jobs/:id` | Update job |
| GET | `/jobs/:id/applications` | Get job applications |
| GET | `/jobs/:id/top-candidates` | Get top candidates |
| GET | `/jobs/:id/candidate-tiers` | Get candidates by ATS tier |
| PUT | `/applications/:id` | Update application status |
| POST | `/applications/bulk-update` | Bulk update statuses |
| POST | `/candidates/filter` | Filter candidates |
| POST | `/candidates/compare` | Compare candidates |
| GET | `/candidates/search` | Search candidates |
| POST | `/assessments/schedule` | Schedule assessments |
| POST | `/interviews/schedule` | Schedule interview |
| GET | `/analytics` | Get hiring analytics |

### Applications (`/api/applications`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | Apply for a job |
| GET | `/user/:user_id` | Get user's applications |
| GET | `/:id` | Get application details |
| PUT | `/:id/withdraw` | Withdraw application |
| GET | `/jobs/available` | Get available jobs |
| GET | `/jobs/recommended/:user_id` | Get recommended jobs |

### Companies (`/api/companies`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/` | Create company |
| GET | `/:id` | Get company |
| PUT | `/:id` | Update company |
| GET | `/` | Get all companies |
| POST | `/:id/members` | Add member |
| DELETE | `/:id/members/:user_id` | Remove member |
| GET | `/:id/dashboard` | Get company dashboard |
| GET | `/user/:user_id` | Get user's companies |

## ATS Scoring System

### How It Works

The ATS system analyzes resumes against job requirements using:

1. **Skills Matching (35%)** - Compares candidate skills with required/preferred skills
2. **Experience Matching (25%)** - Checks if candidate has required experience
3. **Education Matching (15%)** - Validates education requirements
4. **Keyword Density (15%)** - Searches for industry keywords
5. **Format Score (10%)** - Evaluates resume completeness

### Score Tiers

| Score | Status | Recommendation |
|-------|--------|----------------|
| 80-100 | Highly Recommended | Move to interview |
| 65-79 | Recommended | Consider for screening |
| 50-64 | Consider | Review if pool is small |
| 35-49 | Below Threshold | May need more skills |
| 0-34 | Not Recommended | Significant gaps |

### Example Usage

```javascript
// Upload resume and get ATS score
import { uploadResume, calculateATSScore } from './services/hiringApi';

// Upload
const result = await uploadResume(file, userId, jobId);
console.log(result.data.ats_score);

// Calculate for specific job
const atsResult = await calculateATSScore(userId, jobId);
console.log(atsResult.data.ats_score.overall_score);
console.log(atsResult.data.ats_score.matched_skills);
console.log(atsResult.data.ats_score.missing_skills);
console.log(atsResult.data.ats_score.recommendations);
```

## Candidate Filtering

### Filter Options

```javascript
import { filterCandidates } from './services/hiringApi';

const result = await filterCandidates({
    job_id: 1,
    company_id: 1,
    min_ats_score: 60,
    max_ats_score: 100,
    skills: ['React', 'Node.js', 'Python'],
    min_experience: 2,
    max_experience: 8,
    education_level: 'bachelor',
    location: 'New York',
    status: ['applied', 'screening'],
    sort_by: 'ats_score',
    sort_order: 'DESC',
    page: 1,
    limit: 20
});
```

### Compare Candidates

```javascript
import { compareCandidates } from './services/hiringApi';

const comparison = await compareCandidates([1, 2, 3], jobId);
console.log(comparison.data.candidates);
console.log(comparison.data.rankings);
console.log(comparison.data.recommendation);
```

## Resume Parsing

The system uses Google Gemini AI to:
1. Extract text from PDF/DOCX files
2. Parse into structured JSON (name, skills, experience, education)
3. Calculate experience years
4. Extract contact information

### Parsed Resume Structure

```json
{
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+1-555-0123",
    "location": "New York, NY",
    "linkedin": "linkedin.com/in/johndoe",
    "github": "github.com/johndoe",
    "summary": "Experienced software engineer...",
    "skills": {
        "technical": ["JavaScript", "Python", "React"],
        "soft": ["Leadership", "Communication"],
        "tools": ["Git", "Docker", "AWS"]
    },
    "experience": [
        {
            "title": "Senior Developer",
            "company": "Tech Corp",
            "startDate": "01/2020",
            "endDate": "Present",
            "achievements": ["Led team of 5", "Increased performance 40%"]
        }
    ],
    "education": [
        {
            "degree": "Bachelor of Science in Computer Science",
            "institution": "State University",
            "graduationDate": "05/2018"
        }
    ],
    "certifications": [
        {
            "name": "AWS Solutions Architect",
            "issuer": "Amazon",
            "date": "2023"
        }
    ],
    "total_experience_years": 5
}
```

## Company HR Dashboard

### Dashboard Stats

- Total jobs (open/closed)
- Applications by status
- Recent applications
- Top candidates (by ATS score)
- Skill demand analysis

### Example

```javascript
import { getCompanyDashboard } from './services/hiringApi';

const dashboard = await getCompanyDashboard(companyId);
console.log(dashboard.data.stats);
console.log(dashboard.data.recent_applications);
console.log(dashboard.data.top_candidates);
```

## Results Storage

All results are stored in the database:

- **Assessment Results** - Scores, answers, proctoring summary
- **Interview Results** - Ratings, feedback, recommendations
- **Coding Submissions** - Code, test results, AI feedback
- **Candidate Reports** - Comprehensive evaluation reports

### Store Results

```javascript
import { storeAssessmentResult, generateCandidateReport } from './services/hiringApi';

// Store assessment result
await storeAssessmentResult({
    assessment_id: 1,
    candidate_user_id: 5,
    job_id: 2,
    score: 85,
    max_score: 100,
    time_taken_seconds: 3600,
    answers: [...],
    proctoring_summary: {...}
});

// Generate report
await generateCandidateReport({
    candidate_user_id: 5,
    assessment_id: 1,
    job_id: 2,
    overall_score: 82,
    technical_score: 85,
    communication_score: 78,
    strengths: ["Problem solving", "Clean code"],
    weaknesses: ["System design"],
    recommendations: "Strong candidate for junior to mid-level positions"
});
```

## Frontend Integration

Import the hiring API service:

```javascript
import hiringApi from './services/hiringApi';

// Or import specific functions
import { 
    uploadResume, 
    calculateATSScore, 
    applyForJob,
    getJobApplications 
} from './services/hiringApi';
```

## Database Tables

New tables added:
- `candidate_resumes` - Parsed resume data
- `ats_scores` - ATS scores per user/job
- `assessment_results` - Detailed assessment results
- `interview_results` - Detailed interview evaluations
- `code_analysis` - AI code review feedback

## Error Handling

All endpoints return consistent error format:

```json
{
    "message": "Error description",
    "error": "Detailed error message (in development)"
}
```

Success responses:

```json
{
    "success": true,
    "message": "Action completed",
    "data": { ... }
}
```
