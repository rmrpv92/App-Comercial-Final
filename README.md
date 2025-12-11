# App Comercial - Sistema de Gestión de Seguimientos

## 📋 Descripción

App Comercial es un sistema de gestión de seguimientos comerciales desarrollado como proyecto final para el curso de Desarrollo para Entorno Web - UPC 2025-2.

El sistema permite a los ejecutivos comerciales gestionar sus actividades diarias, seguimientos con clientes, y a los supervisores monitorear el rendimiento de su equipo.

## 🏗️ Arquitectura

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    Angular 20   │────▶│  API Gateway    │────▶│  AWS Lambda     │────▶│   SQL Server    │
│    Frontend     │     │  (REST API)     │     │  (Python 3.13)  │     │   RDS           │
└─────────────────┘     └─────────────────┘     └─────────────────┘     └─────────────────┘
```

## 📚 Documentación

- [Guía Detallada de Historias de Usuario](docs/GUIA_HISTORIAS_USUARIO.md)
- [Guía de Configuración de AWS](docs/AWS_CONFIGURATION_GUIDE.md)

## 🎯 Historias de Usuario Implementadas

| HU | Nombre | Vista | Roles |
|----|--------|-------|-------|
| HU001 | Búsqueda de Clientes | BÚSQUEDA | Todos |
| HU002 | Agenda del Día | AGENDA DEL DÍA | Todos |
| HU003 | Dashboard Supervisor | DASHBOARD | Admin, Supervisor |
| HU004 | Pendientes Acumulados | PENDIENTES ACUMULADOS | Todos |
| HU005 | Pendientes Olvidados | PENDIENTES OLVIDADOS | Admin, Supervisor |
| HU006 | Monitoreo/Calendario | MONITOREO | Admin, Supervisor |
| HU009 | Ventas Cerradas | VENTAS CERRADAS | Admin, Supervisor |
| HU010 | Producción del Día | PRODUCCIÓN | Admin, Supervisor |

## 🛠️ Tecnologías

### Frontend
- **Framework:** Angular 20
- **UI:** Bootstrap 5
- **Lenguaje:** TypeScript

### Backend
- **Funciones:** AWS Lambda (Python 3.13)
- **API:** AWS API Gateway
- **Base de Datos:** SQL Server (AWS RDS)

### Infraestructura AWS
- **Hosting:** AWS Amplify
- **API:** API Gateway REST
- **Compute:** Lambda Functions
- **Database:** RDS SQL Server
- **Layer:** pyodbc313 para conexión ODBC

## 📁 Estructura del Proyecto

```
├── docs/                           # Documentación
│   └── GUIA_HISTORIAS_USUARIO.md
├── lambdas/                        # Funciones Lambda
│   ├── TB1_login_lambda.py
│   ├── TB1_busqueda_clientes_lambda.py
│   ├── TB1_agenda_dia_lambda.py
│   ├── TB1_dashboard_supervisor_lambda.py
│   ├── TB1_pendientes_lambda.py
│   ├── TB1_calendario_lambda.py
│   ├── TB1_cerrados_semana_lambda.py
│   └── TB1_produccion_diaria_lambda.py
├── sql/                            # Scripts SQL
│   ├── 01_create_database.sql
│   ├── 02_create_tables.sql
│   ├── 03_insert_data.sql
│   ├── 04_stored_procedures.sql
│   └── ...
└── frontend/                       # Proyecto Angular
    ├── src/
    │   ├── app/
    │   │   ├── pages/
    │   │   └── services/
    │   └── environments/
    └── angular.json
```

## 🚀 Instalación y Ejecución

### Requisitos Previos
- Node.js 18+
- Angular CLI 20
- AWS CLI (para despliegue)

### Instalación Local

```bash
# Clonar repositorio
git clone https://github.com/rmrpv92/App-Comercial-Final.git

# Ir al directorio frontend
cd frontend

# Instalar dependencias
npm install

# Ejecutar en desarrollo
ng serve --open
```

### Despliegue en AWS Amplify

1. Construir el proyecto:
```bash
ng build --configuration production
```

2. Comprimir la carpeta `dist/` en un archivo ZIP

3. En AWS Amplify Console:
   - Crear nueva aplicación
   - Seleccionar "Deploy without Git provider"
   - Subir el archivo ZIP

## 🔐 Credenciales de Prueba

| Usuario | Contraseña | Rol |
|---------|------------|-----|
| admin1 | admin123 | Administrador |
| supervisor1 | super123 | Supervisor |
| ejecutivo1 | ejec123 | Ejecutivo |

## 📡 API Endpoints

**Base URL:** `https://o1a90x561f.execute-api.us-east-1.amazonaws.com/v1`

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| POST | /login | Autenticación |
| GET | /empresas | Búsqueda de empresas |
| GET | /agenda | Agenda del día |
| GET | /dashboard | Métricas dashboard |
| GET | /pendientes | Pendientes acumulados/olvidados |
| GET | /calendario | Calendario semanal |
| GET | /cerrados | Ventas cerradas |
| GET | /produccion | Producción diaria |

## 👥 Equipo - Grupo 3

- Integrante 1
- Integrante 2
- Integrante 3
- Integrante 4

## 📄 Licencia

Este proyecto es parte del curso de Desarrollo para Entorno Web - UPC 2025-2

---

**Universidad Peruana de Ciencias Aplicadas - UPC**  
Diciembre 2025
