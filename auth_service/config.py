"""
Python Authentication Service Configuration
Handles all authentication, face recognition, and user management
"""
import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    """Base configuration"""
    # Server
    PORT = int(os.getenv('PORT', 5000))
    DEBUG = os.getenv('FLASK_ENV', 'production') != 'production'
    SECRET_KEY = os.getenv('SECRET_KEY', 'your-secret-key-change-in-production')
    
    # Database
    DB_HOST = os.getenv('DB_HOST', 'localhost')
    DB_PORT = int(os.getenv('DB_PORT', 3306))
    DB_USER = os.getenv('DB_USER', 'root')
    DB_PASSWORD = os.getenv('DB_PASSWORD', '')
    DB_NAME = os.getenv('DB_NAME', 'interview_platform_unified')
    
    # Face Recognition
    PINECONE_API_KEY = os.getenv('PINECONE_API_KEY')
    PINECONE_INDEX = os.getenv('PINECONE_INDEX', 'face-auth-index')
    PINECONE_HOST = os.getenv('PINECONE_HOST')
    FACE_MIN_SCORE = float(os.getenv('FACE_MIN_SCORE', 0.35))
    FACE_RATIO_THRESHOLD = float(os.getenv('FACE_RATIO_THRESHOLD', 0.18))
    FACE_ADAPTIVE_LR = float(os.getenv('FACE_ADAPTIVE_LR', 0.05))
    FACE_DEVICE = os.getenv('FACE_DEVICE', 'cpu')
    
    # Email (OTP)
    MAIL_SERVER = os.getenv('MAIL_SERVER', 'smtp.gmail.com')
    MAIL_PORT = int(os.getenv('MAIL_PORT', 587))
    MAIL_USE_TLS = os.getenv('MAIL_USE_TLS', 'true').lower() == 'true'
    MAIL_USERNAME = os.getenv('MAIL_USERNAME', '')
    MAIL_PASSWORD = os.getenv('MAIL_PASSWORD', '')
    MAIL_DEFAULT_SENDER = os.getenv('MAIL_DEFAULT_SENDER', 'noreply@interview-platform.com')
    
    # JWT
    JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY', 'jwt-secret-change-in-production')
    JWT_ALGORITHM = 'HS256'
    JWT_EXPIRY_HOURS = int(os.getenv('JWT_EXPIRY_HOURS', 24))
    
    # CORS
    FRONTEND_ORIGIN = os.getenv('FRONTEND_ORIGIN', 'http://localhost:5173')
    NODE_SERVICE_URL = os.getenv('NODE_SERVICE_URL', 'http://localhost:5001')
    ALLOWED_ORIGINS = os.getenv('ALLOWED_ORIGINS', f'{FRONTEND_ORIGIN},{NODE_SERVICE_URL}')
    
    # Session
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SECURE = os.getenv('COOKIE_SECURE', 'false').lower() == 'true'
    SESSION_COOKIE_SAMESITE = os.getenv('COOKIE_SAMESITE', 'Lax')
    
    # Service Integration
    AUTH_SERVICE_SECRET = os.getenv('AUTH_SERVICE_SECRET', 'shared-secret-change-in-production')
    
    @staticmethod
    def get_db_config():
        """Get database configuration dict"""
        return {
            'host': Config.DB_HOST,
            'port': Config.DB_PORT,
            'user': Config.DB_USER,
            'password': Config.DB_PASSWORD,
            'database': Config.DB_NAME,
            'autocommit': False
        }
    
    @staticmethod
    def get_allowed_origins_list():
        """Get list of allowed CORS origins"""
        return [o.strip() for o in Config.ALLOWED_ORIGINS.split(',') if o.strip()]
    
    @staticmethod
    def validate():
        """Validate critical configuration"""
        errors = []
        
        if not Config.PINECONE_API_KEY:
            errors.append('PINECONE_API_KEY is required')
        
        if not Config.MAIL_USERNAME or not Config.MAIL_PASSWORD:
            errors.append('MAIL_USERNAME and MAIL_PASSWORD are required for OTP')
        
        if Config.JWT_SECRET_KEY == 'jwt-secret-change-in-production':
            errors.append('JWT_SECRET_KEY must be changed in production')
        
        if Config.SECRET_KEY == 'your-secret-key-change-in-production':
            errors.append('SECRET_KEY must be changed in production')
        
        return errors

config = Config()
