-- ===================================================================
-- UNIFIED INTERVIEW PLATFORM DATABASE SCHEMA
-- Python Auth Service + Node.js Application Service
-- ===================================================================

CREATE DATABASE IF NOT EXISTS interview_platform_unified;
USE interview_platform_unified;

-- ===================================================================
-- AUTHENTICATION & USER MANAGEMENT (Shared by both services)
-- ===================================================================

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    phone VARCHAR(20),
    role ENUM('candidate', 'company_admin', 'company_hr', 'interviewer', 'admin') NOT NULL DEFAULT 'candidate',
    
    -- Profile Information
    profile_image VARCHAR(500),
    bio TEXT,
    linkedin_url VARCHAR(500),
    github_url VARCHAR(500),
    portfolio_url VARCHAR(500),
    current_company VARCHAR(255),
    current_role VARCHAR(255),
    experience_years INT DEFAULT 0,
    skills_json JSON,
    education_json JSON,
    
    -- Resume Management
    resume_filename VARCHAR(255),
    resume_original_name VARCHAR(255),
    resume_url VARCHAR(500),
    resume_uploaded_at TIMESTAMP NULL,
    
    -- Face Recognition (Python Service)
    face_embedding TEXT,
    
    -- Account Status
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    email_verified BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    
    -- Indexes for performance
    INDEX idx_username (username),
    INDEX idx_email (email),
    INDEX idx_role (role),
    INDEX idx_active (is_active),
    INDEX idx_verified (is_verified)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- OTP Codes for Email Verification (Python Service)
CREATE TABLE IF NOT EXISTS otp_codes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    otp VARCHAR(6) NOT NULL,
    purpose ENUM('register', 'forgot_password', 'verify_email', 'login_2fa') NOT NULL DEFAULT 'register',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    
    INDEX idx_email_otp (email, otp),
    INDEX idx_expires (expires_at),
    INDEX idx_used (used),
    INDEX idx_purpose (purpose)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Session Management (Python Service)
CREATE TABLE IF NOT EXISTS user_sessions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    session_token VARCHAR(500) NOT NULL UNIQUE,
    refresh_token VARCHAR(500),
    device_info JSON,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    
    INDEX idx_session_token (session_token),
    INDEX idx_user_id (user_id),
    INDEX idx_expires (expires_at),
    INDEX idx_active (is_active),
    CONSTRAINT fk_session_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- COMPANY MANAGEMENT (Node.js Service)
-- ===================================================================

CREATE TABLE IF NOT EXISTS companies (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    industry VARCHAR(100),
    company_size ENUM('1-10', '11-50', '51-200', '201-500', '501-1000', '1000+') DEFAULT '1-10',
    website VARCHAR(500),
    logo_url VARCHAR(500),
    cover_image_url VARCHAR(500),
    headquarters VARCHAR(255),
    founded_year INT,
    linkedin_url VARCHAR(500),
    twitter_url VARCHAR(500),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(20),
    is_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    settings_json JSON,
    created_by_user_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_slug (slug),
    INDEX idx_name (name),
    INDEX idx_industry (industry),
    INDEX idx_is_active (is_active),
    INDEX idx_created_by (created_by_user_id),
    CONSTRAINT fk_company_creator FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS company_members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    company_id INT NOT NULL,
    user_id INT NOT NULL,
    role ENUM('owner', 'admin', 'hr', 'interviewer', 'viewer') NOT NULL DEFAULT 'viewer',
    department VARCHAR(100),
    title VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    invited_by_user_id INT,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY uq_company_user (company_id, user_id),
    INDEX idx_company (company_id),
    INDEX idx_user (user_id),
    INDEX idx_role (role),
    CONSTRAINT fk_member_company FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
    CONSTRAINT fk_member_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_member_inviter FOREIGN KEY (invited_by_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- JOB MANAGEMENT (Node.js Service)
-- ===================================================================

CREATE TABLE IF NOT EXISTS jobs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    company_id INT NOT NULL,
    created_by_user_id INT,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL,
    description TEXT,
    requirements TEXT,
    responsibilities TEXT,
    job_type ENUM('full-time', 'part-time', 'contract', 'internship', 'freelance') DEFAULT 'full-time',
    experience_level ENUM('entry', 'mid', 'senior', 'lead', 'executive') DEFAULT 'mid',
    min_experience_years INT DEFAULT 0,
    max_experience_years INT,
    
    -- Salary Information
    salary_min DECIMAL(12, 2),
    salary_max DECIMAL(12, 2),
    salary_currency VARCHAR(3) DEFAULT 'USD',
    
    -- Location
    location VARCHAR(255),
    is_remote BOOLEAN DEFAULT FALSE,
    
    -- Skills & Assessment
    skills_required_json JSON,
    skills_preferred_json JSON,
    assessment_modules_json JSON,
    benefits_json JSON,
    
    -- Job Metadata
    total_positions INT DEFAULT 1,
    filled_positions INT DEFAULT 0,
    status ENUM('draft', 'published', 'paused', 'closed', 'archived') DEFAULT 'draft',
    published_at TIMESTAMP NULL,
    closes_at TIMESTAMP NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_company (company_id),
    INDEX idx_creator (created_by_user_id),
    INDEX idx_status (status),
    INDEX idx_job_type (job_type),
    INDEX idx_experience_level (experience_level),
    INDEX idx_location (location),
    INDEX idx_remote (is_remote),
    INDEX idx_published (published_at),
    CONSTRAINT fk_job_company FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
    CONSTRAINT fk_job_creator FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- APPLICATION MANAGEMENT (Node.js Service)
-- ===================================================================

CREATE TABLE IF NOT EXISTS applications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    candidate_user_id INT NOT NULL,
    job_id INT NOT NULL,
    status ENUM('applied', 'screening', 'interview_scheduled', 'assessment_sent', 'assessment_completed', 'rejected', 'accepted', 'withdrawn', 'offer_extended', 'offer_accepted', 'offer_declined') NOT NULL DEFAULT 'applied',
    cover_letter TEXT,
    resume_version VARCHAR(255),
    
    -- Screening
    screening_score DECIMAL(5,2),
    screening_notes TEXT,
    
    -- Application Metadata
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMP NULL,
    reviewed_by_user_id INT NULL,
    
    UNIQUE KEY uq_candidate_job (candidate_user_id, job_id),
    INDEX idx_candidate (candidate_user_id),
    INDEX idx_job (job_id),
    INDEX idx_status (status),
    INDEX idx_applied_at (applied_at),
    CONSTRAINT fk_app_candidate FOREIGN KEY (candidate_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_app_job FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE,
    CONSTRAINT fk_app_reviewer FOREIGN KEY (reviewed_by_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- ASSESSMENT MANAGEMENT (Node.js Service)
-- ===================================================================

CREATE TABLE IF NOT EXISTS assessments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    job_id INT NULL,
    application_id INT NULL,
    candidate_user_id INT NOT NULL,
    invited_email VARCHAR(255),
    assessment_type ENUM('coding', 'technical', 'behavioral', 'ai_interview', 'practice', 'mixed') NOT NULL,
    
    -- Assessment Configuration
    title VARCHAR(255),
    description TEXT,
    instructions TEXT,
    duration_minutes INT DEFAULT 60,
    passing_score DECIMAL(5,2) DEFAULT 50.00,
    
    -- Status & Timing
    status ENUM('pending', 'invited', 'in_progress', 'completed', 'expired', 'cancelled') NOT NULL DEFAULT 'pending',
    scheduled_at TIMESTAMP NULL,
    started_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    submission_deadline TIMESTAMP NULL,
    
    -- Scoring
    score DECIMAL(5,2),
    max_score DECIMAL(5,2) DEFAULT 100.00,
    auto_score DECIMAL(5,2),
    manual_score DECIMAL(5,2),
    
    -- Assessment Data
    questions_json JSON,
    answers_json JSON,
    feedback_json JSON,
    notes TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_job (job_id),
    INDEX idx_application (application_id),
    INDEX idx_candidate (candidate_user_id),
    INDEX idx_email (invited_email),
    INDEX idx_type (assessment_type),
    INDEX idx_status (status),
    INDEX idx_scheduled (scheduled_at),
    CONSTRAINT fk_assessment_job FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE SET NULL,
    CONSTRAINT fk_assessment_application FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE CASCADE,
    CONSTRAINT fk_assessment_candidate FOREIGN KEY (candidate_user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- INTERVIEW MANAGEMENT (Node.js Service)
-- ===================================================================

CREATE TABLE IF NOT EXISTS interviews (
    id INT AUTO_INCREMENT PRIMARY KEY,
    assessment_id INT NULL,
    application_id INT NULL,
    interview_type ENUM('live', 'ai', 'practice') NOT NULL,
    
    -- Session Information
    room_id VARCHAR(100) UNIQUE,
    session_id VARCHAR(100),
    meeting_url VARCHAR(500),
    
    -- Participants
    candidate_user_id INT NOT NULL,
    interviewer_user_id INT NULL,
    
    -- Status & Timing
    status ENUM('scheduled', 'waiting', 'active', 'completed', 'cancelled', 'no_show') NOT NULL DEFAULT 'scheduled',
    scheduled_at TIMESTAMP NULL,
    started_at TIMESTAMP NULL,
    ended_at TIMESTAMP NULL,
    duration_seconds INT,
    
    -- Interview Data
    transcript TEXT,
    recording_url VARCHAR(500),
    notes TEXT,
    questions_asked JSON,
    answers_json JSON,
    
    -- Evaluation
    rating INT CHECK (rating BETWEEN 1 AND 5),
    feedback TEXT,
    evaluation_json JSON,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_assessment (assessment_id),
    INDEX idx_application (application_id),
    INDEX idx_room (room_id),
    INDEX idx_candidate (candidate_user_id),
    INDEX idx_interviewer (interviewer_user_id),
    INDEX idx_type (interview_type),
    INDEX idx_status (status),
    INDEX idx_scheduled (scheduled_at),
    CONSTRAINT fk_interview_assessment FOREIGN KEY (assessment_id) REFERENCES assessments(id) ON DELETE SET NULL,
    CONSTRAINT fk_interview_application FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE CASCADE,
    CONSTRAINT fk_interview_candidate FOREIGN KEY (candidate_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_interview_interviewer FOREIGN KEY (interviewer_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- CODING PRACTICE & PROBLEMS (Node.js Service)
-- ===================================================================

CREATE TABLE IF NOT EXISTS coding_problems (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    description TEXT NOT NULL,
    difficulty ENUM('Easy', 'Medium', 'Hard') NOT NULL,
    category VARCHAR(100),
    topics JSON,
    
    -- Starter Code
    starter_code_js TEXT,
    starter_code_python TEXT,
    starter_code_java TEXT,
    starter_code_cpp TEXT,
    
    -- Testing
    test_cases JSON NOT NULL,
    constraints TEXT,
    hints JSON,
    solution_approach TEXT,
    time_complexity VARCHAR(100),
    space_complexity VARCHAR(100),
    
    -- Metadata
    created_by_ai BOOLEAN DEFAULT FALSE,
    created_by_user_id INT NULL,
    is_public BOOLEAN DEFAULT TRUE,
    usage_count INT DEFAULT 0,  
    success_rate DECIMAL(5,2),
    average_time_seconds INT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_slug (slug),
    INDEX idx_difficulty (difficulty),
    INDEX idx_category (category),
    INDEX idx_public (is_public),
    INDEX idx_created_by (created_by_user_id),
    CONSTRAINT fk_problem_creator FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS coding_sessions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    session_type ENUM('practice', 'assessment', 'interview') NOT NULL,
    assessment_id INT NULL,
    interview_id INT NULL,
    
    -- Session Data
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP NULL,
    duration_seconds INT,
    status ENUM('active', 'completed', 'abandoned', 'expired') NOT NULL DEFAULT 'active',
    
    -- Session Metadata
    problems_attempted INT DEFAULT 0,
    problems_solved INT DEFAULT 0,
    total_score DECIMAL(5,2) DEFAULT 0,
    
    INDEX idx_user (user_id),
    INDEX idx_assessment (assessment_id),
    INDEX idx_interview (interview_id),
    INDEX idx_type (session_type),
    INDEX idx_status (status),
    INDEX idx_started (started_at),
    CONSTRAINT fk_session_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_session_assessment FOREIGN KEY (assessment_id) REFERENCES assessments(id) ON DELETE SET NULL,
    CONSTRAINT fk_session_interview FOREIGN KEY (interview_id) REFERENCES interviews(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS coding_submissions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    session_id INT NOT NULL,
    problem_id INT NOT NULL,
    user_id INT NOT NULL,
    
    -- Code & Language
    language VARCHAR(50) NOT NULL,
    code TEXT NOT NULL,
    
    -- Execution Results
    status ENUM('pending', 'running', 'accepted', 'wrong_answer', 'runtime_error', 'time_limit', 'memory_limit', 'compilation_error') NOT NULL,
    execution_time_ms INT,
    memory_used_kb INT,
    test_cases_passed INT DEFAULT 0,
    test_cases_total INT DEFAULT 0,
    
    -- Output & Errors
    output TEXT,
    error_message TEXT,
    test_results JSON,
    
    -- Scoring
    score DECIMAL(5,2),
    
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_session (session_id),
    INDEX idx_problem (problem_id),
    INDEX idx_user (user_id),
    INDEX idx_status (status),
    INDEX idx_submitted (submitted_at),
    CONSTRAINT fk_submission_session FOREIGN KEY (session_id) REFERENCES coding_sessions(id) ON DELETE CASCADE,
    CONSTRAINT fk_submission_problem FOREIGN KEY (problem_id) REFERENCES coding_problems(id) ON DELETE CASCADE,
    CONSTRAINT fk_submission_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- PROCTORING & SECURITY (Node.js Service)
-- ===================================================================

CREATE TABLE IF NOT EXISTS proctor_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    assessment_id INT NULL,
    interview_id INT NULL,
    session_id INT NULL,
    
    -- Event Information
    type ENUM('face_detection', 'no_face', 'multiple_faces', 'tab_switch', 'window_blur', 'fullscreen_exit', 'copy', 'paste', 'right_click', 'voice_detection', 'screen_share', 'violation', 'warning', 'info') NOT NULL,
    severity ENUM('low', 'medium', 'high', 'critical') DEFAULT 'low',
    message TEXT,
    
    -- Additional Data
    payload_json JSON,
    screenshot_url VARCHAR(500),
    
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_user (user_id),
    INDEX idx_assessment (assessment_id),
    INDEX idx_interview (interview_id),
    INDEX idx_session (session_id),
    INDEX idx_type (type),
    INDEX idx_severity (severity),
    INDEX idx_timestamp (timestamp),
    CONSTRAINT fk_proctor_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_proctor_assessment FOREIGN KEY (assessment_id) REFERENCES assessments(id) ON DELETE SET NULL,
    CONSTRAINT fk_proctor_interview FOREIGN KEY (interview_id) REFERENCES interviews(id) ON DELETE SET NULL,
    CONSTRAINT fk_proctor_session FOREIGN KEY (session_id) REFERENCES coding_sessions(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ai_detection_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    assessment_id INT NULL,
    interview_id INT NULL,
    
    -- AI Detection Data
    text_analyzed TEXT NOT NULL,
    ai_probability DECIMAL(5,4),
    detection_method VARCHAR(100),
    is_ai_generated BOOLEAN,
    confidence_score DECIMAL(5,4),
    
    -- Detection Details
    details_json JSON,
    flagged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_user (user_id),
    INDEX idx_assessment (assessment_id),
    INDEX idx_interview (interview_id),
    INDEX idx_ai_generated (is_ai_generated),
    INDEX idx_flagged (flagged_at),
    CONSTRAINT fk_ai_detection_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_ai_detection_assessment FOREIGN KEY (assessment_id) REFERENCES assessments(id) ON DELETE SET NULL,
    CONSTRAINT fk_ai_detection_interview FOREIGN KEY (interview_id) REFERENCES interviews(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- REPORTS & ANALYTICS (Node.js Service)
-- ===================================================================

CREATE TABLE IF NOT EXISTS candidate_reports (
    id INT AUTO_INCREMENT PRIMARY KEY,
    candidate_user_id INT NOT NULL,
    application_id INT NULL,
    assessment_id INT NULL,
    interview_id INT NULL,
    
    -- Report Data
    report_type ENUM('assessment', 'interview', 'comprehensive', 'screening') NOT NULL,
    report_json JSON NOT NULL,
    
    -- Scoring Summary
    overall_score DECIMAL(5,2),
    technical_score DECIMAL(5,2),
    behavioral_score DECIMAL(5,2),
    communication_score DECIMAL(5,2),
    
    -- Analysis
    strengths JSON,
    weaknesses JSON,
    recommendations TEXT,
    
    -- Metadata
    generated_by_ai BOOLEAN DEFAULT FALSE,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_candidate (candidate_user_id),
    INDEX idx_application (application_id),
    INDEX idx_assessment (assessment_id),
    INDEX idx_interview (interview_id),
    INDEX idx_type (report_type),
    INDEX idx_generated (generated_at),
    CONSTRAINT fk_report_candidate FOREIGN KEY (candidate_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_report_application FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE CASCADE,
    CONSTRAINT fk_report_assessment FOREIGN KEY (assessment_id) REFERENCES assessments(id) ON DELETE CASCADE,
    CONSTRAINT fk_report_interview FOREIGN KEY (interview_id) REFERENCES interviews(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- NOTIFICATIONS & COMMUNICATION (Node.js Service)
-- ===================================================================

CREATE TABLE IF NOT EXISTS notifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    type ENUM('application_update', 'assessment_invite', 'interview_scheduled', 'report_ready', 'job_match', 'system') NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    
    -- Links & Actions
    action_url VARCHAR(500),
    action_label VARCHAR(100),
    
    -- Related Entities
    related_job_id INT NULL,
    related_application_id INT NULL,
    related_assessment_id INT NULL,
    related_interview_id INT NULL,
    
    -- Status
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_user (user_id),
    INDEX idx_type (type),
    INDEX idx_read (is_read),
    INDEX idx_created (created_at),
    CONSTRAINT fk_notification_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- SYSTEM CONFIGURATION
-- ===================================================================

-- Insert default admin user (password: Admin@123)
INSERT INTO users (username, email, password, full_name, role, is_verified, email_verified) 
VALUES (
    'admin',
    'admin@interview-platform.com',
    '$2a$10$YourHashedPasswordHere',
    'System Administrator',
    'admin',
    TRUE,
    TRUE
) ON DUPLICATE KEY UPDATE id=id;

-- ===================================================================
-- END OF SCHEMA
-- ===================================================================
