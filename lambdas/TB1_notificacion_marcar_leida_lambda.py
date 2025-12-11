"""
Lambda Function: TB1_notificacion_marcar_leida_lambda
Description: Mark a notification as read (HU007 support)
API Endpoint: PUT /notificaciones/{id}/leida
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


def lambda_handler(event, context):
    """
    Main handler for marking notification as read.
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
        # Get notification ID from path parameters
        path_params = event.get('pathParameters', {}) or {}
        notification_id = path_params.get('id')
        
        if not notification_id:
            return error_response('El ID de notificación es requerido', 400)
        
        try:
            notification_id = int(notification_id)
        except (ValueError, TypeError):
            return error_response('ID de notificación debe ser un número válido', 400)
        
        logger.info(f"Marking notification {notification_id} as read")
        
        # Connect to database
        conn = get_connection()
        cursor = conn.cursor()
        
        # Update notification as read
        cursor.execute('''
            UPDATE dbo.TM_NOTIFICACION
            SET LEIDO = 1
            WHERE IDNOTIFICACION = ? AND ACTIVO = 1
        ''', (notification_id,))
        
        rows_affected = cursor.rowcount
        conn.commit()
        
        if rows_affected == 0:
            return error_response('Notificación no encontrada', 404)
        
        logger.info(f"Notification {notification_id} marked as read")
        
        return success_response(
            {'idNotificacion': notification_id, 'leido': True},
            'Notificación marcada como leída'
        )
        
    except pyodbc.Error as e:
        logger.error(f"Database error: {str(e)}")
        return error_response('Error de base de datos', 500)
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return error_response('Error interno del servidor', 500)
        
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
