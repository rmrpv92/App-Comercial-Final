"""
Lambda Function: TB1_notificaciones_lambda
Description: Get notifications and alerts for high-value follow-ups not attended in 24+ hours (HU007)
API Endpoint: GET /notificaciones?userId=3
Runtime: Python 3.13
Database: DB_APPCOMERCIAL
Layer: arn:aws:lambda:us-east-1:411014146872:layer:pyodbc313:1
Environment Variables: DB_HOST, DB_NAME, DB_USER, DB_PASSWORD

HU007: Notificación de Alerta para el equipo Comerciala
- Como Ejecutiva Comercial, quiero recibir notificaciones cuando un seguimiento 
  considerado de alto valor no haya sido atendido en más de 24 horas
- Para intervenir oportunamente y reducir el riesgo de perder oportunidades importantes
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
            'data': None
        })
    }


def lambda_handler(event, context):
    """
    Main handler for retrieving notifications.
    Returns:
    - High-value follow-ups not attended in 24+ hours (alerts)
    - System notifications for the user
    - Unread notification count
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
        # Get userId from path parameters first, then query parameters
        path_params = event.get('pathParameters', {}) or {}
        query_params = event.get('queryStringParameters', {}) or {}
        
        user_id = path_params.get('userId') or query_params.get('userId')
        
        # Validate userId
        if not user_id:
            logger.warning("Missing userId parameter")
            return error_response('El parámetro userId es requerido', 400)
        
        try:
            user_id = int(user_id)
        except (ValueError, TypeError):
            return error_response('userId debe ser un número válido', 400)
        
        logger.info(f"Fetching notifications for user: {user_id}")
        
        # Connect to database
        conn = get_connection()
        cursor = conn.cursor()
        
        # 1. Get high-value alerts (seguimientos de alta prioridad sin atender en 24+ horas)
        cursor.execute('''
            SELECT 
                S.IDSEGUIMIENTO,
                S.FECHAPROGRAMADA,
                S.HORAPROGRAMADA,
                S.PRIORIDAD,
                S.ESTADO,
                E.IDEMPRESA,
                E.NOMBRECOMERCIAL AS EMPRESA,
                E.CONTACTO_NOMBRE AS CONTACTO,
                T.NOMBRE AS TIPOSEGUIMIENTO,
                DATEDIFF(HOUR, 
                    CAST(S.FECHAPROGRAMADA AS DATETIME) + CAST(ISNULL(S.HORAPROGRAMADA, '00:00:00') AS DATETIME),
                    GETDATE()
                ) AS HORAS_SIN_ATENCION,
                D.PRESUPUESTO
            FROM dbo.TM_SEGUIMIENTO S
            INNER JOIN dbo.TM_EMPRESA E ON S.IDEMPRESA = E.IDEMPRESA
            INNER JOIN dbo.TM_SEGUIMIENTO_TIPO T ON S.IDTIPOSEGUIMIENTO = T.IDTIPOSEGUIMIENTO
            LEFT JOIN dbo.TM_SEGUIMIENTO_DETALLE D ON S.IDSEGUIMIENTO = D.IDSEGUIMIENTO AND D.ACTIVO = 1
            WHERE S.IDUSUARIOASIGNADO = ?
              AND UPPER(S.PRIORIDAD) = 'ALTA'
              AND S.ESTADO = 'PENDIENTE'
              AND DATEDIFF(HOUR, 
                    CAST(S.FECHAPROGRAMADA AS DATETIME) + CAST(ISNULL(S.HORAPROGRAMADA, '00:00:00') AS DATETIME),
                    GETDATE()
                  ) >= 24
              AND S.ACTIVO = 1
            ORDER BY S.FECHAPROGRAMADA
        ''', (user_id,))
        
        alerts = []
        columns = [column[0] for column in cursor.description]
        for row in cursor:
            item = {}
            for idx, column in enumerate(columns):
                value = row[idx]
                if value is not None and hasattr(value, 'isoformat'):
                    value = value.isoformat()
                item[column] = value
            # Add alert type
            item['TIPO_ALERTA'] = 'ALTO_VALOR_NO_ATENDIDO'
            item['MENSAJE'] = f"Seguimiento de alta prioridad con {item.get('EMPRESA', '')} sin atender por más de 24 horas"
            alerts.append(item)
        
        # 2. Get system notifications for the user
        cursor.execute('''
            SELECT 
                N.IDNOTIFICACION,
                N.TITULO,
                N.MENSAJE,
                N.TIPO,
                N.LEIDO,
                N.FECHAENVIO
            FROM dbo.TM_NOTIFICACION N
            WHERE N.IDUSUARIO = ?
              AND N.ACTIVO = 1
            ORDER BY N.FECHAENVIO DESC
        ''', (user_id,))
        
        notifications = []
        if cursor.description:
            columns = [column[0] for column in cursor.description]
            for row in cursor:
                item = {}
                for idx, column in enumerate(columns):
                    value = row[idx]
                    if value is not None and hasattr(value, 'isoformat'):
                        value = value.isoformat()
                    item[column] = value
                notifications.append(item)
        
        # 3. Count unread
        cursor.execute('''
            SELECT COUNT(*) AS UNREAD_COUNT
            FROM dbo.TM_NOTIFICACION
            WHERE IDUSUARIO = ? AND LEIDO = 0 AND ACTIVO = 1
        ''', (user_id,))
        
        unread_row = cursor.fetchone()
        unread_count = unread_row[0] if unread_row else 0
        
        # Add alerts count to unread
        total_unread = unread_count + len(alerts)
        
        logger.info(f"Found {len(alerts)} alerts and {len(notifications)} notifications for user {user_id}")
        
        data = {
            'alertas': alerts,
            'notificaciones': notifications,
            'totalAlertas': len(alerts),
            'totalNotificaciones': len(notifications),
            'noLeidos': total_unread
        }
        
        return success_response(data, 'OK')
        
    except pyodbc.Error as e:
        logger.error(f"Database error: {str(e)}")
        return error_response('Error de base de datos al consultar notificaciones', 500)
        
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return error_response('Error interno del servidor', 500)
        
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
