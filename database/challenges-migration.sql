-- ===================================================================
-- Company Challenges & Shortlisting Tables
-- Run this migration to add challenge management features
-- ===================================================================

USE interview_platform_db;

-- ===================================================================
-- COMPANY CHALLENGES
-- ===================================================================

CREATE TABLE IF NOT EXISTS company_challenges (
    id INT AUTO_INCREMENT PRIMARY KEY,
    company_id INT NULL,
    created_by_user_id INT NULL,
    job_id INT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    difficulty ENUM('Easy', 'Medium', 'Hard') NOT NULL DEFAULT 'Medium',
    category VARCHAR(100) DEFAULT 'General',
    topics_json JSON,
    time_limit_minutes INT DEFAULT 30,
    starter_code_js TEXT,
    starter_code_python TEXT,
    starter_code_java TEXT,
    test_cases_json JSON,
    constraints TEXT,
    hints_json JSON,
    solution_approach TEXT,
    is_public BOOLEAN DEFAULT TRUE,
    status ENUM('draft', 'active', 'archived') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_challenge_company (company_id),
    INDEX idx_challenge_job (job_id),
    INDEX idx_challenge_difficulty (difficulty),
    INDEX idx_challenge_status (status),
    INDEX idx_challenge_created_by (created_by_user_id),
    CONSTRAINT fk_challenge_company FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE SET NULL,
    CONSTRAINT fk_challenge_job FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE SET NULL,
    CONSTRAINT fk_challenge_created_by FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- ===================================================================
-- CHALLENGE SUBMISSIONS
-- ===================================================================

CREATE TABLE IF NOT EXISTS challenge_submissions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    challenge_id INT NOT NULL,
    user_id INT NOT NULL,
    language VARCHAR(50) NOT NULL,
    code TEXT NOT NULL,
    execution_time_ms INT DEFAULT 0,
    memory_used_kb INT DEFAULT 0,
    test_cases_passed INT DEFAULT 0,
    test_cases_total INT DEFAULT 0,
    score INT DEFAULT 0,
    status ENUM('pending', 'running', 'accepted', 'partial', 'wrong_answer', 'runtime_error', 'time_limit', 'compilation_error') NOT NULL DEFAULT 'pending',
    error_message TEXT,
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_submission_challenge (challenge_id),
    INDEX idx_submission_user (user_id),
    INDEX idx_submission_status (status),
    INDEX idx_submission_score (score),
    INDEX idx_submission_time (submitted_at),
    CONSTRAINT fk_challenge_submission_challenge FOREIGN KEY (challenge_id) REFERENCES company_challenges(id) ON DELETE CASCADE,
    CONSTRAINT fk_challenge_submission_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ===================================================================
-- CANDIDATE SHORTLIST
-- ===================================================================

CREATE TABLE IF NOT EXISTS candidate_shortlist (
    id INT AUTO_INCREMENT PRIMARY KEY,
    company_id INT NULL,
    job_id INT NULL,
    user_id INT NOT NULL,
    notes TEXT,
    status ENUM('active', 'contacted', 'interviewed', 'hired', 'rejected', 'removed') DEFAULT 'active',
    shortlisted_by_user_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_shortlist_job_user (job_id, user_id),
    INDEX idx_shortlist_company (company_id),
    INDEX idx_shortlist_job (job_id),
    INDEX idx_shortlist_user (user_id),
    INDEX idx_shortlist_status (status),
    CONSTRAINT fk_shortlist_company FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE SET NULL,
    CONSTRAINT fk_shortlist_job FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE SET NULL,
    CONSTRAINT fk_shortlist_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ===================================================================
-- CHALLENGE INVITES
-- ===================================================================

CREATE TABLE IF NOT EXISTS challenge_invites (
    id INT AUTO_INCREMENT PRIMARY KEY,
    challenge_id INT NOT NULL,
    invited_email VARCHAR(255) NOT NULL,
    invited_user_id INT NULL,
    invite_code VARCHAR(100) UNIQUE,
    status ENUM('pending', 'accepted', 'expired', 'completed') DEFAULT 'pending',
    expires_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_invite_challenge (challenge_id),
    INDEX idx_invite_email (invited_email),
    INDEX idx_invite_user (invited_user_id),
    INDEX idx_invite_code (invite_code),
    INDEX idx_invite_status (status),
    CONSTRAINT fk_invite_challenge FOREIGN KEY (challenge_id) REFERENCES company_challenges(id) ON DELETE CASCADE,
    CONSTRAINT fk_invite_user FOREIGN KEY (invited_user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- ===================================================================
-- VIEWS FOR LEADERBOARD & ANALYTICS
-- ===================================================================

CREATE OR REPLACE VIEW v_challenge_leaderboard AS
SELECT 
    ch.id as challenge_id,
    ch.title as challenge_title,
    ch.company_id,
    u.id as user_id,
    u.username,
    u.email,
    MAX(cs.score) as best_score,
    MIN(cs.execution_time_ms) as best_time,
    COUNT(cs.id) as attempt_count,
    MAX(cs.submitted_at) as last_submission
FROM challenge_submissions cs
JOIN company_challenges ch ON cs.challenge_id = ch.id
JOIN users u ON cs.user_id = u.id
GROUP BY ch.id, ch.title, ch.company_id, u.id, u.username, u.email;

CREATE OR REPLACE VIEW v_company_challenge_stats AS
SELECT 
    ch.company_id,
    c.name as company_name,
    COUNT(DISTINCT ch.id) as total_challenges,
    COUNT(DISTINCT cs.user_id) as total_participants,
    COUNT(cs.id) as total_submissions,
    ROUND(AVG(cs.score), 2) as avg_score,
    SUM(CASE WHEN cs.status = 'accepted' THEN 1 ELSE 0 END) as accepted_submissions
FROM company_challenges ch
LEFT JOIN companies c ON ch.company_id = c.id
LEFT JOIN challenge_submissions cs ON ch.id = cs.challenge_id
WHERE ch.status = 'active'
GROUP BY ch.company_id, c.name;

SELECT 'Challenge tables created successfully!' AS Status;
