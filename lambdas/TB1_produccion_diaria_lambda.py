"""
Lambda Function: TB1_produccion_diaria_lambda
Description: Get daily productivity by user for PROD. DÍA view
API Endpoint: GET /produccion?fecha=2025-12-10
Runtime: Python 3.13
Database: DB_APPCOMERCIAL
Layer: arn:aws:lambda:us-east-1:411014146872:layer:pyodbc313:1

Environment Variables:
    - DB_HOST, DB_NAME, DB_USER, DB_PASSWORD
"""
import json
import pyodbc
import os
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Database configuration
DB_HOST = os.environ.get('DB_HOST', 'database-1.c9ywsse2shj2.us-east-1.rds.amazonaws.com')
DB_NAME = os.environ.get('DB_NAME', 'DB_APPCOMERCIAL')
DB_USER = os.environ.get('DB_USER', 'admin')
DB_PASSWORD = os.environ.get('DB_PASSWORD', 'Deviljin99!')

def get_connection():
    """Create database connection."""
    return pyodbc.connect(
        f"Driver={{ODBC Driver 18 for SQL Server}};"
        f"Server={DB_HOST};"
        f"Database={DB_NAME};"
        f"UID={DB_USER};"
        f"PWD={DB_PASSWORD};"
        f"Connection Timeout=30;"
        f"TrustServerCertificate=yes;"
    )

def get_cors_headers(methods='GET,OPTIONS'):
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
    """Generate error response."""
    return {
        'statusCode': status_code,
        'headers': get_cors_headers(),
        'body': json.dumps({
            'isSuccess': False,
            'errorCode': str(status_code),
            'errorMessage': message,
            'data': []
        })
    }

def lambda_handler(event, context):
    """
    Get daily productivity metrics for all executives.
    
    Query Parameters:
        - fecha: Date in YYYY-MM-DD format (required)
    
    Response:
        {
            "isSuccess": true,
            "data": [ list of executive productivity ]
        }
    """
    # Handle OPTIONS preflight
    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': ''
        }
    
    conn = None
    cursor = None
    
    try:
        # Get query parameters
        query_params = event.get('queryStringParameters', {}) or {}
        fecha = query_params.get('fecha')
        
        # Validate required parameters
        if not fecha:
            return error_response('Parámetro fecha es requerido', 400)
        
        # Sanitize date
        fecha = str(fecha).strip()[:10]
        
        # Connect to database
        conn = get_connection()
        cursor = conn.cursor()
        
        # Get userId from query params
        user_id = query_params.get('userId', '1')  # Default to admin if not provided
        try:
            user_id = int(user_id)
            if user_id <= 0:
                user_id = 1  # Default to admin
        except (ValueError, TypeError):
            user_id = 1
        
        # Execute stored procedure with actual userId for role-based access
        cursor.execute('EXEC usp_ObtenerProduccionDiaria @IdUsuario=?, @Fecha=?', (user_id, fecha))
        
        # Fetch results
        data = []
        columns = [column[0] for column in cursor.description]
        
        for row in cursor:
            item = {}
            for idx, column in enumerate(columns):
                value = row[idx]
                if value is not None and hasattr(value, 'isoformat'):
                    value = value.isoformat()
                item[column] = value
            data.append(item)
        
        logger.info(f"Produccion diaria for {fecha}: {len(data)} executives")
        return success_response(data)
        
    except pyodbc.Error as e:
        logger.error(f"Database error in produccion_diaria: {str(e)}")
        return error_response('Error de base de datos', 500)
        
    except Exception as e:
        logger.error(f"Unexpected error in produccion_diaria: {str(e)}")
        return error_response('Error interno del servidor', 500)
        
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
