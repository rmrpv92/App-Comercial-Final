"""
Lambda Function: TB1_calendario_supervisor_lambda
Description: Get weekly calendar for ASIG. SUPERVISOR view - shows scheduled tasks
API Endpoint: GET /calendario?fechaIni=2025-12-09&fechaFin=2025-12-15&userId=1
Runtime: Python 3.13
Database: DB_APPCOMERCIAL
Layer: arn:aws:lambda:us-east-1:411014146872:layer:pyodbc313:1
Environment Variables: DB_HOST, DB_NAME, DB_USER, DB_PASSWORD
"""
import json
import pyodbc
import os
import logging
import re

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Database configuration from environment variables
DB_HOST = os.environ.get('DB_HOST', 'database-1.c9ywsse2shj2.us-east-1.rds.amazonaws.com')
DB_NAME = os.environ.get('DB_NAME', 'DB_APPCOMERCIAL')
DB_USER = os.environ.get('DB_USER', 'admin')
DB_PASSWORD = os.environ.get('DB_PASSWORD', 'Deviljin99!')

# Date format pattern for validation
DATE_PATTERN = re.compile(r'^\d{4}-\d{2}-\d{2}$')


def get_connection():
    """Create and return a database connection."""
    return pyodbc.connect(
        f"Driver={{ODBC Driver 18 for SQL Server}};"
        f"Server={DB_HOST};"
        f"Database={DB_NAME};"
        f"UID={DB_USER};"
        f"PWD={DB_PASSWORD};"
    )


def get_cors_headers():
    """Return CORS headers for responses."""
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,OPTIONS',
        'Access-Control-Max-Age': '86400'
    }


def success_response(data, message='OK', status_code=200):
    """Return a standardized success response."""
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
    """Return a standardized error response."""
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


def validate_date_format(date_str):
    """Validate date format is YYYY-MM-DD."""
    return bool(DATE_PATTERN.match(date_str)) if date_str else False


def lambda_handler(event, context):
    """
    Main handler for retrieving calendar/schedule data for supervisor view.
    Returns scheduled follow-ups within a date range.
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    # Handle OPTIONS preflight request
    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps({'message': 'OK'})
        }
    
    conn = None
    cursor = None
    
    try:
        # Get query parameters
        query_params = event.get('queryStringParameters', {}) or {}
        fecha_ini = query_params.get('fechaIni')
        fecha_fin = query_params.get('fechaFin')
        user_id = query_params.get('userId')  # Optional filter
        
        # Validate required parameters
        if not fecha_ini or not fecha_fin:
            logger.warning("Missing required date parameters")
            return error_response('Los parámetros fechaIni y fechaFin son requeridos', 400)
        
        # Validate date format
        if not validate_date_format(fecha_ini):
            return error_response('Formato de fechaIni inválido. Use YYYY-MM-DD', 400)
        
        if not validate_date_format(fecha_fin):
            return error_response('Formato de fechaFin inválido. Use YYYY-MM-DD', 400)
        
        # Validate date range (fechaFin >= fechaIni)
        if fecha_fin < fecha_ini:
            return error_response('fechaFin debe ser mayor o igual a fechaIni', 400)
        
        # Parse user_id if provided
        parsed_user_id = None
        if user_id:
            try:
                parsed_user_id = int(user_id)
            except (ValueError, TypeError):
                return error_response('userId debe ser un número válido', 400)
        
        logger.info(f"Querying calendar from {fecha_ini} to {fecha_fin}, userId: {parsed_user_id}")
        
        # Connect to database
        conn = get_connection()
        cursor = conn.cursor()
        
        # Execute stored procedure
        params = (parsed_user_id or 1, fecha_ini, fecha_fin)
        cursor.execute('EXEC usp_ObtenerCalendarioSupervisor @IdSupervisor=?, @FechaInicio=?, @FechaFin=?', params)
        
        # Fetch results
        data = []
        columns = [column[0] for column in cursor.description]
        
        for row in cursor:
            item = {}
            for idx, column in enumerate(columns):
                value = row[idx]
                # Convert datetime objects to ISO format string
                if value is not None and hasattr(value, 'isoformat'):
                    value = value.isoformat()
                item[column] = value
            data.append(item)
        
        logger.info(f"Retrieved {len(data)} calendar entries")
        
        return success_response(data, 'OK')
        
    except pyodbc.Error as e:
        logger.error(f"Database error: {str(e)}")
        return error_response('Error de base de datos al consultar calendario', 500)
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return error_response('Error interno del servidor', 500)
        
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
