/* =====================================================================
   DB_APPCOMERCIAL - PART 4: STORED PROCEDURES
   Version: 2.0
   Date: December 10, 2025
   
   Execute AFTER: 03_create_indexes.sql
   ===================================================================== */

USE DB_APPCOMERCIAL;
GO

PRINT '=== Creating Stored Procedures ===';
GO

-- =====================================================================
-- HU001: User Authentication
-- =====================================================================

-- usp_ValidarLogin - Validates user credentials
CREATE OR ALTER PROCEDURE usp_ValidarLogin
    @LoginUsuario NVARCHAR(64),
    @Clave NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        u.IDUSUARIO,
        u.LOGINUSUARIO,
        u.NOMBRES,
        u.APELLIDOPATERNO,
        u.APELLIDOMATERNO,
        u.EMAIL,
        u.TELEFONO,
        p.IDPERFIL,
        p.NOMBREPERFIL,
        u.IDSUPERVISOR
    FROM TM_USUARIO u
    INNER JOIN TM_PERFIL p ON u.IDPERFIL = p.IDPERFIL
    WHERE u.LOGINUSUARIO = @LoginUsuario 
      AND u.CLAVE = @Clave 
      AND u.ACTIVO = 1
      AND p.ACTIVO = 1;
END;
GO
PRINT '  Created: usp_ValidarLogin (HU001)';
GO

-- =====================================================================
-- HU002: Daily Agenda
-- =====================================================================

-- usp_ObtenerAgendaDia - Gets follow-ups scheduled for a specific date
CREATE OR ALTER PROCEDURE usp_ObtenerAgendaDia
    @IdUsuario INT,
    @Fecha DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        s.IDSEGUIMIENTO,
        s.FECHAPROGRAMADA,
        s.HORAPROGRAMADA,
        s.PRIORIDAD,
        s.ESTADO,
        s.NOTAS,
        e.IDEMPRESA,
        e.NOMBRECOMERCIAL,
        e.CONTACTO_NOMBRE,
        e.CONTACTO_TELEFONO,
        e.CONTACTO_EMAIL,
        st.IDTIPOSEGUIMIENTO,
        st.NOMBRE AS TIPOSEGUIMIENTO,
        st.COLOR
    FROM TM_SEGUIMIENTO s
    INNER JOIN TM_EMPRESA e ON s.IDEMPRESA = e.IDEMPRESA
    LEFT JOIN TM_SEGUIMIENTO_TIPO st ON s.IDTIPOSEGUIMIENTO = st.IDTIPOSEGUIMIENTO
    WHERE s.IDUSUARIOASIGNADO = @IdUsuario
      AND s.FECHAPROGRAMADA = @Fecha
      AND s.ACTIVO = 1
    ORDER BY 
        CASE s.PRIORIDAD WHEN 'ALTA' THEN 1 WHEN 'MEDIA' THEN 2 ELSE 3 END,
        s.HORAPROGRAMADA;
END;
GO
PRINT '  Created: usp_ObtenerAgendaDia (HU002)';
GO

-- =====================================================================
-- HU003: Supervisor Dashboard
-- =====================================================================

-- usp_ObtenerDashboardSupervisor - Gets dashboard metrics for supervisor
CREATE OR ALTER PROCEDURE usp_ObtenerDashboardSupervisor
    @IdSupervisor INT,
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Default to current month if dates not provided
    IF @FechaInicio IS NULL SET @FechaInicio = DATEADD(DAY, 1-DAY(GETDATE()), CAST(GETDATE() AS DATE));
    IF @FechaFin IS NULL SET @FechaFin = EOMONTH(GETDATE());
    
    -- Get team member IDs
    DECLARE @TeamMembers TABLE (IDUSUARIO INT);
    INSERT INTO @TeamMembers
    SELECT IDUSUARIO FROM TM_USUARIO WHERE IDSUPERVISOR = @IdSupervisor AND ACTIVO = 1;
    
    -- Return metrics
    SELECT
        -- Team size
        (SELECT COUNT(*) FROM @TeamMembers) AS TotalEquipo,
        
        -- Follow-up counts
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO s 
         WHERE s.IDUSUARIOASIGNADO IN (SELECT IDUSUARIO FROM @TeamMembers)
           AND s.FECHAPROGRAMADA BETWEEN @FechaInicio AND @FechaFin
           AND s.ACTIVO = 1) AS TotalSeguimientos,
        
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO s 
         WHERE s.IDUSUARIOASIGNADO IN (SELECT IDUSUARIO FROM @TeamMembers)
           AND s.ESTADO = 'PENDIENTE'
           AND s.FECHAPROGRAMADA BETWEEN @FechaInicio AND @FechaFin
           AND s.ACTIVO = 1) AS SeguimientosPendientes,
        
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO s 
         WHERE s.IDUSUARIOASIGNADO IN (SELECT IDUSUARIO FROM @TeamMembers)
           AND s.ESTADO = 'COMPLETADO'
           AND s.FECHAPROGRAMADA BETWEEN @FechaInicio AND @FechaFin
           AND s.ACTIVO = 1) AS SeguimientosCompletados,
        
        -- Overdue count
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO s 
         WHERE s.IDUSUARIOASIGNADO IN (SELECT IDUSUARIO FROM @TeamMembers)
           AND s.ESTADO = 'PENDIENTE'
           AND s.FECHAPROGRAMADA < CAST(GETDATE() AS DATE)
           AND s.ACTIVO = 1) AS SeguimientosAtrasados,
        
        -- Sales metrics
        (SELECT ISNULL(SUM(v.MONTO), 0) FROM TM_VENTA v 
         WHERE v.IDUSUARIO IN (SELECT IDUSUARIO FROM @TeamMembers)
           AND v.FECHAVENTA BETWEEN @FechaInicio AND @FechaFin
           AND v.ACTIVO = 1) AS VentasTotales,
        
        (SELECT COUNT(*) FROM TM_VENTA v 
         WHERE v.IDUSUARIO IN (SELECT IDUSUARIO FROM @TeamMembers)
           AND v.FECHAVENTA BETWEEN @FechaInicio AND @FechaFin
           AND v.ACTIVO = 1) AS CantidadVentas;
    
    -- Return team member details
    SELECT 
        u.IDUSUARIO,
        u.NOMBRES + ' ' + u.APELLIDOPATERNO AS NombreCompleto,
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO s 
         WHERE s.IDUSUARIOASIGNADO = u.IDUSUARIO 
           AND s.ESTADO = 'PENDIENTE'
           AND s.FECHAPROGRAMADA BETWEEN @FechaInicio AND @FechaFin
           AND s.ACTIVO = 1) AS Pendientes,
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO s 
         WHERE s.IDUSUARIOASIGNADO = u.IDUSUARIO 
           AND s.ESTADO = 'COMPLETADO'
           AND s.FECHAPROGRAMADA BETWEEN @FechaInicio AND @FechaFin
           AND s.ACTIVO = 1) AS Completados,
        (SELECT ISNULL(SUM(v.MONTO), 0) FROM TM_VENTA v 
         WHERE v.IDUSUARIO = u.IDUSUARIO
           AND v.FECHAVENTA BETWEEN @FechaInicio AND @FechaFin
           AND v.ACTIVO = 1) AS Ventas
    FROM TM_USUARIO u
    WHERE u.IDUSUARIO IN (SELECT IDUSUARIO FROM @TeamMembers)
    ORDER BY Completados DESC;
END;
GO
PRINT '  Created: usp_ObtenerDashboardSupervisor (HU003)';
GO

-- =====================================================================
-- HU004: Forgotten Follow-ups
-- =====================================================================

-- usp_ObtenerPendientesOlvidados - Gets overdue follow-ups
CREATE OR ALTER PROCEDURE usp_ObtenerPendientesOlvidados
    @IdUsuario INT,
    @DiasAntiguedad INT = 7
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        s.IDSEGUIMIENTO,
        s.FECHAPROGRAMADA,
        DATEDIFF(DAY, s.FECHAPROGRAMADA, GETDATE()) AS DiasAtraso,
        s.PRIORIDAD,
        s.ESTADO,
        s.NOTAS,
        e.IDEMPRESA,
        e.NOMBRECOMERCIAL,
        e.CONTACTO_NOMBRE,
        e.CONTACTO_TELEFONO,
        st.NOMBRE AS TIPOSEGUIMIENTO,
        st.COLOR
    FROM TM_SEGUIMIENTO s
    INNER JOIN TM_EMPRESA e ON s.IDEMPRESA = e.IDEMPRESA
    LEFT JOIN TM_SEGUIMIENTO_TIPO st ON s.IDTIPOSEGUIMIENTO = st.IDTIPOSEGUIMIENTO
    WHERE s.IDUSUARIOASIGNADO = @IdUsuario
      AND s.ESTADO = 'PENDIENTE'
      AND s.FECHAPROGRAMADA < CAST(GETDATE() AS DATE)
      AND DATEDIFF(DAY, s.FECHAPROGRAMADA, GETDATE()) >= @DiasAntiguedad
      AND s.ACTIVO = 1
    ORDER BY s.FECHAPROGRAMADA ASC;
END;
GO
PRINT '  Created: usp_ObtenerPendientesOlvidados (HU004)';
GO

-- =====================================================================
-- HU005: Accumulated Pending
-- =====================================================================

-- usp_ObtenerPendientesAcumulados - Gets all pending follow-ups
CREATE OR ALTER PROCEDURE usp_ObtenerPendientesAcumulados
    @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        s.IDSEGUIMIENTO,
        s.FECHAPROGRAMADA,
        DATEDIFF(DAY, s.FECHAPROGRAMADA, GETDATE()) AS DiasAcumulado,
        s.PRIORIDAD,
        s.ESTADO,
        s.NOTAS,
        e.IDEMPRESA,
        e.NOMBRECOMERCIAL,
        e.CONTACTO_NOMBRE,
        e.CONTACTO_TELEFONO,
        st.NOMBRE AS TIPOSEGUIMIENTO,
        st.COLOR,
        CASE 
            WHEN s.FECHAPROGRAMADA < CAST(GETDATE() AS DATE) THEN 'ATRASADO'
            WHEN s.FECHAPROGRAMADA = CAST(GETDATE() AS DATE) THEN 'HOY'
            ELSE 'FUTURO'
        END AS EstatusFecha
    FROM TM_SEGUIMIENTO s
    INNER JOIN TM_EMPRESA e ON s.IDEMPRESA = e.IDEMPRESA
    LEFT JOIN TM_SEGUIMIENTO_TIPO st ON s.IDTIPOSEGUIMIENTO = st.IDTIPOSEGUIMIENTO
    WHERE s.IDUSUARIOASIGNADO = @IdUsuario
      AND s.ESTADO = 'PENDIENTE'
      AND s.ACTIVO = 1
    ORDER BY s.FECHAPROGRAMADA ASC;
END;
GO
PRINT '  Created: usp_ObtenerPendientesAcumulados (HU005)';
GO

-- =====================================================================
-- HU006: Supervisor Calendar
-- =====================================================================

-- usp_ObtenerCalendarioSupervisor - Gets team calendar view
CREATE OR ALTER PROCEDURE usp_ObtenerCalendarioSupervisor
    @IdSupervisor INT,
    @FechaInicio DATE,
    @FechaFin DATE
AS
BEGIN
    SET NOCOUNT ON;
    
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
        u.NOMBRES + ' ' + u.APELLIDOPATERNO AS NombreEjecutivo,
        st.NOMBRE AS TIPOSEGUIMIENTO,
        st.COLOR
    FROM TM_SEGUIMIENTO s
    INNER JOIN TM_EMPRESA e ON s.IDEMPRESA = e.IDEMPRESA
    INNER JOIN TM_USUARIO u ON s.IDUSUARIOASIGNADO = u.IDUSUARIO
    LEFT JOIN TM_SEGUIMIENTO_TIPO st ON s.IDTIPOSEGUIMIENTO = st.IDTIPOSEGUIMIENTO
    WHERE u.IDSUPERVISOR = @IdSupervisor
      AND s.FECHAPROGRAMADA BETWEEN @FechaInicio AND @FechaFin
      AND s.ACTIVO = 1
    ORDER BY s.FECHAPROGRAMADA, s.HORAPROGRAMADA;
END;
GO
PRINT '  Created: usp_ObtenerCalendarioSupervisor (HU006)';
GO

-- =====================================================================
-- HU007: Notifications
-- =====================================================================

-- usp_ObtenerNotificaciones - Gets user notifications
CREATE OR ALTER PROCEDURE usp_ObtenerNotificaciones
    @IdUsuario INT,
    @SoloNoLeidas BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        n.IDNOTIFICACION,
        n.TITULO,
        n.MENSAJE,
        n.TIPO,
        n.LEIDA,
        n.FECHACREACION,
        n.FECHALEIDA,
        n.TIPOENTIDAD,
        n.IDREFERENCIAENTIDAD
    FROM TM_NOTIFICACION n
    WHERE n.IDUSUARIO = @IdUsuario
      AND n.ACTIVO = 1
      AND (@SoloNoLeidas = 0 OR n.LEIDA = 0)
    ORDER BY n.FECHACREACION DESC;
    
    -- Return unread count
    SELECT COUNT(*) AS NoLeidas
    FROM TM_NOTIFICACION
    WHERE IDUSUARIO = @IdUsuario AND LEIDA = 0 AND ACTIVO = 1;
END;
GO
PRINT '  Created: usp_ObtenerNotificaciones (HU007)';
GO

-- usp_MarcarNotificacionLeida - Marks notification as read
CREATE OR ALTER PROCEDURE usp_MarcarNotificacionLeida
    @IdNotificacion INT,
    @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE TM_NOTIFICACION
    SET LEIDA = 1,
        FECHALEIDA = GETDATE()
    WHERE IDNOTIFICACION = @IdNotificacion
      AND IDUSUARIO = @IdUsuario
      AND ACTIVO = 1;
    
    SELECT @@ROWCOUNT AS Affected;
END;
GO
PRINT '  Created: usp_MarcarNotificacionLeida (HU007)';
GO

-- usp_CrearNotificacion - Creates a new notification
CREATE OR ALTER PROCEDURE usp_CrearNotificacion
    @IdUsuario INT,
    @Titulo NVARCHAR(200),
    @Mensaje NVARCHAR(500) = NULL,
    @Tipo NVARCHAR(50) = 'INFO',
    @TipoEntidad NVARCHAR(50) = NULL,
    @IdReferenciaEntidad INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO TM_NOTIFICACION (IDUSUARIO, TITULO, MENSAJE, TIPO, TIPOENTIDAD, IDREFERENCIAENTIDAD)
    VALUES (@IdUsuario, @Titulo, @Mensaje, @Tipo, @TipoEntidad, @IdReferenciaEntidad);
    
    SELECT SCOPE_IDENTITY() AS IdNotificacion;
END;
GO
PRINT '  Created: usp_CrearNotificacion (HU007)';
GO

-- =====================================================================
-- HU008: Weekly Closed
-- =====================================================================

-- usp_ObtenerCerradosSemana - Gets completed follow-ups for the week
CREATE OR ALTER PROCEDURE usp_ObtenerCerradosSemana
    @IdUsuario INT,
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Default to current week
    IF @FechaInicio IS NULL SET @FechaInicio = DATEADD(DAY, 1-DATEPART(WEEKDAY, GETDATE()), CAST(GETDATE() AS DATE));
    IF @FechaFin IS NULL SET @FechaFin = DATEADD(DAY, 7, @FechaInicio);
    
    SELECT 
        s.IDSEGUIMIENTO,
        s.FECHAPROGRAMADA,
        s.FECHACOMPLETADO,
        s.RESULTADO,
        s.NOTAS,
        e.IDEMPRESA,
        e.NOMBRECOMERCIAL,
        e.CONTACTO_NOMBRE,
        st.NOMBRE AS TIPOSEGUIMIENTO,
        st.COLOR
    FROM TM_SEGUIMIENTO s
    INNER JOIN TM_EMPRESA e ON s.IDEMPRESA = e.IDEMPRESA
    LEFT JOIN TM_SEGUIMIENTO_TIPO st ON s.IDTIPOSEGUIMIENTO = st.IDTIPOSEGUIMIENTO
    WHERE s.IDUSUARIOASIGNADO = @IdUsuario
      AND s.ESTADO = 'COMPLETADO'
      AND CAST(s.FECHACOMPLETADO AS DATE) BETWEEN @FechaInicio AND @FechaFin
      AND s.ACTIVO = 1
    ORDER BY s.FECHACOMPLETADO DESC;
    
    -- Summary statistics
    SELECT 
        COUNT(*) AS TotalCerrados,
        SUM(CASE WHEN s.RESULTADO = 'EXITOSO' THEN 1 ELSE 0 END) AS Exitosos,
        SUM(CASE WHEN s.RESULTADO = 'SIN_RESPUESTA' THEN 1 ELSE 0 END) AS SinRespuesta,
        SUM(CASE WHEN s.RESULTADO = 'NO_INTERESADO' THEN 1 ELSE 0 END) AS NoInteresados
    FROM TM_SEGUIMIENTO s
    WHERE s.IDUSUARIOASIGNADO = @IdUsuario
      AND s.ESTADO = 'COMPLETADO'
      AND CAST(s.FECHACOMPLETADO AS DATE) BETWEEN @FechaInicio AND @FechaFin
      AND s.ACTIVO = 1;
END;
GO
PRINT '  Created: usp_ObtenerCerradosSemana (HU008)';
GO

-- =====================================================================
-- HU009: Create/Update Follow-ups
-- =====================================================================

-- usp_CrearSeguimiento - Creates a new follow-up
CREATE OR ALTER PROCEDURE usp_CrearSeguimiento
    @IdEmpresa INT,
    @IdTipoSeguimiento INT = NULL,
    @IdUsuarioAsignado INT,
    @FechaProgramada DATE,
    @HoraProgramada TIME = NULL,
    @Prioridad NVARCHAR(16) = 'MEDIA',
    @Notas NVARCHAR(1024) = NULL,
    @UsuarioCrea INT
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO TM_SEGUIMIENTO (
        IDEMPRESA, IDTIPOSEGUIMIENTO, IDUSUARIOASIGNADO, 
        FECHAPROGRAMADA, HORAPROGRAMADA, PRIORIDAD, NOTAS, USUARIOCREA
    )
    VALUES (
        @IdEmpresa, @IdTipoSeguimiento, @IdUsuarioAsignado,
        @FechaProgramada, @HoraProgramada, @Prioridad, @Notas, @UsuarioCrea
    );
    
    SELECT SCOPE_IDENTITY() AS IdSeguimiento;
END;
GO
PRINT '  Created: usp_CrearSeguimiento (HU009)';
GO

-- usp_ActualizarSeguimiento - Updates an existing follow-up
CREATE OR ALTER PROCEDURE usp_ActualizarSeguimiento
    @IdSeguimiento INT,
    @IdTipoSeguimiento INT = NULL,
    @FechaProgramada DATE = NULL,
    @HoraProgramada TIME = NULL,
    @Prioridad NVARCHAR(16) = NULL,
    @Estado NVARCHAR(32) = NULL,
    @Notas NVARCHAR(1024) = NULL,
    @Resultado NVARCHAR(64) = NULL,
    @UsuarioModifica INT
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE TM_SEGUIMIENTO
    SET 
        IDTIPOSEGUIMIENTO = ISNULL(@IdTipoSeguimiento, IDTIPOSEGUIMIENTO),
        FECHAPROGRAMADA = ISNULL(@FechaProgramada, FECHAPROGRAMADA),
        HORAPROGRAMADA = ISNULL(@HoraProgramada, HORAPROGRAMADA),
        PRIORIDAD = ISNULL(@Prioridad, PRIORIDAD),
        ESTADO = ISNULL(@Estado, ESTADO),
        NOTAS = ISNULL(@Notas, NOTAS),
        RESULTADO = ISNULL(@Resultado, RESULTADO),
        FECHACOMPLETADO = CASE WHEN @Estado = 'COMPLETADO' THEN GETDATE() ELSE FECHACOMPLETADO END,
        USUARIOMODIFICA = @UsuarioModifica,
        FECHAMODIFICA = GETDATE()
    WHERE IDSEGUIMIENTO = @IdSeguimiento
      AND ACTIVO = 1;
    
    SELECT @@ROWCOUNT AS Affected;
END;
GO
PRINT '  Created: usp_ActualizarSeguimiento (HU009)';
GO

-- =====================================================================
-- HU010: Daily Production
-- =====================================================================

-- usp_ObtenerProduccionDiaria - Gets daily production metrics
CREATE OR ALTER PROCEDURE usp_ObtenerProduccionDiaria
    @IdUsuario INT,
    @Fecha DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @Fecha IS NULL SET @Fecha = CAST(GETDATE() AS DATE);
    
    -- Daily metrics
    SELECT 
        @Fecha AS Fecha,
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO 
         WHERE IDUSUARIOASIGNADO = @IdUsuario 
           AND FECHAPROGRAMADA = @Fecha 
           AND ACTIVO = 1) AS TotalProgramados,
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO 
         WHERE IDUSUARIOASIGNADO = @IdUsuario 
           AND FECHAPROGRAMADA = @Fecha 
           AND ESTADO = 'COMPLETADO' 
           AND ACTIVO = 1) AS Completados,
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO 
         WHERE IDUSUARIOASIGNADO = @IdUsuario 
           AND FECHAPROGRAMADA = @Fecha 
           AND ESTADO = 'PENDIENTE' 
           AND ACTIVO = 1) AS Pendientes,
        (SELECT COUNT(*) FROM TM_INTERACCION 
         WHERE IDUSUARIO = @IdUsuario 
           AND CAST(FECHAINTERACCION AS DATE) = @Fecha 
           AND ACTIVO = 1) AS Interacciones,
        (SELECT ISNULL(SUM(MONTO), 0) FROM TM_VENTA 
         WHERE IDUSUARIO = @IdUsuario 
           AND FECHAVENTA = @Fecha 
           AND ACTIVO = 1) AS VentasDelDia;
    
    -- Activity detail
    SELECT 
        s.IDSEGUIMIENTO,
        s.FECHAPROGRAMADA,
        s.HORAPROGRAMADA,
        s.ESTADO,
        s.RESULTADO,
        e.NOMBRECOMERCIAL,
        st.NOMBRE AS TIPOSEGUIMIENTO
    FROM TM_SEGUIMIENTO s
    INNER JOIN TM_EMPRESA e ON s.IDEMPRESA = e.IDEMPRESA
    LEFT JOIN TM_SEGUIMIENTO_TIPO st ON s.IDTIPOSEGUIMIENTO = st.IDTIPOSEGUIMIENTO
    WHERE s.IDUSUARIOASIGNADO = @IdUsuario
      AND s.FECHAPROGRAMADA = @Fecha
      AND s.ACTIVO = 1
    ORDER BY s.HORAPROGRAMADA;
END;
GO
PRINT '  Created: usp_ObtenerProduccionDiaria (HU010)';
GO

-- =====================================================================
-- Company Management Procedures
-- =====================================================================

-- usp_BuscarEmpresas - Searches for companies
CREATE OR ALTER PROCEDURE usp_BuscarEmpresas
    @Criterio NVARCHAR(128) = NULL,
    @TipoCliente NVARCHAR(64) = NULL,
    @TipoCartera NVARCHAR(64) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP 100
        e.IDEMPRESA,
        e.NOMBRECOMERCIAL,
        e.RAZONSOCIAL,
        e.RUC,
        e.TIPOCLIENTE,
        e.TIPOCARTERA,
        e.CONTACTO_NOMBRE,
        e.CONTACTO_EMAIL,
        e.CONTACTO_TELEFONO,
        e.ACTIVO
    FROM TM_EMPRESA e
    WHERE e.ACTIVO = 1
      AND (@Criterio IS NULL OR e.NOMBRECOMERCIAL LIKE '%' + @Criterio + '%' OR e.RUC LIKE '%' + @Criterio + '%')
      AND (@TipoCliente IS NULL OR e.TIPOCLIENTE = @TipoCliente)
      AND (@TipoCartera IS NULL OR e.TIPOCARTERA = @TipoCartera)
    ORDER BY e.NOMBRECOMERCIAL;
END;
GO
PRINT '  Created: usp_BuscarEmpresas';
GO

-- usp_ObtenerEmpresa - Gets company details
CREATE OR ALTER PROCEDURE usp_ObtenerEmpresa
    @IdEmpresa INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Company info
    SELECT 
        e.*
    FROM TM_EMPRESA e
    WHERE e.IDEMPRESA = @IdEmpresa;
    
    -- Company locations
    SELECT 
        s.*
    FROM TM_EMPRESA_SEDE s
    WHERE s.IDEMPRESA = @IdEmpresa AND s.ACTIVO = 1
    ORDER BY s.ESPRINCIPAL DESC, s.NOMBRESEDE;
    
    -- Recent follow-ups
    SELECT TOP 10
        seg.IDSEGUIMIENTO,
        seg.FECHAPROGRAMADA,
        seg.ESTADO,
        seg.RESULTADO,
        st.NOMBRE AS TIPOSEGUIMIENTO
    FROM TM_SEGUIMIENTO seg
    LEFT JOIN TM_SEGUIMIENTO_TIPO st ON seg.IDTIPOSEGUIMIENTO = st.IDTIPOSEGUIMIENTO
    WHERE seg.IDEMPRESA = @IdEmpresa AND seg.ACTIVO = 1
    ORDER BY seg.FECHAPROGRAMADA DESC;
END;
GO
PRINT '  Created: usp_ObtenerEmpresa';
GO

-- usp_InsertarEmpresa - Creates a new company
CREATE OR ALTER PROCEDURE usp_InsertarEmpresa
    @NombreComercial NVARCHAR(256),
    @RazonSocial NVARCHAR(256) = NULL,
    @RUC NVARCHAR(11) = NULL,
    @SedePrincipal NVARCHAR(256) = NULL,
    @Domicilio NVARCHAR(512) = NULL,
    @ContactoNombre NVARCHAR(128) = NULL,
    @ContactoEmail NVARCHAR(128) = NULL,
    @ContactoTelefono NVARCHAR(20) = NULL,
    @ContactoCargo NVARCHAR(64) = NULL,
    @TipoCliente NVARCHAR(64) = NULL,
    @LineaNegocio NVARCHAR(128) = NULL,
    @SublineaNegocio NVARCHAR(128) = NULL,
    @TipoCredito NVARCHAR(64) = NULL,
    @TipoCartera NVARCHAR(64) = NULL,
    @ActividadEconomica NVARCHAR(256) = NULL,
    @Riesgo NVARCHAR(32) = NULL,
    @NumTrabajadores INT = NULL,
    @UsuarioCrea INT
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO TM_EMPRESA (
        NOMBRECOMERCIAL, RAZONSOCIAL, RUC, SEDEPRINCIPAL, DOMICILIO,
        CONTACTO_NOMBRE, CONTACTO_EMAIL, CONTACTO_TELEFONO, CONTACTO_CARGO,
        TIPOCLIENTE, LINEANEGOCIO, SUBLINEANEGOCIO, TIPOCREDITO, TIPOCARTERA,
        ACTIVIDADECONOMICA, RIESGO, NUMTRABAJADORES, USUARIOCREA
    )
    VALUES (
        @NombreComercial, @RazonSocial, @RUC, @SedePrincipal, @Domicilio,
        @ContactoNombre, @ContactoEmail, @ContactoTelefono, @ContactoCargo,
        @TipoCliente, @LineaNegocio, @SublineaNegocio, @TipoCredito, @TipoCartera,
        @ActividadEconomica, @Riesgo, @NumTrabajadores, @UsuarioCrea
    );
    
    SELECT SCOPE_IDENTITY() AS IdEmpresa;
END;
GO
PRINT '  Created: usp_InsertarEmpresa';
GO

-- usp_ActualizarEmpresa - Updates an existing company
CREATE OR ALTER PROCEDURE usp_ActualizarEmpresa
    @IdEmpresa INT,
    @NombreComercial NVARCHAR(256) = NULL,
    @RazonSocial NVARCHAR(256) = NULL,
    @RUC NVARCHAR(11) = NULL,
    @SedePrincipal NVARCHAR(256) = NULL,
    @Domicilio NVARCHAR(512) = NULL,
    @ContactoNombre NVARCHAR(128) = NULL,
    @ContactoEmail NVARCHAR(128) = NULL,
    @ContactoTelefono NVARCHAR(20) = NULL,
    @ContactoCargo NVARCHAR(64) = NULL,
    @TipoCliente NVARCHAR(64) = NULL,
    @LineaNegocio NVARCHAR(128) = NULL,
    @SublineaNegocio NVARCHAR(128) = NULL,
    @TipoCredito NVARCHAR(64) = NULL,
    @TipoCartera NVARCHAR(64) = NULL,
    @ActividadEconomica NVARCHAR(256) = NULL,
    @Riesgo NVARCHAR(32) = NULL,
    @NumTrabajadores INT = NULL,
    @UsuarioModifica INT
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE TM_EMPRESA
    SET 
        NOMBRECOMERCIAL = ISNULL(@NombreComercial, NOMBRECOMERCIAL),
        RAZONSOCIAL = ISNULL(@RazonSocial, RAZONSOCIAL),
        RUC = ISNULL(@RUC, RUC),
        SEDEPRINCIPAL = ISNULL(@SedePrincipal, SEDEPRINCIPAL),
        DOMICILIO = ISNULL(@Domicilio, DOMICILIO),
        CONTACTO_NOMBRE = ISNULL(@ContactoNombre, CONTACTO_NOMBRE),
        CONTACTO_EMAIL = ISNULL(@ContactoEmail, CONTACTO_EMAIL),
        CONTACTO_TELEFONO = ISNULL(@ContactoTelefono, CONTACTO_TELEFONO),
        CONTACTO_CARGO = ISNULL(@ContactoCargo, CONTACTO_CARGO),
        TIPOCLIENTE = ISNULL(@TipoCliente, TIPOCLIENTE),
        LINEANEGOCIO = ISNULL(@LineaNegocio, LINEANEGOCIO),
        SUBLINEANEGOCIO = ISNULL(@SublineaNegocio, SUBLINEANEGOCIO),
        TIPOCREDITO = ISNULL(@TipoCredito, TIPOCREDITO),
        TIPOCARTERA = ISNULL(@TipoCartera, TIPOCARTERA),
        ACTIVIDADECONOMICA = ISNULL(@ActividadEconomica, ACTIVIDADECONOMICA),
        RIESGO = ISNULL(@Riesgo, RIESGO),
        NUMTRABAJADORES = ISNULL(@NumTrabajadores, NUMTRABAJADORES),
        USUARIOMODIFICA = @UsuarioModifica,
        FECHAMODIFICA = GETDATE()
    WHERE IDEMPRESA = @IdEmpresa;
    
    SELECT @@ROWCOUNT AS Affected;
END;
GO
PRINT '  Created: usp_ActualizarEmpresa';
GO

-- usp_ObtenerTiposSeguimiento - Gets follow-up types
CREATE OR ALTER PROCEDURE usp_ObtenerTiposSeguimiento
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        IDTIPOSEGUIMIENTO,
        NOMBRE,
        DESCRIPCION,
        COLOR,
        ACTIVO
    FROM TM_SEGUIMIENTO_TIPO
    WHERE ACTIVO = 1
    ORDER BY NOMBRE;
END;
GO
PRINT '  Created: usp_ObtenerTiposSeguimiento';
GO

PRINT '';
PRINT 'All 19 stored procedures created successfully.';
PRINT 'Now run: 05_sample_data.sql';
GO
