"""
Lambda Function: TB1_empresa_insertar_lambda
Description: Create new company for BÚSQUEDA view
API Endpoint: POST /empresa
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
    Create a new company.
    
    Request Body:
        {
            "nombreComercial": "..." (required),
            "razonSocial": "...",
            ... other fields (optional)
        }
    
    Response:
        {
            "isSuccess": true,
            "data": { "idEmpresa": 6 }
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
        
        # Sanitize function
        def sanitize(value, max_len=256):
            if value is None:
                return None
            return str(value).strip()[:max_len] if value else None
        
        # Helper to get field from either camelCase or UPPERCASE
        def get_field(body, camel_key, upper_key):
            return body.get(camel_key) or body.get(upper_key)
        
        # Extract and validate required fields (accept both camelCase and UPPERCASE)
        nombreComercial = sanitize(get_field(body, 'nombreComercial', 'NOMBRECOMERCIAL'), 256)
        if not nombreComercial:
            return error_response('nombreComercial es requerido', 400)
        
        # Extract optional parameters (accept both camelCase and UPPERCASE)
        razonSocial = sanitize(get_field(body, 'razonSocial', 'RAZONSOCIAL'), 256)
        ruc = sanitize(get_field(body, 'ruc', 'RUC'), 20)
        sedePrincipal = sanitize(get_field(body, 'sedePrincipal', 'SEDEPRINCIPAL'), 256)
        domicilio = sanitize(get_field(body, 'domicilio', 'DOMICILIO'), 256)
        contactoNombre = sanitize(get_field(body, 'contactoNombre', 'CONTACTO_NOMBRE'), 128)
        contactoEmail = sanitize(get_field(body, 'contactoEmail', 'CONTACTO_EMAIL'), 128)
        contactoTelefono = sanitize(get_field(body, 'contactoTelefono', 'CONTACTO_TELEFONO'), 32)
        contactoCargo = sanitize(get_field(body, 'contactoCargo', 'CONTACTO_CARGO'), 64)
        tipoCliente = sanitize(get_field(body, 'tipoCliente', 'TIPOCLIENTE'), 64)
        lineaNegocio = sanitize(get_field(body, 'lineaNegocio', 'LINEANEGOCIO'), 128)
        subLineaNegocio = sanitize(get_field(body, 'subLineaNegocio', 'SUBLINEANEGOCIO'), 128)
        tipoCredito = sanitize(get_field(body, 'tipoCredito', 'TIPOCREDITO'), 64)
        tipoCartera = sanitize(get_field(body, 'tipoCartera', 'TIPOCARTERA'), 64)
        actividadEconomica = sanitize(get_field(body, 'actividadEconomica', 'ACTIVIDADECONOMICA'), 128)
        riesgo = sanitize(get_field(body, 'riesgo', 'RIESGO'), 64)
        numTrabajadores = get_field(body, 'numTrabajadores', 'NUMTRABAJADORES')
        usuarioCrea = get_field(body, 'usuarioCrea', 'USUARIOCREA') or 1
        
        # Validate numTrabajadores if provided
        if numTrabajadores is not None:
            try:
                numTrabajadores = int(numTrabajadores)
            except ValueError:
                numTrabajadores = None
        
        # Connect to database
        conn = get_connection()
        cursor = conn.cursor()
        
        # Execute stored procedure - includes @ContactoCargo
        params = (
            nombreComercial, razonSocial, ruc, sedePrincipal, domicilio,
            contactoNombre, contactoEmail, contactoTelefono, contactoCargo,
            tipoCliente, lineaNegocio, subLineaNegocio, tipoCredito, tipoCartera,
            actividadEconomica, riesgo, numTrabajadores, int(usuarioCrea)
        )
        
        cursor.execute('''
            EXEC usp_InsertarEmpresa 
                @NombreComercial=?, @RazonSocial=?, @RUC=?, @SedePrincipal=?, @Domicilio=?,
                @ContactoNombre=?, @ContactoEmail=?, @ContactoTelefono=?, @ContactoCargo=?,
                @TipoCliente=?, @LineaNegocio=?, @SublineaNegocio=?, @TipoCredito=?, @TipoCartera=?,
                @ActividadEconomica=?, @Riesgo=?, @NumTrabajadores=?, @UsuarioCrea=?
        ''', params)
        
        # Get new ID
        row = cursor.fetchone()
        idempresa_new = row[0] if row else None
        
        conn.commit()
        
        logger.info(f"Created new empresa with ID: {idempresa_new}")
        return success_response({'idEmpresa': idempresa_new}, 'Empresa creada correctamente', 201)
        
    except pyodbc.Error as e:
        logger.error(f"Database error in empresa_insertar: {str(e)}")
        return error_response('Error de base de datos', 500)
        
    except json.JSONDecodeError:
        return error_response('Formato de solicitud inválido', 400)
        
    except Exception as e:
        logger.error(f"Unexpected error in empresa_insertar: {str(e)}")
        return error_response('Error interno del servidor', 500)
        
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
