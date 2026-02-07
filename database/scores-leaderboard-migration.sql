-- ===================================================================
-- SCORES, LEADERBOARD & USER SKILLS MIGRATION
-- Track user performance across contests, practice, and interviews
-- ===================================================================

USE interview_platform_db;

-- ===================================================================
-- USER SKILLS TRACKING
-- ===================================================================

CREATE TABLE IF NOT EXISTS user_skills (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    skill_name VARCHAR(100) NOT NULL,
    skill_category ENUM('programming', 'framework', 'database', 'cloud', 'devops', 'soft_skills', 'domain', 'other') DEFAULT 'programming',
    proficiency_level ENUM('beginner', 'intermediate', 'advanced', 'expert') DEFAULT 'intermediate',
    years_experience INT DEFAULT 0,
    verified BOOLEAN DEFAULT FALSE,
    verified_through VARCHAR(100), -- 'assessment', 'interview', 'self_declared'
    score DECIMAL(5,2) DEFAULT 0,
    last_assessed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uq_user_skill (user_id, skill_name),
    INDEX idx_user (user_id),
    INDEX idx_skill_name (skill_name),
    INDEX idx_category (skill_category),
    INDEX idx_proficiency (proficiency_level),
    CONSTRAINT fk_skill_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- USER SCORES TRACKING
-- Store scores from different activities
-- ===================================================================

CREATE TABLE IF NOT EXISTS user_scores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    
    -- Activity Reference
    activity_type ENUM('coding_practice', 'ai_interview', 'live_interview', 'assessment', 'contest', 'challenge') NOT NULL,
    activity_id INT NULL, -- can reference coding_sessions, interviews, assessments, etc.
    
    -- Score Details
    score DECIMAL(8,2) NOT NULL,
    max_score DECIMAL(8,2) DEFAULT 100,
    percentage DECIMAL(5,2) GENERATED ALWAYS AS (CASE WHEN max_score > 0 THEN (score / max_score * 100) ELSE 0 END) STORED,
    
    -- Activity Metadata
    activity_title VARCHAR(255),
    difficulty ENUM('Easy', 'Medium', 'Hard') DEFAULT 'Medium',
    duration_seconds INT,
    problems_solved INT DEFAULT 0,
    total_problems INT DEFAULT 0,
    
    -- Skills assessed
    skills_assessed JSON,
    
    -- Timestamps
    completed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_user (user_id),
    INDEX idx_activity_type (activity_type),
    INDEX idx_completed (completed_at),
    INDEX idx_score (score DESC),
    INDEX idx_percentage (percentage DESC),
    CONSTRAINT fk_score_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- USER AGGREGATE SCORES FOR LEADERBOARD
-- Pre-calculated aggregate scores for fast leaderboard queries
-- ===================================================================

CREATE TABLE IF NOT EXISTS user_leaderboard_stats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    
    -- Overall Stats
    total_score DECIMAL(12,2) DEFAULT 0,
    total_activities INT DEFAULT 0,
    average_score DECIMAL(5,2) DEFAULT 0,
    
    -- Category Scores
    coding_score DECIMAL(10,2) DEFAULT 0,
    coding_problems_solved INT DEFAULT 0,
    interview_score DECIMAL(10,2) DEFAULT 0,
    interview_count INT DEFAULT 0,
    contest_score DECIMAL(10,2) DEFAULT 0,
    contest_count INT DEFAULT 0,
    challenge_score DECIMAL(10,2) DEFAULT 0,
    challenge_count INT DEFAULT 0,
    
    -- Ranking
    global_rank INT DEFAULT 0,
    weekly_rank INT DEFAULT 0,
    monthly_rank INT DEFAULT 0,
    
    -- Streaks
    current_streak_days INT DEFAULT 0,
    longest_streak_days INT DEFAULT 0,
    last_activity_date DATE,
    
    -- Badges & Achievements (JSON array)
    badges JSON,
    achievements JSON,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_total_score (total_score DESC),
    INDEX idx_global_rank (global_rank),
    INDEX idx_coding_score (coding_score DESC),
    INDEX idx_interview_score (interview_score DESC),
    CONSTRAINT fk_leaderboard_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- AI ANALYSIS FOR STRENGTHS & WEAKNESSES
-- ===================================================================

CREATE TABLE IF NOT EXISTS user_ai_analysis (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    
    -- Strengths & Weaknesses
    strengths JSON, -- Array of {skill, confidence, evidence}
    weaknesses JSON, -- Array of {skill, confidence, suggestions}
    
    -- Detailed Analysis
    overall_assessment TEXT,
    coding_analysis TEXT,
    interview_analysis TEXT,
    communication_analysis TEXT,
    
    -- Skill Radar Data (for visualization)
    skill_radar JSON, -- {problem_solving: 85, communication: 70, technical: 80, ...}
    
    -- Recommendations
    recommended_topics JSON, -- Topics to study
    recommended_jobs JSON, -- Job types that match profile
    improvement_plan TEXT,
    
    -- AI Confidence
    analysis_confidence DECIMAL(5,2),
    data_points_used INT DEFAULT 0,
    
    -- Timestamps
    analyzed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL, -- Analysis validity period
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_user (user_id),
    INDEX idx_analyzed (analyzed_at),
    CONSTRAINT fk_analysis_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- CONTESTS TABLE
-- ===================================================================

CREATE TABLE IF NOT EXISTS contests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    duration_minutes INT DEFAULT 120,
    
    -- Contest Configuration
    contest_type ENUM('coding', 'quiz', 'mixed') DEFAULT 'coding',
    difficulty ENUM('Easy', 'Medium', 'Hard', 'Mixed') DEFAULT 'Mixed',
    max_participants INT DEFAULT NULL,
    is_public BOOLEAN DEFAULT TRUE,
    requires_registration BOOLEAN DEFAULT TRUE,
    
    -- Scoring
    scoring_type ENUM('standard', 'time_based', 'penalty_based') DEFAULT 'standard',
    
    -- Problems (JSON array of problem IDs or embedded problems)
    problems_json JSON,
    
    -- Prizes (optional)
    prizes_json JSON,
    
    -- Status
    status ENUM('upcoming', 'active', 'ended', 'cancelled') DEFAULT 'upcoming',
    
    -- Creator
    created_by_user_id INT,
    company_id INT NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_start_time (start_time),
    INDEX idx_status (status),
    INDEX idx_public (is_public),
    INDEX idx_created_by (created_by_user_id),
    CONSTRAINT fk_contest_creator FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_contest_company FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- CONTEST REGISTRATIONS
-- ===================================================================

CREATE TABLE IF NOT EXISTS contest_registrations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    contest_id INT NOT NULL,
    user_id INT NOT NULL,
    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('registered', 'participated', 'disqualified', 'no_show') DEFAULT 'registered',
    
    UNIQUE KEY uq_contest_user (contest_id, user_id),
    INDEX idx_contest (contest_id),
    INDEX idx_user (user_id),
    CONSTRAINT fk_reg_contest FOREIGN KEY (contest_id) REFERENCES contests(id) ON DELETE CASCADE,
    CONSTRAINT fk_reg_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- CONTEST SUBMISSIONS & RESULTS
-- ===================================================================

CREATE TABLE IF NOT EXISTS contest_submissions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    contest_id INT NOT NULL,
    user_id INT NOT NULL,
    problem_id INT,
    
    -- Submission Details
    code TEXT,
    language VARCHAR(50),
    
    -- Results
    score DECIMAL(8,2) DEFAULT 0,
    time_taken_seconds INT,
    test_cases_passed INT DEFAULT 0,
    test_cases_total INT DEFAULT 0,
    status ENUM('pending', 'accepted', 'wrong_answer', 'time_limit', 'runtime_error', 'compilation_error') DEFAULT 'pending',
    
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_contest (contest_id),
    INDEX idx_user (user_id),
    INDEX idx_problem (problem_id),
    INDEX idx_score (score DESC),
    CONSTRAINT fk_csub_contest FOREIGN KEY (contest_id) REFERENCES contests(id) ON DELETE CASCADE,
    CONSTRAINT fk_csub_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- JOB SKILL REQUIREMENTS (for matching)
-- ===================================================================

CREATE TABLE IF NOT EXISTS job_skill_requirements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    job_id INT NOT NULL,
    skill_name VARCHAR(100) NOT NULL,
    is_required BOOLEAN DEFAULT TRUE,
    min_proficiency ENUM('beginner', 'intermediate', 'advanced', 'expert') DEFAULT 'intermediate',
    weight DECIMAL(3,2) DEFAULT 1.0, -- Importance weight for matching
    
    UNIQUE KEY uq_job_skill (job_id, skill_name),
    INDEX idx_job (job_id),
    INDEX idx_skill (skill_name),
    CONSTRAINT fk_jobskill_job FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- ADD SKILL MATCH SCORE TO APPLICATIONS
-- ===================================================================

ALTER TABLE applications 
ADD COLUMN IF NOT EXISTS skill_match_score DECIMAL(5,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS platform_score DECIMAL(8,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS overall_match_score DECIMAL(5,2) DEFAULT 0;

-- ===================================================================
-- END OF MIGRATION
-- ===================================================================
