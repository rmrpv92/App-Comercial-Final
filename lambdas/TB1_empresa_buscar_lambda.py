"""
Lambda Function: TB1_empresa_buscar_lambda
Description: Search companies with filters for BÚSQUEDA view
API Endpoint: GET /empresas?search=texto&usuario=username
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
            'data': []
        })
    }

def lambda_handler(event, context):
    """
    Search companies with optional filters.
    
    Query Parameters:
        - search: Text to search in company name, RUC, contact (optional)
        - usuario: Filter by assigned user (optional)
    
    Response:
        {
            "isSuccess": true,
            "data": [ list of companies ]
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
        # Get query parameters safely
        query_params = event.get('queryStringParameters', {}) or {}
        search_text = query_params.get('search')
        usuario = query_params.get('usuario')
        
        # Sanitize inputs
        if search_text:
            search_text = str(search_text).strip()[:256]
        if usuario:
            usuario = str(usuario).strip()[:64]
        
        # Connect to database
        conn = get_connection()
        cursor = conn.cursor()
        
        # Execute stored procedure with parameterized query
        # usp_BuscarEmpresas expects @Criterio (search text), @TipoCliente, @TipoCartera
        cursor.execute(
            'EXEC usp_BuscarEmpresas @Criterio=?',
            (search_text,)
        )
        
        # Fetch results
        data = []
        columns = [column[0] for column in cursor.description]
        
        for row in cursor:
            empresa = {}
            for idx, column in enumerate(columns):
                value = row[idx]
                # Convert types for JSON serialization
                if value is not None and hasattr(value, 'isoformat'):
                    value = value.isoformat()
                empresa[column] = value
            data.append(empresa)
        
        logger.info(f"Search returned {len(data)} companies")
        return success_response(data)
        
    except pyodbc.Error as e:
        logger.error(f"Database error in empresa_buscar: {str(e)}")
        return error_response('Error de base de datos', 500)
        
    except Exception as e:
        logger.error(f"Unexpected error in empresa_buscar: {str(e)}")
        return error_response('Error interno del servidor', 500)
        
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
