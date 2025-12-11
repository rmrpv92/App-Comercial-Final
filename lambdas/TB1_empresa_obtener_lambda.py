"""
Lambda Function: TB1_empresa_obtener_lambda
Description: Get complete company details for BÚSQUEDA view
API Endpoint: GET /empresa?id=1
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
            'data': None
        })
    }

def row_to_dict(cursor, row):
    """Convert a row to dictionary with proper type handling."""
    if row is None or cursor.description is None:
        return None
    
    columns = [column[0] for column in cursor.description]
    result = {}
    for idx, column in enumerate(columns):
        value = row[idx]
        if value is not None and hasattr(value, 'isoformat'):
            value = value.isoformat()
        result[column] = value
    return result

def rows_to_list(cursor):
    """Convert all cursor rows to list of dictionaries."""
    if cursor.description is None:
        return []
    
    columns = [column[0] for column in cursor.description]
    data = []
    for row in cursor:
        item = {}
        for idx, column in enumerate(columns):
            value = row[idx]
            if value is not None and hasattr(value, 'isoformat'):
                value = value.isoformat()
            item[column] = value
        data.append(item)
    return data

def lambda_handler(event, context):
    """
    Get complete company details with multi-resultset handling.
    
    Query Parameters:
        - id: Company ID (required)
    
    Response:
        {
            "isSuccess": true,
            "data": {
                "IDEMPRESA": 1,
                "NOMBRECOMERCIAL": "...",
                "sedes": [...],
                "seguimiento": {...},
                "detalleSeguimiento": {...}
            }
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
        # Get query parameter
        query_params = event.get('queryStringParameters', {}) or {}
        id_empresa = query_params.get('id')
        
        # Validate ID
        if not id_empresa:
            return error_response('Parámetro id es requerido', 400)
        
        try:
            id_empresa = int(id_empresa)
            if id_empresa <= 0:
                return error_response('ID de empresa inválido', 400)
        except ValueError:
            return error_response('ID de empresa debe ser numérico', 400)
        
        # Connect to database
        conn = get_connection()
        cursor = conn.cursor()
        
        # Execute stored procedure with parameterized query
        cursor.execute('EXEC usp_ObtenerEmpresa @IdEmpresa=?', (id_empresa,))
        
        # Result set 1: Empresa data
        empresa = row_to_dict(cursor, cursor.fetchone())
        
        # Result set 2: Sedes
        sedes = []
        if cursor.nextset() and cursor.description:
            sedes = rows_to_list(cursor)
        
        # Result set 3: Último seguimiento
        seguimiento = None
        if cursor.nextset() and cursor.description:
            seguimiento = row_to_dict(cursor, cursor.fetchone())
        
        # Result set 4: Detalle seguimiento
        detalle_seguimiento = None
        if cursor.nextset() and cursor.description:
            detalle_seguimiento = row_to_dict(cursor, cursor.fetchone())
        
        # Build response
        if empresa:
            empresa['sedes'] = sedes
            empresa['seguimiento'] = seguimiento
            empresa['detalleSeguimiento'] = detalle_seguimiento
            
            logger.info(f"Retrieved empresa {id_empresa}")
            return success_response(empresa)
        else:
            return error_response('Empresa no encontrada', 404)
        
    except pyodbc.Error as e:
        logger.error(f"Database error in empresa_obtener: {str(e)}")
        return error_response('Error de base de datos', 500)
        
    except Exception as e:
        logger.error(f"Unexpected error in empresa_obtener: {str(e)}")
        return error_response('Error interno del servidor', 500)
        
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
