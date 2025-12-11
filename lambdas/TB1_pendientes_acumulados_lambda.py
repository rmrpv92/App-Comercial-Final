"""
Lambda Function: TB1_pendientes_acumulados_lambda
Description: Get accumulated pending items for PENDIENTES ACUMULADOS view
API Endpoint: GET /pendientes-acumulados?userId=1&prioridad=Alta&fechaIni=2025-12-10&fechaFin=2025-12-31
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
    Get accumulated pending items (future follow-ups).
    
    Query Parameters:
        - userId: User ID (required)
        - prioridad: Filter by priority (optional): Alta, Media, Baja
        - fechaIni: Start date filter YYYY-MM-DD (optional)
        - fechaFin: End date filter YYYY-MM-DD (optional)
    
    Response:
        {
            "isSuccess": true,
            "data": [ list of pending items ]
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
        user_id = query_params.get('userId')
        prioridad = query_params.get('prioridad')
        fecha_ini = query_params.get('fechaIni')
        fecha_fin = query_params.get('fechaFin')
        
        # Validate required parameters
        if not user_id:
            return error_response('Parámetro userId es requerido', 400)
        
        # Validate user_id
        try:
            user_id = int(user_id)
            if user_id <= 0:
                return error_response('userId inválido', 400)
        except ValueError:
            return error_response('userId debe ser numérico', 400)
        
        # Sanitize optional parameters
        if prioridad:
            prioridad = str(prioridad).strip().upper()[:16]  # Normalize to uppercase
            if prioridad not in ('ALTA', 'MEDIA', 'BAJA'):
                prioridad = None  # Invalid value, ignore
        if fecha_ini:
            fecha_ini = str(fecha_ini).strip()[:10]
        if fecha_fin:
            fecha_fin = str(fecha_fin).strip()[:10]
        
        # Connect to database
        conn = get_connection()
        cursor = conn.cursor()
        
        # Execute stored procedure with filter parameters
        cursor.execute(
            'EXEC usp_ObtenerPendientesAcumulados @IdUsuario=?, @Prioridad=?, @FechaIni=?, @FechaFin=?',
            (user_id, prioridad, fecha_ini, fecha_fin)
        )
        
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
        
        logger.info(f"Pendientes acumulados for user {user_id}: {len(data)} items (filters: prioridad={prioridad}, fechaIni={fecha_ini}, fechaFin={fecha_fin})")
        return success_response(data)
        
    except pyodbc.Error as e:
        logger.error(f"Database error in pendientes_acumulados: {str(e)}")
        return error_response('Error de base de datos', 500)
        
    except Exception as e:
        logger.error(f"Unexpected error in pendientes_acumulados: {str(e)}")
        return error_response('Error interno del servidor', 500)
        
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
