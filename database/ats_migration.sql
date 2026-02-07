-- ===================================================================
-- ATS & Results Storage Migration
-- Run this to add ATS scoring and extended results tables
-- ===================================================================

USE interview_platform_db;

-- ===================================================================
-- CANDIDATE RESUMES (Parsed & Structured)
-- ===================================================================

CREATE TABLE IF NOT EXISTS candidate_resumes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    filename VARCHAR(255),
    original_name VARCHAR(255),
    parsed_data_json JSON,
    extracted_skills_json JSON,
    experience_years INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_resume_user (user_id),
    INDEX idx_resume_experience (experience_years),
    CONSTRAINT fk_resume_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ===================================================================
-- ATS SCORES (Resume-Job Match Scores)
-- ===================================================================

CREATE TABLE IF NOT EXISTS ats_scores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    job_id INT NOT NULL,
    overall_score INT DEFAULT 0,
    breakdown_json JSON,
    matched_skills_json JSON,
    missing_skills_json JSON,
    recommendations_json JSON,
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_ats_user_job (user_id, job_id),
    INDEX idx_ats_user (user_id),
    INDEX idx_ats_job (job_id),
    INDEX idx_ats_score (overall_score),
    CONSTRAINT fk_ats_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_ats_job FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE
);

-- ===================================================================
-- ASSESSMENT RESULTS (Detailed)
-- ===================================================================

CREATE TABLE IF NOT EXISTS assessment_results (
    id INT AUTO_INCREMENT PRIMARY KEY,
    assessment_id INT,
    candidate_user_id INT,
    job_id INT,
    score DECIMAL(10,2) DEFAULT 0,
    max_score DECIMAL(10,2) DEFAULT 100,
    percentage DECIMAL(5,2) DEFAULT 0,
    time_taken_seconds INT DEFAULT 0,
    answers_json JSON,
    proctoring_summary_json JSON,
    ai_detection_summary_json JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ar_assessment (assessment_id),
    INDEX idx_ar_candidate (candidate_user_id),
    INDEX idx_ar_job (job_id),
    INDEX idx_ar_score (percentage),
    CONSTRAINT fk_ar_assessment FOREIGN KEY (assessment_id) REFERENCES assessments(id) ON DELETE SET NULL,
    CONSTRAINT fk_ar_candidate FOREIGN KEY (candidate_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_ar_job FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE SET NULL
);

-- ===================================================================
-- INTERVIEW RESULTS (Detailed Evaluations)
-- ===================================================================

CREATE TABLE IF NOT EXISTS interview_results (
    id INT AUTO_INCREMENT PRIMARY KEY,
    interview_id INT,
    candidate_user_id INT,
    interviewer_user_id INT,
    overall_rating DECIMAL(3,1) DEFAULT 0,
    technical_rating DECIMAL(3,1) DEFAULT 0,
    communication_rating DECIMAL(3,1) DEFAULT 0,
    problem_solving_rating DECIMAL(3,1) DEFAULT 0,
    cultural_fit_rating DECIMAL(3,1) DEFAULT 0,
    feedback TEXT,
    strengths_json JSON,
    weaknesses_json JSON,
    recommendation ENUM('strong_hire', 'hire', 'maybe', 'no_hire', 'strong_no_hire'),
    ai_analysis_json JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ir_interview (interview_id),
    INDEX idx_ir_candidate (candidate_user_id),
    INDEX idx_ir_interviewer (interviewer_user_id),
    INDEX idx_ir_recommendation (recommendation),
    CONSTRAINT fk_ir_interview FOREIGN KEY (interview_id) REFERENCES interviews(id) ON DELETE SET NULL,
    CONSTRAINT fk_ir_candidate FOREIGN KEY (candidate_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_ir_interviewer FOREIGN KEY (interviewer_user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- ===================================================================
-- CODE ANALYSIS (AI Feedback on Submissions)
-- ===================================================================

CREATE TABLE IF NOT EXISTS code_analysis (
    id INT AUTO_INCREMENT PRIMARY KEY,
    submission_id INT,
    user_id INT,
    analysis_type ENUM('ai_review', 'auto_grade', 'style_check', 'security_scan') DEFAULT 'ai_review',
    feedback_json JSON,
    score DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ca_submission (submission_id),
    INDEX idx_ca_user (user_id),
    CONSTRAINT fk_ca_submission FOREIGN KEY (submission_id) REFERENCES coding_submissions(id) ON DELETE CASCADE,
    CONSTRAINT fk_ca_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- ===================================================================
-- UPDATE EXISTING TABLES (Add missing columns)
-- ===================================================================

-- Add job_id to candidate_reports if not exists
ALTER TABLE candidate_reports ADD COLUMN IF NOT EXISTS job_id INT NULL AFTER interview_id;
ALTER TABLE candidate_reports ADD INDEX IF NOT EXISTS idx_report_job (job_id);
ALTER TABLE candidate_reports ADD CONSTRAINT IF NOT EXISTS fk_reports_job 
    FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE SET NULL;

-- Add application_id to assessments if not exists
ALTER TABLE assessments ADD COLUMN IF NOT EXISTS application_id INT NULL AFTER job_id;
ALTER TABLE assessments ADD INDEX IF NOT EXISTS idx_assessment_application (application_id);
ALTER TABLE assessments ADD CONSTRAINT IF NOT EXISTS fk_assessments_application_new 
    FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE SET NULL;

-- Add experience_required to jobs if not exists
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS experience_required INT DEFAULT 0 AFTER job_type;

-- Add profile fields to users if not exists
ALTER TABLE users ADD COLUMN IF NOT EXISTS location VARCHAR(255) AFTER github_url;

-- ===================================================================
-- VIEWS FOR HR DASHBOARD
-- ===================================================================

CREATE OR REPLACE VIEW v_candidate_pipeline AS
SELECT 
    app.id as application_id,
    app.status,
    app.applied_at,
    u.id as user_id,
    u.username,
    u.email,
    u.experience_years,
    cr.extracted_skills_json as skills,
    ats.overall_score as ats_score,
    ats.breakdown_json as ats_breakdown,
    j.id as job_id,
    j.title as job_title,
    c.id as company_id,
    c.name as company_name
FROM applications app
JOIN users u ON app.candidate_user_id = u.id
JOIN jobs j ON app.job_id = j.id
LEFT JOIN companies c ON j.company_id = c.id
LEFT JOIN candidate_resumes cr ON u.id = cr.user_id
LEFT JOIN ats_scores ats ON u.id = ats.user_id AND ats.job_id = j.id
ORDER BY app.applied_at DESC;

CREATE OR REPLACE VIEW v_job_analytics AS
SELECT 
    j.id as job_id,
    j.title,
    j.status,
    j.created_at,
    c.name as company_name,
    COUNT(DISTINCT app.id) as total_applications,
    COUNT(DISTINCT CASE WHEN app.status = 'screening' THEN app.id END) as in_screening,
    COUNT(DISTINCT CASE WHEN app.status = 'interview_scheduled' THEN app.id END) as in_interview,
    COUNT(DISTINCT CASE WHEN app.status = 'accepted' THEN app.id END) as accepted,
    COUNT(DISTINCT CASE WHEN app.status = 'rejected' THEN app.id END) as rejected,
    AVG(ats.overall_score) as avg_ats_score,
    MAX(ats.overall_score) as highest_ats_score
FROM jobs j
LEFT JOIN companies c ON j.company_id = c.id
LEFT JOIN applications app ON j.id = app.job_id
LEFT JOIN ats_scores ats ON j.id = ats.job_id
GROUP BY j.id, j.title, j.status, j.created_at, c.name;

-- ===================================================================
-- INDEXES FOR PERFORMANCE
-- ===================================================================

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_app_job_status ON applications(job_id, status);
CREATE INDEX IF NOT EXISTS idx_ats_job_score ON ats_scores(job_id, overall_score DESC);
CREATE INDEX IF NOT EXISTS idx_ar_job_score ON assessment_results(job_id, percentage DESC);

-- Full-text search on resume skills (if MySQL 5.6+)
-- ALTER TABLE candidate_resumes ADD FULLTEXT INDEX ft_skills (extracted_skills_json);

SELECT 'ATS migration completed successfully!' AS Status;
