"""
Lambda Function: TB1_cerrados_semana_lambda
Description: Get weekly closed deals for CERRADOS view - shows completed sales metrics
API Endpoint: GET /cerrados?fechaIni=2025-12-09&fechaFin=2025-12-15
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
from decimal import Decimal

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


def decimal_default(obj):
    """JSON serializer for Decimal types."""
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")


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
        }, default=decimal_default)
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
            'data': None
        })
    }


def validate_date_format(date_str):
    """Validate date format is YYYY-MM-DD."""
    return bool(DATE_PATTERN.match(date_str)) if date_str else False


def convert_value(value):
    """Convert database value to JSON-serializable format."""
    if isinstance(value, Decimal):
        return float(value)
    elif value is not None and hasattr(value, 'isoformat'):
        return value.isoformat()
    return value


def fetch_result_set(cursor):
    """Fetch all rows from current result set as list of dicts."""
    if not cursor.description:
        return []
    
    columns = [column[0] for column in cursor.description]
    results = []
    
    for row in cursor:
        item = {columns[idx]: convert_value(value) for idx, value in enumerate(row)}
        results.append(item)
    
    return results


def lambda_handler(event, context):
    """
    Main handler for retrieving closed deals report.
    Returns metrics, daily breakdown, and history for the date range.
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
        fecha_inicio = query_params.get('fechaIni')
        fecha_fin = query_params.get('fechaFin')
        user_id = query_params.get('userId', '1')  # Default to admin if not provided
        
        # Validate and convert user_id
        try:
            user_id = int(user_id)
            if user_id <= 0:
                user_id = 1  # Default to admin
        except (ValueError, TypeError):
            user_id = 1
        
        # Validate required parameters
        if not fecha_inicio or not fecha_fin:
            logger.warning("Missing required date parameters")
            return error_response('Los parámetros fechaIni y fechaFin son requeridos', 400)
        
        # Validate date format
        if not validate_date_format(fecha_inicio):
            return error_response('Formato de fechaIni inválido. Use YYYY-MM-DD', 400)
        
        if not validate_date_format(fecha_fin):
            return error_response('Formato de fechaFin inválido. Use YYYY-MM-DD', 400)
        
        # Validate date range
        if fecha_fin < fecha_inicio:
            return error_response('fechaFin debe ser mayor o igual a fechaIni', 400)
        
        logger.info(f"Querying closed deals for user {user_id} from {fecha_inicio} to {fecha_fin}")
        
        # Connect to database
        conn = get_connection()
        cursor = conn.cursor()
        
        # Execute stored procedure with actual userId
        params = (user_id, fecha_inicio, fecha_fin)
        cursor.execute('EXEC usp_ObtenerCerradosSemana @IdUsuario=?, @FechaInicio=?, @FechaFin=?', params)
        
        # Result set 1: Historial (detailed list of completados)
        historial = []
        if cursor.description:
            historial = fetch_result_set(cursor)
        
        # Result set 2: Métricas/Estadísticas (summary with MONTO and DIAS)
        metricas = None
        if cursor.nextset() and cursor.description:
            stats = fetch_result_set(cursor)
            if stats:
                metricas = {
                    'TOTAL_CERRADOS': stats[0].get('TOTAL_CERRADOS', stats[0].get('TotalCerrados', 0)),
                    'EXITOSOS': stats[0].get('Exitosos', 0),
                    'SIN_RESPUESTA': stats[0].get('SinRespuesta', 0),
                    'NO_INTERESADOS': stats[0].get('NoInteresados', 0),
                    'MONTO_TOTAL': stats[0].get('MontoTotal', 0),
                    'DIAS_PROMEDIO_CIERRE': stats[0].get('DiasPromedioCierre', 0)
                }
        
        # Result set 3: Breakdown por día (for the chart)
        por_dia = []
        if cursor.nextset() and cursor.description:
            por_dia = fetch_result_set(cursor)
        
        logger.info(f"Retrieved {len(historial)} history records, metrics: {metricas}, {len(por_dia)} daily entries")
        
        data = {
            'metricas': metricas,
            'porDia': por_dia,
            'historial': historial
        }
        
        return success_response(data, 'OK')
        
    except pyodbc.Error as e:
        logger.error(f"Database error: {str(e)}")
        return error_response('Error de base de datos al consultar cerrados', 500)
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return error_response('Error interno del servidor', 500)
        
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
