# Guía Detallada de Historias de Usuario - App Comercial

## Índice
1. [Arquitectura General](#arquitectura-general)
2. [HU001 - Búsqueda de Clientes](#hu001---búsqueda-de-clientes)
3. [HU002 - Agenda del Día](#hu002---agenda-del-día)
4. [HU003 - Dashboard Supervisor](#hu003---dashboard-supervisor)
5. [HU004 - Pendientes Acumulados](#hu004---pendientes-acumulados)
6. [HU005 - Pendientes Olvidados](#hu005---pendientes-olvidados)
7. [HU006 - Monitoreo / Calendario de Supervisión](#hu006---monitoreo--calendario-de-supervisión)
8. [HU009 - Ventas Cerradas](#hu009---ventas-cerradas)
9. [HU010 - Producción del Día](#hu010---producción-del-día)
10. [Configuración de AWS](#configuración-de-aws)

---

## Arquitectura General

### Stack Tecnológico

| Capa | Tecnología | Descripción |
|------|------------|-------------|
| **Frontend** | Angular 20 | Aplicación SPA con componentes standalone |
| **Backend** | AWS Lambda (Python 3.13) | Funciones serverless para lógica de negocio |
| **API** | AWS API Gateway | RESTful API con endpoints HTTP |
| **Base de Datos** | SQL Server RDS | Base de datos relacional en AWS |
| **Autenticación** | JWT | Tokens para autenticación de usuarios |

### Diagrama de Arquitectura

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    Angular      │────▶│  API Gateway    │────▶│  AWS Lambda     │────▶│   SQL Server    │
│    Frontend     │     │  (REST API)     │     │  (Python 3.13)  │     │   RDS           │
└─────────────────┘     └─────────────────┘     └─────────────────┘     └─────────────────┘
                                │
                                ▼
                        https://o1a90x561f.execute-api.us-east-1.amazonaws.com/v1
```

### Roles de Usuario

| ID Perfil | Rol | Permisos |
|-----------|-----|----------|
| 1 | Administrador | Acceso total a todos los datos |
| 2 | Supervisor | Ve datos de su equipo asignado |
| 3 | Ejecutivo | Solo ve sus propios datos |

### Base de Datos: DB_APPCOMERCIAL

**Tablas Principales:**
- `TM_USUARIO` - Usuarios del sistema
- `TM_EMPRESA` - Empresas/Clientes
- `TM_SEGUIMIENTO` - Seguimientos programados
- `TM_INTERACCION` - Registro de interacciones
- `TM_VENTA` - Ventas cerradas
- `TM_NOTIFICACION` - Notificaciones del sistema

---

## HU001 - Búsqueda de Clientes

### Descripción
**Como** ejecutivo comercial, **quiero** buscar clientes por nombre, contacto o teléfono **para** acceder rápidamente a su información.

### Vista en la Aplicación
- **Tab:** BÚSQUEDA
- **Visibilidad:** Todos los roles (Admin, Supervisor, Ejecutivo)

### Componentes

#### Frontend (Angular)
**Archivo:** `src/app/pages/app-comercial/app-comercial.html`

```html
<!-- Campo de búsqueda -->
<input type="text" class="form-control" 
       [(ngModel)]="searchTerm"
       (input)="onSearchInput()"
       placeholder="Buscar por nombre, contacto, teléfono...">

<!-- Filtros adicionales -->
<select [(ngModel)]="selectedCampana" (ngModelChange)="onFilterChange()">
  <option value="">TODOS</option>
  <option *ngFor="let c of campanasDisponibles" [value]="c">{{ c }}</option>
</select>
```

**Archivo:** `src/app/pages/app-comercial/app-comercial.ts`

```typescript
// Método de búsqueda
searchClientes() {
  this.empresaService.searchEmpresas(
    this.searchTerm, 
    this.selectedCampana, 
    this.currentUserId
  ).subscribe({
    next: (response) => {
      if (response.isSuccess) {
        this.empresas = response.data;
      }
    }
  });
}
```

**Archivo:** `src/app/services/empresa.service.ts`

```typescript
searchEmpresas(searchTerm: string, campana: string, userId: number): Observable<ApiResponse<Empresa[]>> {
  const params = new HttpParams()
    .set('search', searchTerm)
    .set('campana', campana)
    .set('userId', userId.toString());
  
  return this.http.get<ApiResponse<Empresa[]>>(`${this.apiUrl}/empresas`, { params });
}
```

#### API Gateway
| Método | Endpoint | Parámetros |
|--------|----------|------------|
| GET | `/empresas` | `search`, `campana`, `userId` |

#### Lambda (Python)
**Archivo:** `lambdas/TB1_busqueda_clientes_lambda.py`

```python
def lambda_handler(event, context):
    query_params = event.get('queryStringParameters', {}) or {}
    search_term = query_params.get('search', '')
    campana = query_params.get('campana', '')
    user_id = int(query_params.get('userId', '1'))
    
    conn = get_connection()
    cursor = conn.cursor()
    
    cursor.execute(
        'EXEC usp_BuscarEmpresas @SearchTerm=?, @Campana=?, @IdUsuario=?',
        (search_term, campana, user_id)
    )
    
    # Procesar resultados...
```

#### Stored Procedure (SQL Server)
**Archivo:** `sql/04_stored_procedures.sql`

```sql
CREATE OR ALTER PROCEDURE usp_BuscarEmpresas
    @SearchTerm NVARCHAR(100) = '',
    @Campana NVARCHAR(50) = '',
    @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IdPerfil INT;
    SELECT @IdPerfil = IDPERFIL FROM TM_USUARIO WHERE IDUSUARIO = @IdUsuario;
    
    SELECT 
        e.IDEMPRESA,
        e.NOMBRECOMERCIAL,
        e.RUC,
        e.TELEFONO,
        e.EMAIL,
        e.DIRECCION,
        e.CAMPANA,
        e.ESTADO
    FROM TM_EMPRESA e
    WHERE e.ACTIVO = 1
      AND (@SearchTerm = '' OR 
           e.NOMBRECOMERCIAL LIKE '%' + @SearchTerm + '%' OR
           e.RUC LIKE '%' + @SearchTerm + '%' OR
           e.TELEFONO LIKE '%' + @SearchTerm + '%')
      AND (@Campana = '' OR e.CAMPANA = @Campana)
      -- Filtro por rol
      AND (
          @IdPerfil = 1 -- Admin ve todo
          OR (@IdPerfil = 2 AND e.IDUSUARIOASIGNADO IN 
              (SELECT IDUSUARIO FROM TM_USUARIO WHERE IDSUPERVISOR = @IdUsuario))
          OR (@IdPerfil = 3 AND e.IDUSUARIOASIGNADO = @IdUsuario)
      )
    ORDER BY e.NOMBRECOMERCIAL;
END;
```

### Flujo de Datos

```
1. Usuario escribe en el campo de búsqueda
   ↓
2. Angular detecta el input y llama a searchClientes()
   ↓
3. EmpresaService hace GET /empresas?search=...&campana=...&userId=...
   ↓
4. API Gateway enruta a TB1_busqueda_clientes_lambda
   ↓
5. Lambda ejecuta usp_BuscarEmpresas con los parámetros
   ↓
6. SQL Server filtra empresas según rol y criterios
   ↓
7. Resultados retornan por la cadena hasta el frontend
   ↓
8. Angular actualiza la tabla de resultados
```

---

## HU002 - Agenda del Día

### Descripción
**Como** ejecutivo comercial, **quiero** ver mi agenda del día **para** conocer mis actividades programadas.

### Vista en la Aplicación
- **Tab:** AGENDA DEL DÍA
- **Visibilidad:** Todos los roles

### Componentes

#### Frontend (Angular)
**Archivo:** `src/app/pages/app-comercial/app-comercial.html`

```html
<!-- Vista de agenda -->
<div *ngIf="getOriginalTabIndex(activeView) === 1">
  <div class="card mb-3" *ngFor="let item of agendaItems">
    <div class="card-body">
      <span class="badge" [style.background-color]="item.COLOR">
        {{ item.TIPOSEGUIMIENTO }}
      </span>
      <h6>{{ item.HORAPROGRAMADA }} - {{ item.NOMBRECOMERCIAL }}</h6>
      <p>{{ item.NOTAS }}</p>
      <span class="badge" [ngClass]="{
        'bg-warning': item.PRIORIDAD === 'ALTA',
        'bg-info': item.PRIORIDAD === 'MEDIA',
        'bg-secondary': item.PRIORIDAD === 'BAJA'
      }">{{ item.PRIORIDAD }}</span>
    </div>
  </div>
</div>
```

**Archivo:** `src/app/pages/app-comercial/app-comercial.ts`

```typescript
loadAgendaDelDia() {
  const today = new Date().toISOString().split('T')[0];
  
  this.dashboardService.getAgenda(today, this.currentUserId).subscribe({
    next: (response) => {
      if (response.isSuccess) {
        this.agendaItems = response.data;
      }
    }
  });
}
```

#### API Gateway
| Método | Endpoint | Parámetros |
|--------|----------|------------|
| GET | `/agenda` | `fecha`, `userId` |

#### Lambda (Python)
**Archivo:** `lambdas/TB1_agenda_dia_lambda.py`

```python
def lambda_handler(event, context):
    query_params = event.get('queryStringParameters', {}) or {}
    fecha = query_params.get('fecha')
    user_id = int(query_params.get('userId', '1'))
    
    cursor.execute(
        'EXEC usp_ObtenerAgendaDia @IdUsuario=?, @Fecha=?',
        (user_id, fecha)
    )
```

#### Stored Procedure
**Archivo:** `sql/04_stored_procedures.sql`

```sql
CREATE OR ALTER PROCEDURE usp_ObtenerAgendaDia
    @IdUsuario INT,
    @Fecha DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IdPerfil INT;
    SELECT @IdPerfil = IDPERFIL FROM TM_USUARIO WHERE IDUSUARIO = @IdUsuario;
    
    SELECT 
        s.IDSEGUIMIENTO,
        s.FECHAPROGRAMADA,
        s.HORAPROGRAMADA,
        s.PRIORIDAD,
        s.ESTADO,
        s.NOTAS,
        e.NOMBRECOMERCIAL,
        ts.NOMBRE AS TIPOSEGUIMIENTO,
        ts.COLOR
    FROM TM_SEGUIMIENTO s
    INNER JOIN TM_EMPRESA e ON s.IDEMPRESA = e.IDEMPRESA
    INNER JOIN TM_TIPOSEGUIMIENTO ts ON s.IDTIPOSEGUIMIENTO = ts.IDTIPOSEGUIMIENTO
    WHERE s.FECHAPROGRAMADA = @Fecha
      AND s.ACTIVO = 1
      AND (
          @IdPerfil = 1
          OR (@IdPerfil = 2 AND s.IDUSUARIOASIGNADO IN 
              (SELECT IDUSUARIO FROM TM_USUARIO WHERE IDSUPERVISOR = @IdUsuario))
          OR (@IdPerfil = 3 AND s.IDUSUARIOASIGNADO = @IdUsuario)
      )
    ORDER BY s.HORAPROGRAMADA;
END;
```

### Códigos de Color por Tipo de Seguimiento

| Tipo | Color | Código Hex |
|------|-------|------------|
| Llamada Fría | Azul | #3498db |
| Llamada Seguimiento | Verde | #2ecc71 |
| Visita Presencial | Rojo | #e74c3c |
| Reunión Virtual | Morado | #9b59b6 |
| Envío Propuesta | Naranja | #f39c12 |
| Cierre Venta | Turquesa | #1abc9c |
| Post-Venta | Gris | #34495e |
| Reactivación | Naranja Oscuro | #e67e22 |

---

## HU003 - Dashboard Supervisor

### Descripción
**Como** supervisor, **quiero** ver un dashboard con métricas de mi equipo **para** monitorear el rendimiento.

### Vista en la Aplicación
- **Tab:** DASHBOARD
- **Visibilidad:** Admin y Supervisor

### Componentes

#### Frontend (Angular)

```html
<!-- Métricas del equipo -->
<div class="row">
  <div class="col-md-3">
    <div class="card bg-primary text-white">
      <h6>Total Equipo</h6>
      <h3>{{ dashboardData?.TotalEquipo || 0 }}</h3>
    </div>
  </div>
  <div class="col-md-3">
    <div class="card bg-success text-white">
      <h6>Seguimientos Completados</h6>
      <h3>{{ dashboardData?.SeguimientosCompletados || 0 }}</h3>
    </div>
  </div>
  <!-- ... más métricas -->
</div>
```

#### API Gateway
| Método | Endpoint | Parámetros |
|--------|----------|------------|
| GET | `/dashboard` | `fecha`, `userId` |

#### Lambda
**Archivo:** `lambdas/TB1_dashboard_supervisor_lambda.py`

```python
def lambda_handler(event, context):
    query_params = event.get('queryStringParameters', {}) or {}
    fecha = query_params.get('fecha')
    user_id = int(query_params.get('userId', '1'))
    
    cursor.execute(
        'EXEC usp_ObtenerDashboardSupervisor @IdSupervisor=?, @FechaInicio=?, @FechaFin=?',
        (user_id, fecha, fecha)
    )
    
    # Retorna objeto único con métricas
    row = cursor.fetchone()
    data = {
        'PROGRAMADOS_SEMANA': row[0],
        'COMPLETADOS_SEMANA': row[1],
        'PENDIENTES_SEMANA': row[2],
        'CANCELADOS_SEMANA': row[3]
    }
```

#### Stored Procedure

```sql
CREATE OR ALTER PROCEDURE usp_ObtenerDashboardSupervisor
    @IdSupervisor INT,
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Determinar rol del usuario
    DECLARE @IdPerfil INT;
    SELECT @IdPerfil = IDPERFIL FROM TM_USUARIO WHERE IDUSUARIO = @IdSupervisor;
    
    -- Obtener miembros del equipo según rol
    DECLARE @TeamMembers TABLE (IDUSUARIO INT);
    
    IF @IdPerfil = 1
        INSERT INTO @TeamMembers SELECT IDUSUARIO FROM TM_USUARIO WHERE ACTIVO = 1;
    ELSE IF @IdPerfil = 2
        INSERT INTO @TeamMembers SELECT IDUSUARIO FROM TM_USUARIO 
        WHERE IDSUPERVISOR = @IdSupervisor AND ACTIVO = 1;
    ELSE
        INSERT INTO @TeamMembers VALUES (@IdSupervisor);
    
    -- Retornar métricas
    SELECT
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO s 
         WHERE s.IDUSUARIOASIGNADO IN (SELECT IDUSUARIO FROM @TeamMembers)
           AND s.FECHAPROGRAMADA BETWEEN @FechaInicio AND @FechaFin) AS PROGRAMADOS_SEMANA,
        -- ... más métricas
END;
```

---

## HU004 - Pendientes Acumulados

### Descripción
**Como** ejecutivo, **quiero** ver mis seguimientos pendientes acumulados **para** priorizar mi trabajo.

### Vista en la Aplicación
- **Tab:** PENDIENTES ACUMULADOS
- **Visibilidad:** Todos los roles

### Componentes

#### Frontend

```html
<!-- Filtros -->
<select [(ngModel)]="filterPrioridad" (ngModelChange)="applyPendientesFilters()">
  <option value="">Todas</option>
  <option value="ALTA">Alta</option>
  <option value="MEDIA">Media</option>
  <option value="BAJA">Baja</option>
</select>

<!-- Tabla de pendientes -->
<table class="table">
  <tr *ngFor="let item of filteredPendientes">
    <td>{{ item.NOMBRECOMERCIAL }}</td>
    <td>{{ item.FECHAPROGRAMADA | date:'dd/MM/yyyy' }}</td>
    <td><span class="badge">{{ item.PRIORIDAD }}</span></td>
    <td>{{ item.DIAS_ATRASO }} días</td>
  </tr>
</table>
```

#### API Gateway
| Método | Endpoint | Parámetros |
|--------|----------|------------|
| GET | `/pendientes` | `tipo=acumulados`, `userId` |

#### Lambda
**Archivo:** `lambdas/TB1_pendientes_acumulados_lambda.py`

```python
cursor.execute(
    'EXEC usp_ObtenerPendientesAcumulados @IdUsuario=?',
    (user_id,)
)
```

#### Stored Procedure

```sql
CREATE OR ALTER PROCEDURE usp_ObtenerPendientesAcumulados
    @IdUsuario INT
AS
BEGIN
    SELECT 
        s.IDSEGUIMIENTO,
        e.NOMBRECOMERCIAL,
        s.FECHAPROGRAMADA,
        s.PRIORIDAD,
        DATEDIFF(DAY, s.FECHAPROGRAMADA, GETDATE()) AS DIAS_ATRASO,
        s.NOTAS
    FROM TM_SEGUIMIENTO s
    INNER JOIN TM_EMPRESA e ON s.IDEMPRESA = e.IDEMPRESA
    WHERE s.ESTADO = 'PENDIENTE'
      AND s.FECHAPROGRAMADA < CAST(GETDATE() AS DATE)
      AND s.ACTIVO = 1
      -- Filtro por rol...
    ORDER BY s.PRIORIDAD DESC, s.FECHAPROGRAMADA;
END;
```

---

## HU005 - Pendientes Olvidados

### Descripción
**Como** supervisor, **quiero** ver seguimientos olvidados (más de 7 días sin atención) **para** tomar acciones correctivas.

### Vista en la Aplicación
- **Tab:** PENDIENTES OLVIDADOS
- **Visibilidad:** Admin y Supervisor

### Diferencia con Pendientes Acumulados
- **Acumulados:** Pendientes con 1+ días de atraso
- **Olvidados:** Pendientes con 7+ días de atraso

#### Stored Procedure

```sql
CREATE OR ALTER PROCEDURE usp_ObtenerPendientesOlvidados
    @IdUsuario INT
AS
BEGIN
    SELECT 
        s.IDSEGUIMIENTO,
        e.NOMBRECOMERCIAL,
        u.NOMBRE AS EJECUTIVO_ASIGNADO,
        s.FECHAPROGRAMADA,
        DATEDIFF(DAY, s.FECHAPROGRAMADA, GETDATE()) AS DIAS_OLVIDADO,
        s.PRIORIDAD
    FROM TM_SEGUIMIENTO s
    INNER JOIN TM_EMPRESA e ON s.IDEMPRESA = e.IDEMPRESA
    INNER JOIN TM_USUARIO u ON s.IDUSUARIOASIGNADO = u.IDUSUARIO
    WHERE s.ESTADO = 'PENDIENTE'
      AND DATEDIFF(DAY, s.FECHAPROGRAMADA, GETDATE()) >= 7  -- 7+ días
      AND s.ACTIVO = 1
    ORDER BY DIAS_OLVIDADO DESC;
END;
```

---

## HU006 - Monitoreo / Calendario de Supervisión

### Descripción
**Como** supervisor, **quiero** ver un calendario semanal con todas las citas del equipo **para** monitorear la actividad.

### Vista en la Aplicación
- **Tab:** MONITOREO
- **Visibilidad:** Admin y Supervisor

### Componentes

#### Frontend

```html
<!-- Métricas semanales -->
<div class="row mb-4">
  <div class="col-md-3">
    <div class="card bg-primary text-white">
      <h6>PROGRAMADOS SEMANA</h6>
      <h3>{{ dashboardMetrics?.PROGRAMADOS_SEMANA || 0 }}</h3>
    </div>
  </div>
  <div class="col-md-3">
    <div class="card bg-success text-white">
      <h6>COMPLETADOS</h6>
      <h3>{{ dashboardMetrics?.COMPLETADOS_SEMANA || 0 }}</h3>
    </div>
  </div>
  <!-- ... PENDIENTES, CANCELADOS -->
</div>

<!-- Calendario semanal -->
<table class="table table-bordered">
  <thead>
    <tr>
      <th *ngFor="let day of weekDays">{{ day.name }}<br>{{ day.date }}</th>
    </tr>
  </thead>
  <tbody>
    <tr *ngFor="let hour of hours">
      <td *ngFor="let day of weekDays">
        <div *ngFor="let event of getEventsForSlot(day.date, hour)"
             class="calendar-event"
             [style.background-color]="event.COLOR">
          {{ event.HORAPROGRAMADA }} - {{ event.NOMBRECOMERCIAL }}
        </div>
      </td>
    </tr>
  </tbody>
</table>
```

#### API Gateway
| Método | Endpoint | Parámetros |
|--------|----------|------------|
| GET | `/calendario` | `fechaIni`, `fechaFin`, `userId` |
| GET | `/dashboard` | `fecha`, `userId` |

#### Lambda - Calendario
**Archivo:** `lambdas/TB1_calendario_lambda.py`

```python
cursor.execute(
    'EXEC usp_ObtenerCalendarioSemanal @IdUsuario=?, @FechaInicio=?, @FechaFin=?',
    (user_id, fecha_inicio, fecha_fin)
)
```

#### Stored Procedure

```sql
CREATE OR ALTER PROCEDURE usp_ObtenerCalendarioSemanal
    @IdUsuario INT,
    @FechaInicio DATE,
    @FechaFin DATE
AS
BEGIN
    SELECT 
        s.IDSEGUIMIENTO,
        s.FECHAPROGRAMADA,
        s.HORAPROGRAMADA,
        s.PRIORIDAD,
        s.ESTADO,
        s.NOTAS,
        e.IDEMPRESA,
        e.NOMBRECOMERCIAL,
        u.IDUSUARIO,
        u.NOMBRE AS NombreEjecutivo,
        ts.NOMBRE AS TIPOSEGUIMIENTO,
        ts.COLOR
    FROM TM_SEGUIMIENTO s
    INNER JOIN TM_EMPRESA e ON s.IDEMPRESA = e.IDEMPRESA
    INNER JOIN TM_USUARIO u ON s.IDUSUARIOASIGNADO = u.IDUSUARIO
    INNER JOIN TM_TIPOSEGUIMIENTO ts ON s.IDTIPOSEGUIMIENTO = ts.IDTIPOSEGUIMIENTO
    WHERE s.FECHAPROGRAMADA BETWEEN @FechaInicio AND @FechaFin
      AND s.ACTIVO = 1
      -- Filtro por rol...
    ORDER BY s.FECHAPROGRAMADA, s.HORAPROGRAMADA;
END;
```

---

## HU009 - Ventas Cerradas

### Descripción
**Como** supervisor, **quiero** ver un resumen de ventas cerradas en la semana **para** analizar el rendimiento comercial.

### Vista en la Aplicación
- **Tab:** VENTAS CERRADAS
- **Visibilidad:** Admin y Supervisor

### Componentes

#### Frontend

```html
<!-- Métricas -->
<div class="row">
  <div class="col-md-4">
    <div class="card bg-success text-white">
      <h6>Monto Acumulado Semanal</h6>
      <h3>S/ {{ cerradosData?.metricas?.MONTO_TOTAL | number:'1.2-2' }}</h3>
    </div>
  </div>
  <div class="col-md-4">
    <div class="card bg-primary text-white">
      <h6>Contratos Cerrados</h6>
      <h3>{{ cerradosData?.metricas?.TOTAL_CERRADOS }}</h3>
    </div>
  </div>
  <div class="col-md-4">
    <div class="card bg-info text-white">
      <h6>Días Promedio de Cierre</h6>
      <h3>{{ cerradosData?.metricas?.DIAS_PROMEDIO_CIERRE }} días</h3>
    </div>
  </div>
</div>

<!-- Gráfico de rendimiento diario -->
<div class="simple-chart">
  <div *ngFor="let dia of cerradosData?.porDia">
    <div class="bg-primary" [style.height.px]="getBarHeight(dia.CANTIDAD)"></div>
    <span>{{ dia.DIA_SEMANA }}</span>
    <span>{{ dia.CANTIDAD }}</span>
  </div>
</div>

<!-- Historial reciente -->
<table class="table">
  <tr *ngFor="let item of cerradosData?.historial">
    <td>{{ item.EMPRESA }}</td>
    <td>{{ item.SERVICIO }}</td>
    <td>S/ {{ item.MONTO | number:'1.2-2' }}</td>
    <td>{{ item.FECHA }}</td>
  </tr>
</table>
```

#### API Gateway
| Método | Endpoint | Parámetros |
|--------|----------|------------|
| GET | `/cerrados` | `fechaIni`, `fechaFin`, `userId` |

#### Lambda
**Archivo:** `lambdas/TB1_cerrados_semana_lambda.py`

```python
def lambda_handler(event, context):
    # Ejecutar SP que retorna 3 result sets
    cursor.execute(
        'EXEC usp_ObtenerCerradosSemana @IdUsuario=?, @FechaInicio=?, @FechaFin=?',
        (user_id, fecha_inicio, fecha_fin)
    )
    
    # Result Set 1: Historial
    historial = fetch_result_set(cursor)
    
    # Result Set 2: Métricas
    cursor.nextset()
    stats = fetch_result_set(cursor)
    metricas = {
        'TOTAL_CERRADOS': stats[0].get('TOTAL_CERRADOS', 0),
        'MONTO_TOTAL': stats[0].get('MontoTotal', 0),
        'DIAS_PROMEDIO_CIERRE': stats[0].get('DiasPromedioCierre', 0)
    }
    
    # Result Set 3: Por día (para gráfico)
    cursor.nextset()
    por_dia = fetch_result_set(cursor)
    
    return {
        'metricas': metricas,
        'porDia': por_dia,
        'historial': historial
    }
```

#### Stored Procedure

```sql
CREATE OR ALTER PROCEDURE usp_ObtenerCerradosSemana
    @IdUsuario INT,
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL
AS
BEGIN
    -- RESULT SET 1: Historial Reciente
    SELECT TOP 10
        e.NOMBRECOMERCIAL AS EMPRESA,
        ISNULL(v.PRODUCTO, 'Servicio Estándar') AS SERVICIO,
        v.MONTO,
        FORMAT(v.FECHAVENTA, 'yyyy-MM-dd') AS FECHA
    FROM TM_VENTA v
    INNER JOIN TM_EMPRESA e ON v.IDEMPRESA = e.IDEMPRESA
    WHERE v.IDUSUARIO IN (SELECT IDUSUARIO FROM @TeamMembers)
    ORDER BY v.FECHAVENTA DESC;
    
    -- RESULT SET 2: Métricas
    SELECT
        COUNT(*) AS TOTAL_CERRADOS,
        SUM(v.MONTO) AS MontoTotal,
        AVG(DATEDIFF(DAY, v.FECHACREA, v.FECHAVENTA)) AS DiasPromedioCierre
    FROM TM_VENTA v
    WHERE v.FECHAVENTA BETWEEN @FechaInicio AND @FechaFin;
    
    -- RESULT SET 3: Por día (para gráfico)
    SELECT 
        LEFT(DATENAME(WEEKDAY, FECHA), 3) AS DIA_SEMANA,
        FORMAT(FECHA, 'yyyy-MM-dd') AS FECHA,
        COUNT(IDVENTA) AS CANTIDAD
    FROM ...
    GROUP BY FECHA;
END;
```

---

## HU010 - Producción del Día

### Descripción
**Como** supervisor, **quiero** ver la producción diaria de mi equipo **para** evaluar el rendimiento en tiempo real.

### Vista en la Aplicación
- **Tab:** PRODUCCIÓN
- **Visibilidad:** Admin y Supervisor

### Componentes

#### Frontend

```html
<!-- Lista de ejecutivos con su producción -->
<div class="row">
  <div class="col-md-4" *ngFor="let user of prodDiaUsers">
    <div class="card">
      <div class="card-body">
        <h6>{{ user.nombre }}</h6>
        <div class="d-flex justify-content-between">
          <span>Contactos: {{ user.contactos }}</span>
          <span>Pendientes: {{ user.pendientes }}</span>
          <span>Total: {{ user.total }}</span>
        </div>
      </div>
    </div>
  </div>
</div>
```

#### API Gateway
| Método | Endpoint | Parámetros |
|--------|----------|------------|
| GET | `/produccion` | `fecha`, `userId` |

#### Lambda
**Archivo:** `lambdas/TB1_produccion_diaria_lambda.py`

```python
cursor.execute(
    'EXEC usp_ObtenerProduccionDiaria @IdUsuario=?, @Fecha=?',
    (user_id, fecha)
)
```

#### Stored Procedure

```sql
CREATE OR ALTER PROCEDURE usp_ObtenerProduccionDiaria
    @IdUsuario INT,
    @Fecha DATE = NULL
AS
BEGIN
    SELECT
        u.IDUSUARIO,
        u.USUARIO,
        u.NOMBRE,
        (SELECT COUNT(*) FROM TM_INTERACCION i 
         WHERE i.IDUSUARIO = u.IDUSUARIO 
           AND CAST(i.FECHAINTERACCION AS DATE) = @Fecha) AS CONTACTOS_DEL_DIA,
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO s 
         WHERE s.IDUSUARIOASIGNADO = u.IDUSUARIO 
           AND s.ESTADO = 'PENDIENTE'
           AND s.FECHAPROGRAMADA = @Fecha) AS PENDIENTES_DEL_DIA,
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO s 
         WHERE s.IDUSUARIOASIGNADO = u.IDUSUARIO 
           AND s.FECHAPROGRAMADA = @Fecha) AS TOTAL_DEL_DIA
    FROM TM_USUARIO u
    WHERE u.ACTIVO = 1
      AND u.IDUSUARIO IN (SELECT IDUSUARIO FROM @TeamMembers)
    ORDER BY CONTACTOS_DEL_DIA DESC;
END;
```

---

## Configuración de AWS

### API Gateway

**Base URL:** `https://o1a90x561f.execute-api.us-east-1.amazonaws.com/v1`

#### Endpoints Configurados

| Método | Recurso | Lambda | Descripción |
|--------|---------|--------|-------------|
| POST | /login | TB1_login_lambda | Autenticación |
| GET | /empresas | TB1_busqueda_clientes_lambda | HU001 |
| GET | /agenda | TB1_agenda_dia_lambda | HU002 |
| GET | /dashboard | TB1_dashboard_supervisor_lambda | HU003/HU006 |
| GET | /pendientes | TB1_pendientes_lambda | HU004/HU005 |
| GET | /calendario | TB1_calendario_lambda | HU006 |
| GET | /cerrados | TB1_cerrados_semana_lambda | HU009 |
| GET | /produccion | TB1_produccion_diaria_lambda | HU010 |

### Lambda Layer

**ARN:** `arn:aws:lambda:us-east-1:411014146872:layer:pyodbc313:1`

Contiene:
- pyodbc para conexión a SQL Server
- ODBC Driver 18 for SQL Server

### Variables de Entorno Lambda

```
DB_HOST=database-1.c9ywsse2shj2.us-east-1.rds.amazonaws.com
DB_NAME=DB_APPCOMERCIAL
DB_USER=admin
DB_PASSWORD=***
```

### Configuración CORS

Todas las Lambdas incluyen headers CORS:

```python
def get_cors_headers():
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    }
```

---

## Estructura de Archivos del Proyecto

```
TrabajoFinal-Grupo3/
├── docs/
│   ├── GUIA_HISTORIAS_USUARIO.md    # Esta documentación
│   └── diagrams/                     # Diagramas UML
├── lambdas/
│   ├── TB1_login_lambda.py
│   ├── TB1_busqueda_clientes_lambda.py
│   ├── TB1_agenda_dia_lambda.py
│   ├── TB1_dashboard_supervisor_lambda.py
│   ├── TB1_pendientes_lambda.py
│   ├── TB1_calendario_lambda.py
│   ├── TB1_cerrados_semana_lambda.py
│   └── TB1_produccion_diaria_lambda.py
├── sql/
│   ├── 01_create_database.sql
│   ├── 02_create_tables.sql
│   ├── 03_insert_data.sql
│   ├── 04_stored_procedures.sql
│   ├── 05_sample_data.sql
│   └── 13_fix_monitoreo_cerrados.sql
└── frontend/                         # Angular project
    ├── src/
    │   ├── app/
    │   │   ├── pages/
    │   │   │   └── app-comercial/
    │   │   └── services/
    │   └── environments/
    └── angular.json
```

---

## Resumen de Integración

### Flujo General de Datos

```
┌──────────────────────────────────────────────────────────────────────────┐
│                              FRONTEND (Angular)                          │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                  │
│  │ Components  │───▶│  Services   │───▶│ HttpClient  │                  │
│  └─────────────┘    └─────────────┘    └─────────────┘                  │
└──────────────────────────────────────────│───────────────────────────────┘
                                           │
                                           ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                           AWS API GATEWAY                                │
│  GET /empresas  │  GET /agenda  │  GET /dashboard  │  GET /cerrados     │
└──────────────────────────────────────────│───────────────────────────────┘
                                           │
                                           ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                           AWS LAMBDA (Python 3.13)                       │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  - Validación de parámetros                                      │    │
│  │  - Conexión a base de datos                                      │    │
│  │  - Ejecución de stored procedures                                │    │
│  │  - Formateo de respuesta JSON                                    │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────│───────────────────────────────┘
                                           │
                                           ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                           SQL SERVER RDS                                 │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Stored Procedures con lógica de negocio y filtros por rol      │    │
│  │  - usp_BuscarEmpresas                                            │    │
│  │  - usp_ObtenerAgendaDia                                          │    │
│  │  - usp_ObtenerDashboardSupervisor                                │    │
│  │  - usp_ObtenerCerradosSemana                                     │    │
│  │  - usp_ObtenerProduccionDiaria                                   │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────┘
```

---

**Documento generado:** Diciembre 2025  
**Proyecto:** App Comercial - Sistema de Gestión de Seguimientos  
**Equipo:** Grupo 3 - UPC
