"""
JWT (JSON Web Token) utilities for authentication
Handles token generation, validation, and decoding
"""
import jwt
import json
from datetime import datetime, timedelta
from config import config
import logging

logger = logging.getLogger(__name__)

def generate_token(user, expiry_hours=None):
    """
    Generate JWT token for user
    
    Args:
        user: User dict from database
        expiry_hours: Token expiry in hours (default from config)
        
    Returns:
        JWT token string
    """
    if expiry_hours is None:
        expiry_hours = config.JWT_EXPIRY_HOURS
    
    expires_at = datetime.utcnow() + timedelta(hours=expiry_hours)
    
    payload = {
        'user_id': user['id'],
        'username': user['username'],
        'email': user['email'],
        'role': user['role'],
        'exp': expires_at,
        'iat': datetime.utcnow()
    }
    
    token = jwt.encode(
        payload,
        config.JWT_SECRET_KEY,
        algorithm=config.JWT_ALGORITHM
    )
    
    return token

def decode_token(token):
    """
    Decode and validate JWT token
    
    Args:
        token: JWT token string
        
    Returns:
        Decoded payload dict or None if invalid
    """
    try:
        payload = jwt.decode(
            token,
            config.JWT_SECRET_KEY,
            algorithms=[config.JWT_ALGORITHM]
        )
        return payload
    except jwt.ExpiredSignatureError:
        logger.warning("Token expired")
        return None
    except jwt.InvalidTokenError as e:
        logger.warning(f"Invalid token: {e}")
        return None

def verify_token(token):
    """
    Verify token validity
    
    Args:
        token: JWT token string
        
    Returns:
        tuple: (is_valid, payload_or_error)
    """
    payload = decode_token(token)
    if payload:
        return True, payload
    return False, "Invalid or expired token"

def extract_token_from_header(auth_header):
    """
    Extract token from Authorization header
    
    Args:
        auth_header: Authorization header value ("Bearer <token>")
        
    Returns:
        Token string or None
    """
    if not auth_header:
        return None
    
    parts = auth_header.split()
    if len(parts) != 2 or parts[0].lower() != 'bearer':
        return None
    
    return parts[1]

def create_user_response(user, include_token=False):
    """
    Create standardized user response object
    
    Args:
        user: User dict from database
        include_token: Whether to generate and include JWT token
        
    Returns:
        User response dict
    """
    response = {
        'id': user['id'],
        'username': user['username'],
        'email': user['email'],
        'role': user['role'],
        'full_name': user.get('full_name'),
        'phone': user.get('phone'),
        'profile_image': user.get('profile_image'),
        'is_verified': bool(user.get('is_verified')),
        'email_verified': bool(user.get('email_verified')),
        'created_at': user['created_at'].isoformat() if user.get('created_at') else None,
        'last_login': user['last_login'].isoformat() if user.get('last_login') else None
    }
    
    if include_token:
        response['token'] = generate_token(user)
    
    return response

def require_auth(request):
    """
    Decorator helper to require authentication
    
    Args:
        request: Flask request object
        
    Returns:
        tuple: (user_payload, error_response) - one will be None
    """
    auth_header = request.headers.get('Authorization')
    token = extract_token_from_header(auth_header)
    
    if not token:
        return None, {'message': 'Missing authorization token'}, 401
    
    is_valid, payload = verify_token(token)
    if not is_valid:
        return None, {'message': payload}, 401
    
    return payload, None, None

def require_role(request, allowed_roles):
    """
    Require specific roles for access
    
    Args:
        request: Flask request object
        allowed_roles: List of allowed roles
        
    Returns:
        tuple: (user_payload, error_response) - one will be None
    """
    payload, error, status = require_auth(request)
    if error:
        return None, error, status
    
    if payload['role'] not in allowed_roles:
        return None, {'message': 'Insufficient permissions'}, 403
    
    return payload, None, None
