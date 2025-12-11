"""
Lambda Function: TB1_user_login_lambda
Description: User authentication for login
API Endpoint: POST /login
Runtime: Python 3.13
Database: DB_APPCOMERCIAL
Layer: arn:aws:lambda:us-east-1:411014146872:layer:pyodbc313:1

Environment Variables (configure in Lambda):
    - DB_HOST: RDS endpoint
    - DB_NAME: Database name
    - DB_USER: Database user
    - DB_PASSWORD: Database password
"""
import json
import pyodbc
import os
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Database configuration from environment variables (with defaults for development)
DB_HOST = os.environ.get('DB_HOST', 'database-1.c9ywsse2shj2.us-east-1.rds.amazonaws.com')
DB_NAME = os.environ.get('DB_NAME', 'DB_APPCOMERCIAL')
DB_USER = os.environ.get('DB_USER', 'admin')
DB_PASSWORD = os.environ.get('DB_PASSWORD', 'Deviljin99!')

def get_connection():
    """Create database connection with proper settings."""
    return pyodbc.connect(
        f"Driver={{ODBC Driver 18 for SQL Server}};"
        f"Server={DB_HOST};"
        f"Database={DB_NAME};"
        f"UID={DB_USER};"
        f"PWD={DB_PASSWORD};"
        f"Connection Timeout=30;"
        f"TrustServerCertificate=yes;"
    )

def get_cors_headers(methods='POST,OPTIONS'):
    """Return CORS headers."""
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': methods,
        'Access-Control-Max-Age': '3600'
    }

def success_response(data, message='OK', status_code=200):
    """Generate success response."""
    return {
        'statusCode': status_code,
        'headers': get_cors_headers(),
        'body': json.dumps({
            'isSuccess': True,
            'errorCode': str(status_code),
            'errorMessage': message,
            'data': data
        })
    }

def error_response(message, status_code=500):
    """Generate error response without exposing internal details."""
    return {
        'statusCode': status_code,
        'headers': get_cors_headers(),
        'body': json.dumps({
            'isSuccess': False,
            'errorCode': str(status_code),
            'errorMessage': message,
            'data': None
        })
    }

def lambda_handler(event, context):
    """
    Handle login request.
    
    Request Body:
        {
            "username": "jperez" (or "userid"),
            "password": "exec123" (or "userpwd")
        }
    
    Response:
        {
            "isSuccess": true,
            "errorCode": "200",
            "errorMessage": "Login exitoso",
            "data": { user info }
        }
    """
    # Handle OPTIONS preflight request
    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': ''
        }
    
    conn = None
    cursor = None
    
    try:
        # Parse request body safely
        body = json.loads(event.get('body', '{}') or '{}')
        
        # Support both naming conventions
        username = body.get('userid') or body.get('username')
        password = body.get('userpwd') or body.get('password')
        
        # Validate required fields
        if not username or not password:
            return error_response('Usuario y contraseña son requeridos', 400)
        
        # Sanitize inputs (basic length check)
        username = str(username).strip()[:64]
        password = str(password)[:256]
        
        if len(username) < 1:
            return error_response('Usuario inválido', 400)
        
        # Connect to database
        conn = get_connection()
        cursor = conn.cursor()
        
        # Execute stored procedure with parameterized query (prevents SQL injection)
        cursor.execute(
            'EXEC usp_ValidarLogin @LoginUsuario=?, @Clave=?',
            (username, password)
        )
        
        # Fetch result
        row = cursor.fetchone()
        
        if row:
            # Build user data from columns
            columns = [column[0] for column in cursor.description]
            user_data = {}
            for idx, column in enumerate(columns):
                user_data[column] = row[idx]
            
            logger.info(f"Login successful for user: {username}")
            return success_response(user_data, 'Login exitoso', 200)
        else:
            logger.warning(f"Login failed for user: {username}")
            return error_response('Credenciales inválidas', 401)
        
    except pyodbc.Error as e:
        # Log error internally but don't expose to client
        logger.error(f"Database error during login: {str(e)}")
        return error_response('Error de conexión a base de datos', 500)
        
    except json.JSONDecodeError:
        return error_response('Formato de solicitud inválido', 400)
        
    except Exception as e:
        logger.error(f"Unexpected error during login: {str(e)}")
        return error_response('Error interno del servidor', 500)
        
    finally:
        # Always close connections
        if cursor:
            cursor.close()
        if conn:
            conn.close()
