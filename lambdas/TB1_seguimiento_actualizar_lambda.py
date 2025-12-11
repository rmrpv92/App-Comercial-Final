"""
Lambda Function: TB1_seguimiento_actualizar_lambda
Description: Update follow-up status and details for CRM records
API Endpoint: PUT /seguimiento
Runtime: Python 3.13
Database: DB_APPCOMERCIAL
Layer: arn:aws:lambda:us-east-1:411014146872:layer:pyodbc313:1
Environment Variables: DB_HOST, DB_NAME, DB_USER, DB_PASSWORD
"""
import json
import pyodbc
import os
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Database configuration from environment variables
DB_HOST = os.environ.get('DB_HOST', 'database-1.c9ywsse2shj2.us-east-1.rds.amazonaws.com')
DB_NAME = os.environ.get('DB_NAME', 'DB_APPCOMERCIAL')
DB_USER = os.environ.get('DB_USER', 'admin')
DB_PASSWORD = os.environ.get('DB_PASSWORD', 'Deviljin99!')

# Valid estados for validation
VALID_ESTADOS = ['PENDIENTE', 'REALIZADO', 'REPROGRAMADO', 'CANCELADO']


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
        'Access-Control-Allow-Methods': 'PUT,OPTIONS',
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
            'data': None
        })
    }


def sanitize_string(value, max_length=500):
    """Sanitize string input by truncating to max length."""
    if value is None:
        return None
    return str(value)[:max_length] if value else None


def lambda_handler(event, context):
    """
    Main handler for updating seguimiento (follow-up) records.
    Supports updating status and/or detailed information.
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
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        logger.info(f"Request body: {json.dumps(body)}")
        
        # Extract and validate idSeguimiento (required)
        idSeguimiento = body.get('idSeguimiento')
        if not idSeguimiento:
            logger.warning("Missing required field: idSeguimiento")
            return error_response('El campo idSeguimiento es requerido', 400)
        
        try:
            idSeguimiento = int(idSeguimiento)
        except (ValueError, TypeError):
            return error_response('idSeguimiento debe ser un número válido', 400)
        
        # Extract optional parameters
        estado = body.get('estado')
        usuarioModifica = body.get('usuarioModifica', 1)
        
        try:
            usuarioModifica = int(usuarioModifica)
        except (ValueError, TypeError):
            usuarioModifica = 1
        
        # Validate estado if provided
        if estado and estado not in VALID_ESTADOS:
            logger.warning(f"Invalid estado value: {estado}")
            return error_response(
                f'Estado inválido. Valores permitidos: {", ".join(VALID_ESTADOS)}', 
                400
            )
        
        # Connect to database
        conn = get_connection()
        cursor = conn.cursor()
        
        rows_affected = 0
        operations_performed = []
        
        # Update status if provided
        if estado:
            logger.info(f"Updating estado to {estado} for seguimiento {idSeguimiento}")
            cursor.execute('''
                EXEC usp_ActualizarSeguimiento 
                    @IdSeguimiento=?, @Estado=?, @UsuarioModifica=?
            ''', (idSeguimiento, estado, usuarioModifica))
            row = cursor.fetchone()
            rows_affected = row[0] if row else 0
            operations_performed.append('estado')
        
        # Update details if provided
        detalle = body.get('detalle')
        if detalle and isinstance(detalle, dict):
            logger.info(f"Updating detalle for seguimiento {idSeguimiento}")
            
            cursor.execute('''
                EXEC usp_ActualizarSeguimiento 
                    @IdSeguimiento=?, @Notas=?, @UsuarioModifica=?
            ''', (idSeguimiento, sanitize_string(detalle.get('observaciones'), 500), usuarioModifica))
            operations_performed.append('detalle')
        
        # Check if any operation was performed
        if not operations_performed:
            return error_response('No se proporcionaron datos para actualizar (estado o detalle)', 400)
        
        conn.commit()
        logger.info(f"Successfully updated seguimiento {idSeguimiento}: {operations_performed}")
        
        return success_response(
            {
                'idSeguimiento': idSeguimiento,
                'rowsAffected': rows_affected,
                'operationsPerformed': operations_performed
            },
            'Seguimiento actualizado correctamente'
        )
        
    except json.JSONDecodeError as e:
        logger.error(f"JSON parse error: {str(e)}")
        return error_response('Formato JSON inválido en el cuerpo de la solicitud', 400)
        
    except pyodbc.Error as e:
        logger.error(f"Database error: {str(e)}")
        return error_response('Error de base de datos al actualizar seguimiento', 500)
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return error_response('Error interno del servidor', 500)
        
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
