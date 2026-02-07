-- ===================================================================
-- Unified Hiring & Interview Platform Database Schema
-- This combines both Python (Flask) and Node.js microservices
-- ===================================================================

CREATE DATABASE IF NOT EXISTS interview_platform_db;
USE interview_platform_db;

-- ===================================================================
-- USER MANAGEMENT & AUTHENTICATION
-- ===================================================================

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('candidate', 'company_admin', 'company_hr', 'interviewer') NOT NULL DEFAULT 'candidate',
    face_embedding TEXT,
    resume_filename VARCHAR(255),
    resume_original_name VARCHAR(255),
    resume_uploaded_at TIMESTAMP NULL,
    profile_picture VARCHAR(255),
    phone VARCHAR(20),
    linkedin_url VARCHAR(255),
    github_url VARCHAR(255),
    bio TEXT,
    skills JSON,
    experience_years INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    INDEX idx_username (username),
    INDEX idx_email (email),
    INDEX idx_role (role),
    INDEX idx_active (is_active)
);

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
    INDEX idx_used (used)
);

-- ===================================================================
-- COMPANY & JOB MANAGEMENT
-- ===================================================================

CREATE TABLE IF NOT EXISTS companies (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    website VARCHAR(255),
    logo_url VARCHAR(255),
    industry VARCHAR(100),
    size VARCHAR(50),
    location VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_company_name (name),
    INDEX idx_industry (industry)
);

CREATE TABLE IF NOT EXISTS company_members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    company_id INT NOT NULL,
    user_id INT NOT NULL,
    role ENUM('admin', 'hr', 'interviewer') NOT NULL DEFAULT 'interviewer',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_company_user (company_id, user_id),
    INDEX idx_company (company_id),
    INDEX idx_user (user_id),
    CONSTRAINT fk_company_members_company FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
    CONSTRAINT fk_company_members_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS jobs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    company_id INT NULL,
    created_by_user_id INT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    requirements TEXT,
    location VARCHAR(255),
    job_type ENUM('full-time', 'part-time', 'contract', 'internship') DEFAULT 'full-time',
    experience_required INT DEFAULT 0,
    salary_min DECIMAL(10,2),
    salary_max DECIMAL(10,2),
    currency VARCHAR(3) DEFAULT 'USD',
    skills_json JSON,
    modules_json JSON,
    status ENUM('draft', 'open', 'closed', 'archived') DEFAULT 'draft',
    deadline TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_job_company (company_id),
    INDEX idx_job_created_by (created_by_user_id),
    INDEX idx_job_status (status),
    INDEX idx_job_created_at (created_at),
    CONSTRAINT fk_jobs_company FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE SET NULL,
    CONSTRAINT fk_jobs_created_by FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS applications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    candidate_user_id INT NOT NULL,
    job_id INT NOT NULL,
    status ENUM('applied', 'screening', 'interview_scheduled', 'rejected', 'accepted', 'withdrawn') NOT NULL DEFAULT 'applied',
    cover_letter TEXT,
    resume_version VARCHAR(255),
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_app_candidate_job (candidate_user_id, job_id),
    INDEX idx_app_candidate (candidate_user_id),
    INDEX idx_app_job (job_id),
    INDEX idx_app_status (status),
    INDEX idx_app_applied_at (applied_at),
    CONSTRAINT fk_app_candidate FOREIGN KEY (candidate_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_app_job FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE
);

-- ===================================================================
-- ASSESSMENTS & INTERVIEWS
-- ===================================================================

CREATE TABLE IF NOT EXISTS assessments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    job_id INT NULL,
    application_id INT NULL,
    candidate_user_id INT NULL,
    invited_email VARCHAR(255),
    assessment_type ENUM('coding', 'technical', 'behavioral', 'ai_interview', 'practice') NOT NULL,
    status ENUM('pending', 'in_progress', 'completed', 'expired', 'cancelled') NOT NULL DEFAULT 'pending',
    scheduled_at TIMESTAMP NULL,
    started_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    duration_minutes INT DEFAULT 60,
    score DECIMAL(5,2),
    max_score DECIMAL(5,2),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_assessment_job (job_id),
    INDEX idx_assessment_application (application_id),
    INDEX idx_assessment_candidate (candidate_user_id),
    INDEX idx_assessment_email (invited_email),
    INDEX idx_assessment_type (assessment_type),
    INDEX idx_assessment_status (status),
    CONSTRAINT fk_assessments_job FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE SET NULL,
    CONSTRAINT fk_assessments_application FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE SET NULL,
    CONSTRAINT fk_assessments_candidate FOREIGN KEY (candidate_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS interviews (
    id INT AUTO_INCREMENT PRIMARY KEY,
    assessment_id INT NULL,
    interview_type ENUM('live', 'ai', 'practice') NOT NULL,
    room_id VARCHAR(100) UNIQUE,
    session_id VARCHAR(100),
    candidate_user_id INT NULL,
    interviewer_user_id INT NULL,
    status ENUM('scheduled', 'waiting', 'active', 'completed', 'cancelled', 'no_show') NOT NULL DEFAULT 'scheduled',
    scheduled_at TIMESTAMP NULL,
    started_at TIMESTAMP NULL,
    ended_at TIMESTAMP NULL,
    duration_seconds INT,
    meeting_url VARCHAR(500),
    recording_url VARCHAR(500),
    transcript TEXT,
    notes TEXT,
    rating INT,
    feedback TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_interview_assessment (assessment_id),
    INDEX idx_interview_room (room_id),
    INDEX idx_interview_candidate (candidate_user_id),
    INDEX idx_interview_interviewer (interviewer_user_id),
    INDEX idx_interview_status (status),
    INDEX idx_interview_type (interview_type),
    CONSTRAINT fk_interviews_assessment FOREIGN KEY (assessment_id) REFERENCES assessments(id) ON DELETE SET NULL,
    CONSTRAINT fk_interviews_candidate FOREIGN KEY (candidate_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_interviews_interviewer FOREIGN KEY (interviewer_user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- ===================================================================
-- CODING PRACTICE & PROBLEMS
-- ===================================================================

CREATE TABLE IF NOT EXISTS coding_sessions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL,
    session_type ENUM('practice', 'assessment', 'interview') NOT NULL,
    assessment_id INT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP NULL,
    duration_seconds INT,
    status ENUM('active', 'completed', 'abandoned') NOT NULL DEFAULT 'active',
    INDEX idx_session_user (user_id),
    INDEX idx_session_assessment (assessment_id),
    INDEX idx_session_type (session_type),
    CONSTRAINT fk_coding_session_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_coding_session_assessment FOREIGN KEY (assessment_id) REFERENCES assessments(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS coding_problems (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    difficulty ENUM('Easy', 'Medium', 'Hard') NOT NULL,
    category VARCHAR(100),
    topics JSON,
    starter_code_js TEXT,
    starter_code_python TEXT,
    starter_code_java TEXT,
    starter_code_cpp TEXT,
    test_cases JSON,
    constraints TEXT,
    hints JSON,
    solution_approach TEXT,
    time_complexity VARCHAR(100),
    space_complexity VARCHAR(100),
    created_by_ai BOOLEAN DEFAULT FALSE,
    is_public BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_problem_difficulty (difficulty),
    INDEX idx_problem_category (category),
    INDEX idx_problem_public (is_public)
);

CREATE TABLE IF NOT EXISTS coding_submissions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    session_id INT NULL,
    problem_id INT NULL,
    user_id INT NULL,
    language VARCHAR(50) NOT NULL,
    code TEXT NOT NULL,
    status ENUM('pending', 'running', 'accepted', 'wrong_answer', 'runtime_error', 'time_limit', 'memory_limit', 'compilation_error') NOT NULL,
    execution_time_ms INT,
    memory_used_kb INT,
    test_cases_passed INT DEFAULT 0,
    test_cases_total INT DEFAULT 0,
    output TEXT,
    error_message TEXT,
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_submission_session (session_id),
    INDEX idx_submission_problem (problem_id),
    INDEX idx_submission_user (user_id),
    INDEX idx_submission_status (status),
    CONSTRAINT fk_submission_session FOREIGN KEY (session_id) REFERENCES coding_sessions(id) ON DELETE SET NULL,
    CONSTRAINT fk_submission_problem FOREIGN KEY (problem_id) REFERENCES coding_problems(id) ON DELETE SET NULL,
    CONSTRAINT fk_submission_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- ===================================================================
-- PROCTORING & SECURITY
-- ===================================================================

CREATE TABLE IF NOT EXISTS proctor_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL,
    assessment_id INT NULL,
    interview_id INT NULL,
    session_id INT NULL,
    type ENUM('face_detection', 'tab_switch', 'multiple_faces', 'no_face', 'voice_detection', 'screen_share', 'violation', 'warning', 'info') NOT NULL,
    severity ENUM('low', 'medium', 'high', 'critical') DEFAULT 'low',
    message TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    payload_json JSON,
    screenshot_url VARCHAR(500),
    INDEX idx_proctor_user (user_id),
    INDEX idx_proctor_assessment (assessment_id),
    INDEX idx_proctor_interview (interview_id),
    INDEX idx_proctor_session (session_id),
    INDEX idx_proctor_type (type),
    INDEX idx_proctor_severity (severity),
    INDEX idx_proctor_timestamp (timestamp),
    CONSTRAINT fk_proctor_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_proctor_assessment FOREIGN KEY (assessment_id) REFERENCES assessments(id) ON DELETE SET NULL,
    CONSTRAINT fk_proctor_interview FOREIGN KEY (interview_id) REFERENCES interviews(id) ON DELETE SET NULL,
    CONSTRAINT fk_proctor_session FOREIGN KEY (session_id) REFERENCES coding_sessions(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS ai_detection_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL,
    assessment_id INT NULL,
    interview_id INT NULL,
    text_analyzed TEXT NOT NULL,
    ai_probability DECIMAL(5,4),
    is_ai_generated BOOLEAN DEFAULT FALSE,
    model_used VARCHAR(100),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ai_detection_user (user_id),
    INDEX idx_ai_detection_assessment (assessment_id),
    INDEX idx_ai_detection_interview (interview_id),
    CONSTRAINT fk_ai_detection_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_ai_detection_assessment FOREIGN KEY (assessment_id) REFERENCES assessments(id) ON DELETE SET NULL,
    CONSTRAINT fk_ai_detection_interview FOREIGN KEY (interview_id) REFERENCES interviews(id) ON DELETE SET NULL
);

-- ===================================================================
-- REPORTS & ANALYTICS
-- ===================================================================

CREATE TABLE IF NOT EXISTS candidate_reports (
    id INT AUTO_INCREMENT PRIMARY KEY,
    candidate_user_id INT NULL,
    assessment_id INT NULL,
    interview_id INT NULL,
    overall_score DECIMAL(5,2),
    technical_score DECIMAL(5,2),
    communication_score DECIMAL(5,2),
    problem_solving_score DECIMAL(5,2),
    code_quality_score DECIMAL(5,2),
    strengths JSON,
    weaknesses JSON,
    recommendations TEXT,
    report_json JSON NOT NULL,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_report_candidate (candidate_user_id),
    INDEX idx_report_assessment (assessment_id),
    INDEX idx_report_interview (interview_id),
    CONSTRAINT fk_reports_candidate FOREIGN KEY (candidate_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_reports_assessment FOREIGN KEY (assessment_id) REFERENCES assessments(id) ON DELETE SET NULL,
    CONSTRAINT fk_reports_interview FOREIGN KEY (interview_id) REFERENCES interviews(id) ON DELETE SET NULL
);

-- ===================================================================
-- AI CHAT & ASSISTANCE
-- ===================================================================

CREATE TABLE IF NOT EXISTS axiom_chats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL,
    title VARCHAR(255) DEFAULT 'New Chat',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_chat_user (user_id),
    INDEX idx_chat_activity (last_activity),
    CONSTRAINT fk_chat_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS axiom_messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    chat_id INT NOT NULL,
    role ENUM('user', 'assistant', 'system') NOT NULL,
    content TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadata_json JSON,
    INDEX idx_message_chat (chat_id),
    INDEX idx_message_timestamp (timestamp),
    CONSTRAINT fk_message_chat FOREIGN KEY (chat_id) REFERENCES axiom_chats(id) ON DELETE CASCADE
);

-- ===================================================================
-- QUESTION BANKS
-- ===================================================================

CREATE TABLE IF NOT EXISTS questions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type ENUM('coding', 'mcq', 'theoretical', 'behavioral', 'system_design') NOT NULL,
    difficulty ENUM('Easy', 'Medium', 'Hard') NOT NULL,
    category VARCHAR(100),
    question_text TEXT NOT NULL,
    options JSON,
    correct_answer TEXT,
    explanation TEXT,
    tags JSON,
    created_by_user_id INT NULL,
    is_public BOOLEAN DEFAULT TRUE,
    usage_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_question_type (type),
    INDEX idx_question_difficulty (difficulty),
    INDEX idx_question_category (category),
    INDEX idx_question_public (is_public),
    CONSTRAINT fk_question_creator FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- ===================================================================
-- NOTIFICATIONS & ACTIVITY
-- ===================================================================

CREATE TABLE IF NOT EXISTS notifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    type ENUM('interview_scheduled', 'assessment_reminder', 'result_available', 'application_update', 'system') NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    link VARCHAR(500),
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_notification_user (user_id),
    INDEX idx_notification_read (is_read),
    INDEX idx_notification_created (created_at),
    CONSTRAINT fk_notification_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS activity_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50),
    entity_id INT,
    description TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_activity_user (user_id),
    INDEX idx_activity_action (action),
    INDEX idx_activity_entity (entity_type, entity_id),
    INDEX idx_activity_created (created_at),
    CONSTRAINT fk_activity_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- ===================================================================
-- SYSTEM CONFIGURATION
-- ===================================================================

CREATE TABLE IF NOT EXISTS system_config (
    id INT AUTO_INCREMENT PRIMARY KEY,
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value TEXT,
    description TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_config_key (config_key)
);

-- Insert default configurations
INSERT INTO system_config (config_key, config_value, description) VALUES
('platform_name', 'Interview & Assessment Platform', 'Platform display name'),
('max_interview_duration', '120', 'Maximum interview duration in minutes'),
('max_assessment_duration', '180', 'Maximum assessment duration in minutes'),
('enable_proctoring', 'true', 'Enable proctoring features'),
('enable_ai_detection', 'true', 'Enable AI content detection'),
('require_face_verification', 'false', 'Require face verification for assessments')
ON DUPLICATE KEY UPDATE config_key=config_key;

-- ===================================================================
-- VIEWS FOR COMMON QUERIES
-- ===================================================================

CREATE OR REPLACE VIEW v_active_assessments AS
SELECT 
    a.*,
    u.username as candidate_username,
    u.email as candidate_email,
    j.title as job_title,
    c.name as company_name
FROM assessments a
LEFT JOIN users u ON a.candidate_user_id = u.id
LEFT JOIN jobs j ON a.job_id = j.id
LEFT JOIN companies c ON j.company_id = c.id
WHERE a.status IN ('pending', 'in_progress');

CREATE OR REPLACE VIEW v_user_statistics AS
SELECT 
    u.id,
    u.username,
    u.email,
    u.role,
    COUNT(DISTINCT app.id) as total_applications,
    COUNT(DISTINCT ass.id) as total_assessments,
    COUNT(DISTINCT i.id) as total_interviews,
    COUNT(DISTINCT cs.id) as total_coding_sessions,
    AVG(ass.score) as average_score
FROM users u
LEFT JOIN applications app ON u.id = app.candidate_user_id
LEFT JOIN assessments ass ON u.id = ass.candidate_user_id
LEFT JOIN interviews i ON u.id = i.candidate_user_id
LEFT JOIN coding_sessions cs ON u.id = cs.user_id
GROUP BY u.id, u.username, u.email, u.role;

-- ===================================================================
-- TRIGGERS
-- ===================================================================

DELIMITER //

CREATE TRIGGER after_assessment_complete
AFTER UPDATE ON assessments
FOR EACH ROW
BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        INSERT INTO notifications (user_id, type, title, message, link)
        VALUES (
            NEW.candidate_user_id,
            'result_available',
            'Assessment Completed',
            'Your assessment has been completed. Results are being processed.',
            CONCAT('/assessments/', NEW.id, '/report')
        );
    END IF;
END//

CREATE TRIGGER after_interview_schedule
AFTER INSERT ON interviews
FOR EACH ROW
BEGIN
    IF NEW.candidate_user_id IS NOT NULL THEN
        INSERT INTO notifications (user_id, type, title, message, link)
        VALUES (
            NEW.candidate_user_id,
            'interview_scheduled',
            'Interview Scheduled',
            CONCAT('Your interview has been scheduled for ', NEW.scheduled_at),
            CONCAT('/interviews/', NEW.room_id)
        );
    END IF;
END//

DELIMITER ;


SELECT 'Database schema created successfully!' AS Status;
SELECT 'Tables created:', COUNT(*) FROM information_schema.tables WHERE table_schema = 'interview_platform_db' AS TableCount;
