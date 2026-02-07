"""
Database utilities for Python Authentication Service
Handles MySQL connection and queries
"""
import mysql.connector
from mysql.connector import pooling, Error
from config import config
import logging

logger = logging.getLogger(__name__)

# Connection pool
connection_pool = None

def init_database():
    """Initialize MySQL database connection pool"""
    global connection_pool
    try:
        connection_pool = mysql.connector.pooling.MySQLConnectionPool(
            pool_name="auth_pool",
            pool_size=10,
            pool_reset_session=True,
            **config.get_db_config()
        )
        logger.info("✅ MySQL database connected successfully (Python Auth Service)")
        return True
    except Error as err:
        logger.error(f"❌ MySQL connection error: {err}")
        return False

def get_connection():
    """Get a database connection from the pool"""
    if connection_pool:
        try:
            return connection_pool.get_connection()
        except Error as err:
            logger.error(f"Error getting connection from pool: {err}")
            return None
    return None

def execute_query(query, params=None, fetch=True, fetch_one=False):
    """
    Execute a database query
    
    Args:
        query: SQL query string
        params: Query parameters tuple
        fetch: Whether to fetch results (SELECT queries)
        fetch_one: Fetch only one row
        
    Returns:
        List of dicts for SELECT, insert_id for INSERT, affected rows for UPDATE/DELETE
    """
    conn = None
    cursor = None
    try:
        conn = get_connection()
        if not conn:
            raise Exception("Database connection not available")
        
        cursor = conn.cursor(dictionary=True)
        cursor.execute(query, params or ())
        
        if fetch:
            result = cursor.fetchone() if fetch_one else cursor.fetchall()
        else:
            result = cursor.lastrowid if 'INSERT' in query.upper() else cursor.rowcount
            conn.commit()
        
        return result
    except Error as e:
        if conn:
            conn.rollback()
        logger.error(f"Database query error: {e}")
        logger.error(f"Query: {query}")
        logger.error(f"Params: {params}")
        raise e
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

class AuthDB:
    """Database operations for authentication"""
    
    @staticmethod
    def find_user_by_email(email):
        """Find user by email"""
        query = "SELECT * FROM users WHERE email = %s LIMIT 1"
        result = execute_query(query, (email,), fetch=True, fetch_one=True)
        return result
    
    @staticmethod
    def find_user_by_username(username):
        """Find user by username"""
        query = "SELECT * FROM users WHERE username = %s LIMIT 1"
        result = execute_query(query, (username,), fetch=True, fetch_one=True)
        return result
    
    @staticmethod
    def find_user_by_id(user_id):
        """Find user by ID"""
        query = "SELECT * FROM users WHERE id = %s LIMIT 1"
        result = execute_query(query, (user_id,), fetch=True, fetch_one=True)
        return result
    
    @staticmethod
    def create_user(username, email, password, **kwargs):
        """Create a new user"""
        full_name = kwargs.get('full_name')
        phone = kwargs.get('phone')
        role = kwargs.get('role', 'candidate')
        face_embedding = kwargs.get('face_embedding')
        
        query = """
            INSERT INTO users (username, email, password, full_name, phone, role, face_embedding, is_verified, email_verified) 
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        params = (username, email, password, full_name, phone, role, face_embedding, False, False)
        user_id = execute_query(query, params, fetch=False)
        return user_id
    
    @staticmethod
    def update_user_face_embedding(user_id, embedding):
        """Update user's face embedding"""
        query = "UPDATE users SET face_embedding = %s WHERE id = %s"
        execute_query(query, (embedding, user_id), fetch=False)
    
    @staticmethod
    def update_user_password(user_id, hashed_password):
        """Update user's password"""
        query = "UPDATE users SET password = %s WHERE id = %s"
        execute_query(query, (hashed_password, user_id), fetch=False)
    
    @staticmethod
    def update_user_password_by_email(email, hashed_password):
        """Update user's password by email"""
        query = "UPDATE users SET password = %s WHERE email = %s"
        rows = execute_query(query, (hashed_password, email), fetch=False)
        return rows > 0
    
    @staticmethod
    def update_last_login(user_id):
        """Update user's last login timestamp"""
        query = "UPDATE users SET last_login = NOW() WHERE id = %s"
        execute_query(query, (user_id,), fetch=False)
    
    @staticmethod
    def verify_user_email(user_id):
        """Mark user's email as verified"""
        query = "UPDATE users SET email_verified = TRUE, is_verified = TRUE WHERE id = %s"
        execute_query(query, (user_id,), fetch=False)
    
    # OTP Operations
    @staticmethod
    def create_otp(email, otp, purpose, expires_at):
        """Store OTP code"""
        query = """
            INSERT INTO otp_codes (email, otp, purpose, expires_at) 
            VALUES (%s, %s, %s, %s)
        """
        otp_id = execute_query(query, (email, otp, purpose, expires_at), fetch=False)
        return otp_id
    
    @staticmethod
    def find_valid_otp(email, otp, purpose):
        """Find valid unused OTP"""
        query = """
            SELECT id, expires_at FROM otp_codes
            WHERE email = %s AND otp = %s AND purpose = %s AND used = FALSE
            ORDER BY created_at DESC LIMIT 1
        """
        result = execute_query(query, (email, otp, purpose), fetch=True, fetch_one=True)
        return result
    
    @staticmethod
    def mark_otp_used(otp_id):
        """Mark OTP as used"""
        query = "UPDATE otp_codes SET used = TRUE WHERE id = %s"
        execute_query(query, (otp_id,), fetch=False)
    
    # Session Operations
    @staticmethod
    def create_session(user_id, session_token, expires_at, **kwargs):
        """Create user session"""
        refresh_token = kwargs.get('refresh_token')
        device_info = kwargs.get('device_info')
        ip_address = kwargs.get('ip_address')
        user_agent = kwargs.get('user_agent')
        
        query = """
            INSERT INTO user_sessions 
            (user_id, session_token, refresh_token, device_info, ip_address, user_agent, expires_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        params = (user_id, session_token, refresh_token, device_info, ip_address, user_agent, expires_at)
        session_id = execute_query(query, params, fetch=False)
        return session_id
    
    @staticmethod
    def find_session_by_token(session_token):
        """Find active session by token"""
        query = """
            SELECT * FROM user_sessions 
            WHERE session_token = %s AND is_active = TRUE AND expires_at > NOW()
            LIMIT 1
        """
        result = execute_query(query, (session_token,), fetch=True, fetch_one=True)
        return result
    
    @staticmethod
    def deactivate_session(session_token):
        """Deactivate a session"""
        query = "UPDATE user_sessions SET is_active = FALSE WHERE session_token = %s"
        execute_query(query, (session_token,), fetch=False)
    
    @staticmethod
    def deactivate_user_sessions(user_id):
        """Deactivate all sessions for a user"""
        query = "UPDATE user_sessions SET is_active = FALSE WHERE user_id = %s"
        execute_query(query, (user_id,), fetch=False)
    
    @staticmethod
    def cleanup_expired_sessions():
        """Remove expired sessions"""
        query = "DELETE FROM user_sessions WHERE expires_at < NOW()"
        execute_query(query, None, fetch=False)
    
    @staticmethod
    def cleanup_expired_otps():
        """Remove expired OTPs"""
        query = "DELETE FROM otp_codes WHERE expires_at < NOW()"
        execute_query(query, None, fetch=False)
