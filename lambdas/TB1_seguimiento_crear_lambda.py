"""
Lambda Function: TB1_seguimiento_crear_lambda
Description: Create new follow-up record
API Endpoint: POST /seguimiento
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

def get_cors_headers(methods='POST,OPTIONS'):
    """Return CORS headers."""
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': methods,
        'Access-Control-Max-Age': '3600'
    }

def success_response(data, message='OK', status_code=201):
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

def lambda_handler(event, context):
    """
    Create a new follow-up (seguimiento).
    
    Request Body:
        {
            "idEmpresa": 1 (required),
            "idUsuarioAsignado": 3 (required),
            "idTipoSeguimiento": 1 (required),
            "prioridad": "Alta" (required),
            "fechaProgramada": "2025-12-15" (required),
            "horaProgramada": "10:00" (required),
            "notas": "..." (optional),
            "usuarioCrea": 1 (optional, defaults to 1)
        }
    
    Response:
        {
            "isSuccess": true,
            "data": { "idSeguimiento": 9 }
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
        # Parse request body
        body = json.loads(event.get('body', '{}') or '{}')
        
        # Extract required parameters
        idEmpresa = body.get('idEmpresa')
        idUsuarioAsignado = body.get('idUsuarioAsignado')
        idTipoSeguimiento = body.get('idTipoSeguimiento')
        prioridad = body.get('prioridad')
        fechaProgramada = body.get('fechaProgramada')
        horaProgramada = body.get('horaProgramada')
        notas = body.get('notas')
        usuarioCrea = body.get('usuarioCrea', 1)
        
        # Validate required fields
        required_fields = {
            'idEmpresa': idEmpresa,
            'idUsuarioAsignado': idUsuarioAsignado,
            'idTipoSeguimiento': idTipoSeguimiento,
            'prioridad': prioridad,
            'fechaProgramada': fechaProgramada,
            'horaProgramada': horaProgramada
        }
        
        missing = [k for k, v in required_fields.items() if not v]
        if missing:
            return error_response(f'Campos requeridos: {", ".join(missing)}', 400)
        
        # Validate integers
        try:
            idEmpresa = int(idEmpresa)
            idUsuarioAsignado = int(idUsuarioAsignado)
            idTipoSeguimiento = int(idTipoSeguimiento)
            usuarioCrea = int(usuarioCrea)
        except ValueError:
            return error_response('Los IDs deben ser numéricos', 400)
        
        # Sanitize strings
        prioridad = str(prioridad).strip()[:16]
        fechaProgramada = str(fechaProgramada).strip()[:10]
        horaProgramada = str(horaProgramada).strip()[:8]
        if notas:
            notas = str(notas).strip()[:4000]
        
        # Validate prioridad
        if prioridad not in ['Alta', 'Media', 'Baja']:
            return error_response('Prioridad debe ser: Alta, Media o Baja', 400)
        
        # Connect to database
        conn = get_connection()
        cursor = conn.cursor()
        
        # Execute stored procedure
        params = (
            idEmpresa, idTipoSeguimiento, idUsuarioAsignado,
            fechaProgramada, horaProgramada, prioridad, notas, usuarioCrea
        )
        
        cursor.execute('''
            EXEC usp_CrearSeguimiento 
                @IdEmpresa=?, @IdTipoSeguimiento=?, @IdUsuarioAsignado=?,
                @FechaProgramada=?, @HoraProgramada=?, @Prioridad=?, @Notas=?, @UsuarioCrea=?
        ''', params)
        
        # Get new ID
        row = cursor.fetchone()
        idseguimiento_new = row[0] if row else None
        
        conn.commit()
        
        logger.info(f"Created new seguimiento with ID: {idseguimiento_new}")
        return success_response({'idSeguimiento': idseguimiento_new}, 'Seguimiento creado correctamente', 201)
        
    except pyodbc.Error as e:
        logger.error(f"Database error in seguimiento_crear: {str(e)}")
        return error_response('Error de base de datos', 500)
        
    except json.JSONDecodeError:
        return error_response('Formato de solicitud inválido', 400)
        
    except Exception as e:
        logger.error(f"Unexpected error in seguimiento_crear: {str(e)}")
        return error_response('Error interno del servidor', 500)
        
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
