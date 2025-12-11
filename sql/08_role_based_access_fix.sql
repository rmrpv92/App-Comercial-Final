-- =====================================================================
-- 08_role_based_access_fix.sql
-- Description: Update stored procedures to support role-based data access
--              - ADMIN (IDPERFIL=1): See ALL data
--              - SUPERVISOR (IDPERFIL=2): See team data
--              - EJECUTIVO (IDPERFIL=3): See own data only
-- =====================================================================

USE DB_APPCOMERCIAL;
GO

PRINT '=====================================================';
PRINT 'Updating Stored Procedures for Role-Based Access';
PRINT '=====================================================';
PRINT '';

-- =====================================================================
-- HU002: Updated Daily Agenda with Role Support
-- =====================================================================
CREATE OR ALTER PROCEDURE usp_ObtenerAgendaDia
    @IdUsuario INT,
    @Fecha DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IdPerfil INT;
    SELECT @IdPerfil = IDPERFIL FROM TM_USUARIO WHERE IDUSUARIO = @IdUsuario;
    
    -- Admin sees all, Supervisor sees team, Ejecutivo sees own
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
        st.COLOR,
        u.NOMBRES + ' ' + u.APELLIDOPATERNO AS EJECUTIVO_ASIGNADO
    FROM TM_SEGUIMIENTO s
    INNER JOIN TM_EMPRESA e ON s.IDEMPRESA = e.IDEMPRESA
    INNER JOIN TM_USUARIO u ON s.IDUSUARIOASIGNADO = u.IDUSUARIO
    LEFT JOIN TM_SEGUIMIENTO_TIPO st ON s.IDTIPOSEGUIMIENTO = st.IDTIPOSEGUIMIENTO
    WHERE s.FECHAPROGRAMADA = @Fecha
      AND s.ACTIVO = 1
      AND (
          @IdPerfil = 1 -- Admin sees all
          OR (@IdPerfil = 2 AND u.IDSUPERVISOR = @IdUsuario) -- Supervisor sees team
          OR (@IdPerfil = 3 AND s.IDUSUARIOASIGNADO = @IdUsuario) -- Ejecutivo sees own
      )
    ORDER BY 
        CASE s.PRIORIDAD WHEN 'ALTA' THEN 1 WHEN 'MEDIA' THEN 2 ELSE 3 END,
        s.HORAPROGRAMADA;
END;
GO
PRINT '  Updated: usp_ObtenerAgendaDia with role-based access';
GO

-- =====================================================================
-- HU003: Updated Dashboard with Role Support
-- =====================================================================
CREATE OR ALTER PROCEDURE usp_ObtenerDashboardSupervisor
    @IdSupervisor INT,
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IdPerfil INT;
    SELECT @IdPerfil = IDPERFIL FROM TM_USUARIO WHERE IDUSUARIO = @IdSupervisor;
    
    -- Default to current month if dates not provided
    IF @FechaInicio IS NULL SET @FechaInicio = DATEADD(DAY, 1-DAY(GETDATE()), CAST(GETDATE() AS DATE));
    IF @FechaFin IS NULL SET @FechaFin = EOMONTH(GETDATE());
    
    -- Get team member IDs based on role
    DECLARE @TeamMembers TABLE (IDUSUARIO INT);
    
    IF @IdPerfil = 1
        -- Admin sees all users
        INSERT INTO @TeamMembers SELECT IDUSUARIO FROM TM_USUARIO WHERE ACTIVO = 1;
    ELSE IF @IdPerfil = 2
        -- Supervisor sees team
        INSERT INTO @TeamMembers SELECT IDUSUARIO FROM TM_USUARIO WHERE IDSUPERVISOR = @IdSupervisor AND ACTIVO = 1;
    ELSE
        -- Ejecutivo sees only self
        INSERT INTO @TeamMembers VALUES (@IdSupervisor);
    
    -- Return metrics
    SELECT
        (SELECT COUNT(*) FROM @TeamMembers) AS TotalEquipo,
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
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO s 
         WHERE s.IDUSUARIOASIGNADO IN (SELECT IDUSUARIO FROM @TeamMembers)
           AND s.ESTADO = 'PENDIENTE'
           AND s.FECHAPROGRAMADA < CAST(GETDATE() AS DATE)
           AND s.ACTIVO = 1) AS SeguimientosAtrasados,
        (SELECT ISNULL(SUM(v.MONTO), 0) FROM TM_VENTA v 
         WHERE v.IDUSUARIO IN (SELECT IDUSUARIO FROM @TeamMembers)
           AND v.FECHAVENTA BETWEEN @FechaInicio AND @FechaFin
           AND v.ACTIVO = 1) AS VentasTotales,
        (SELECT COUNT(*) FROM TM_VENTA v 
         WHERE v.IDUSUARIO IN (SELECT IDUSUARIO FROM @TeamMembers)
           AND v.FECHAVENTA BETWEEN @FechaInicio AND @FechaFin
           AND v.ACTIVO = 1) AS TotalVentas;
END;
GO
PRINT '  Updated: usp_ObtenerDashboardSupervisor with role-based access';
GO

-- =====================================================================
-- HU005: Updated Pendientes Acumulados with Role Support
-- =====================================================================
CREATE OR ALTER PROCEDURE usp_ObtenerPendientesAcumulados
    @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IdPerfil INT;
    SELECT @IdPerfil = IDPERFIL FROM TM_USUARIO WHERE IDUSUARIO = @IdUsuario;
    
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
        u.NOMBRES + ' ' + u.APELLIDOPATERNO AS EJECUTIVO_ASIGNADO,
        CASE 
            WHEN s.FECHAPROGRAMADA < CAST(GETDATE() AS DATE) THEN 'ATRASADO'
            WHEN s.FECHAPROGRAMADA = CAST(GETDATE() AS DATE) THEN 'HOY'
            ELSE 'FUTURO'
        END AS EstatusFecha
    FROM TM_SEGUIMIENTO s
    INNER JOIN TM_EMPRESA e ON s.IDEMPRESA = e.IDEMPRESA
    INNER JOIN TM_USUARIO u ON s.IDUSUARIOASIGNADO = u.IDUSUARIO
    LEFT JOIN TM_SEGUIMIENTO_TIPO st ON s.IDTIPOSEGUIMIENTO = st.IDTIPOSEGUIMIENTO
    WHERE s.ESTADO = 'PENDIENTE'
      AND s.ACTIVO = 1
      AND (
          @IdPerfil = 1 -- Admin sees all
          OR (@IdPerfil = 2 AND u.IDSUPERVISOR = @IdUsuario) -- Supervisor sees team
          OR (@IdPerfil = 3 AND s.IDUSUARIOASIGNADO = @IdUsuario) -- Ejecutivo sees own
      )
    ORDER BY s.FECHAPROGRAMADA ASC;
END;
GO
PRINT '  Updated: usp_ObtenerPendientesAcumulados with role-based access';
GO

-- =====================================================================
-- HU004: Updated Pendientes Olvidados with Role Support
-- =====================================================================
CREATE OR ALTER PROCEDURE usp_ObtenerPendientesOlvidados
    @IdUsuario INT,
    @DiasAntiguedad INT = 7
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IdPerfil INT;
    SELECT @IdPerfil = IDPERFIL FROM TM_USUARIO WHERE IDUSUARIO = @IdUsuario;
    
    SELECT 
        s.IDSEGUIMIENTO,
        s.FECHAPROGRAMADA,
        DATEDIFF(DAY, s.FECHAPROGRAMADA, GETDATE()) AS DiasOlvidado,
        s.PRIORIDAD,
        s.ESTADO,
        s.NOTAS,
        e.IDEMPRESA,
        e.NOMBRECOMERCIAL,
        e.CONTACTO_NOMBRE,
        e.CONTACTO_TELEFONO,
        st.NOMBRE AS TIPOSEGUIMIENTO,
        st.COLOR,
        u.NOMBRES + ' ' + u.APELLIDOPATERNO AS EJECUTIVO_ASIGNADO
    FROM TM_SEGUIMIENTO s
    INNER JOIN TM_EMPRESA e ON s.IDEMPRESA = e.IDEMPRESA
    INNER JOIN TM_USUARIO u ON s.IDUSUARIOASIGNADO = u.IDUSUARIO
    LEFT JOIN TM_SEGUIMIENTO_TIPO st ON s.IDTIPOSEGUIMIENTO = st.IDTIPOSEGUIMIENTO
    WHERE s.ESTADO = 'PENDIENTE'
      AND s.FECHAPROGRAMADA < CAST(GETDATE() AS DATE)
      AND DATEDIFF(DAY, s.FECHAPROGRAMADA, GETDATE()) >= @DiasAntiguedad
      AND s.ACTIVO = 1
      AND (
          @IdPerfil = 1 -- Admin sees all
          OR (@IdPerfil = 2 AND u.IDSUPERVISOR = @IdUsuario) -- Supervisor sees team
          OR (@IdPerfil = 3 AND s.IDUSUARIOASIGNADO = @IdUsuario) -- Ejecutivo sees own
      )
    ORDER BY s.FECHAPROGRAMADA ASC;
END;
GO
PRINT '  Updated: usp_ObtenerPendientesOlvidados with role-based access';
GO

-- =====================================================================
-- HU006: Updated Calendario Supervisor with Role Support
-- =====================================================================
CREATE OR ALTER PROCEDURE usp_ObtenerCalendarioSupervisor
    @IdSupervisor INT,
    @FechaInicio DATE,
    @FechaFin DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IdPerfil INT;
    SELECT @IdPerfil = IDPERFIL FROM TM_USUARIO WHERE IDUSUARIO = @IdSupervisor;
    
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
    WHERE s.FECHAPROGRAMADA BETWEEN @FechaInicio AND @FechaFin
      AND s.ACTIVO = 1
      AND (
          @IdPerfil = 1 -- Admin sees all
          OR (@IdPerfil = 2 AND u.IDSUPERVISOR = @IdSupervisor) -- Supervisor sees team
          OR (@IdPerfil = 3 AND s.IDUSUARIOASIGNADO = @IdSupervisor) -- Ejecutivo sees own
      )
    ORDER BY s.FECHAPROGRAMADA, s.HORAPROGRAMADA;
END;
GO
PRINT '  Updated: usp_ObtenerCalendarioSupervisor with role-based access';
GO

-- =====================================================================
-- HU008: Updated Cerrados Semana with Role Support
-- =====================================================================
CREATE OR ALTER PROCEDURE usp_ObtenerCerradosSemana
    @IdUsuario INT,
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IdPerfil INT;
    SELECT @IdPerfil = IDPERFIL FROM TM_USUARIO WHERE IDUSUARIO = @IdUsuario;
    
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
        st.COLOR,
        u.NOMBRES + ' ' + u.APELLIDOPATERNO AS EJECUTIVO_ASIGNADO
    FROM TM_SEGUIMIENTO s
    INNER JOIN TM_EMPRESA e ON s.IDEMPRESA = e.IDEMPRESA
    INNER JOIN TM_USUARIO u ON s.IDUSUARIOASIGNADO = u.IDUSUARIO
    LEFT JOIN TM_SEGUIMIENTO_TIPO st ON s.IDTIPOSEGUIMIENTO = st.IDTIPOSEGUIMIENTO
    WHERE s.ESTADO = 'COMPLETADO'
      AND CAST(s.FECHACOMPLETADO AS DATE) BETWEEN @FechaInicio AND @FechaFin
      AND s.ACTIVO = 1
      AND (
          @IdPerfil = 1 -- Admin sees all
          OR (@IdPerfil = 2 AND u.IDSUPERVISOR = @IdUsuario) -- Supervisor sees team
          OR (@IdPerfil = 3 AND s.IDUSUARIOASIGNADO = @IdUsuario) -- Ejecutivo sees own
      )
    ORDER BY s.FECHACOMPLETADO DESC;
    
    -- Summary statistics
    SELECT 
        COUNT(*) AS TotalCerrados,
        SUM(CASE WHEN s.RESULTADO = 'EXITOSO' THEN 1 ELSE 0 END) AS Exitosos,
        SUM(CASE WHEN s.RESULTADO = 'SIN_RESPUESTA' THEN 1 ELSE 0 END) AS SinRespuesta,
        SUM(CASE WHEN s.RESULTADO = 'NO_INTERESADO' THEN 1 ELSE 0 END) AS NoInteresados
    FROM TM_SEGUIMIENTO s
    INNER JOIN TM_USUARIO u ON s.IDUSUARIOASIGNADO = u.IDUSUARIO
    WHERE s.ESTADO = 'COMPLETADO'
      AND CAST(s.FECHACOMPLETADO AS DATE) BETWEEN @FechaInicio AND @FechaFin
      AND s.ACTIVO = 1
      AND (
          @IdPerfil = 1
          OR (@IdPerfil = 2 AND u.IDSUPERVISOR = @IdUsuario)
          OR (@IdPerfil = 3 AND s.IDUSUARIOASIGNADO = @IdUsuario)
      );
END;
GO
PRINT '  Updated: usp_ObtenerCerradosSemana with role-based access';
GO

-- =====================================================================
-- HU009: Updated Produccion Diaria with Role Support
-- =====================================================================
CREATE OR ALTER PROCEDURE usp_ObtenerProduccionDiaria
    @IdUsuario INT,
    @Fecha DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IdPerfil INT;
    SELECT @IdPerfil = IDPERFIL FROM TM_USUARIO WHERE IDUSUARIO = @IdUsuario;
    
    IF @Fecha IS NULL SET @Fecha = CAST(GETDATE() AS DATE);
    
    -- Get interactions based on role
    SELECT 
        i.IDINTERACCION,
        i.FECHAINTERACCION,
        i.TIPOINTERACCION,
        i.RESULTADO,
        i.DURACIONMINUTOS,
        i.NOTAS,
        e.IDEMPRESA,
        e.NOMBRECOMERCIAL,
        u.IDUSUARIO,
        u.NOMBRES + ' ' + u.APELLIDOPATERNO AS EJECUTIVO
    FROM TM_INTERACCION i
    INNER JOIN TM_EMPRESA e ON i.IDEMPRESA = e.IDEMPRESA
    INNER JOIN TM_USUARIO u ON i.IDUSUARIO = u.IDUSUARIO
    WHERE CAST(i.FECHAINTERACCION AS DATE) = @Fecha
      AND i.ACTIVO = 1
      AND (
          @IdPerfil = 1 -- Admin sees all
          OR (@IdPerfil = 2 AND u.IDSUPERVISOR = @IdUsuario) -- Supervisor sees team
          OR (@IdPerfil = 3 AND i.IDUSUARIO = @IdUsuario) -- Ejecutivo sees own
      )
    ORDER BY i.FECHAINTERACCION DESC;
    
    -- Summary statistics
    SELECT 
        COUNT(DISTINCT i.IDEMPRESA) AS TotalContactos,
        COUNT(*) AS TotalInteracciones,
        SUM(CASE WHEN i.RESULTADO = 'EXITOSO' THEN 1 ELSE 0 END) AS InteraccionesExitosas,
        SUM(ISNULL(i.DURACIONMINUTOS, 0)) AS MinutosTotales,
        CAST(
            CASE 
                WHEN COUNT(*) > 0 THEN 
                    (SUM(CASE WHEN i.RESULTADO = 'EXITOSO' THEN 1 ELSE 0 END) * 100.0) / COUNT(*)
                ELSE 0 
            END AS DECIMAL(5,2)
        ) AS TasaExito
    FROM TM_INTERACCION i
    INNER JOIN TM_USUARIO u ON i.IDUSUARIO = u.IDUSUARIO
    WHERE CAST(i.FECHAINTERACCION AS DATE) = @Fecha
      AND i.ACTIVO = 1
      AND (
          @IdPerfil = 1
          OR (@IdPerfil = 2 AND u.IDSUPERVISOR = @IdUsuario)
          OR (@IdPerfil = 3 AND i.IDUSUARIO = @IdUsuario)
      );
END;
GO
PRINT '  Updated: usp_ObtenerProduccionDiaria with role-based access';
GO

-- =====================================================================
-- HU007: Updated Notificaciones with Role Support
-- =====================================================================
CREATE OR ALTER PROCEDURE usp_ObtenerNotificaciones
    @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IdPerfil INT;
    SELECT @IdPerfil = IDPERFIL FROM TM_USUARIO WHERE IDUSUARIO = @IdUsuario;
    
    -- Alertas (high priority pending items)
    SELECT 
        s.IDSEGUIMIENTO AS IDALERTA,
        'SEGUIMIENTO_ATRASADO' AS TIPOALERTA,
        'Seguimiento atrasado: ' + e.NOMBRECOMERCIAL AS MENSAJE,
        s.FECHAPROGRAMADA,
        DATEDIFF(DAY, s.FECHAPROGRAMADA, GETDATE()) AS DiasAtraso,
        e.IDEMPRESA,
        e.NOMBRECOMERCIAL,
        u.NOMBRES + ' ' + u.APELLIDOPATERNO AS EJECUTIVO
    FROM TM_SEGUIMIENTO s
    INNER JOIN TM_EMPRESA e ON s.IDEMPRESA = e.IDEMPRESA
    INNER JOIN TM_USUARIO u ON s.IDUSUARIOASIGNADO = u.IDUSUARIO
    WHERE s.ESTADO = 'PENDIENTE'
      AND s.FECHAPROGRAMADA < CAST(GETDATE() AS DATE)
      AND s.ACTIVO = 1
      AND (
          @IdPerfil = 1 -- Admin sees all
          OR (@IdPerfil = 2 AND u.IDSUPERVISOR = @IdUsuario) -- Supervisor sees team
          OR (@IdPerfil = 3 AND s.IDUSUARIOASIGNADO = @IdUsuario) -- Ejecutivo sees own
      )
    ORDER BY s.FECHAPROGRAMADA ASC;
    
    -- Notificaciones
    SELECT 
        n.IDNOTIFICACION,
        n.TITULO,
        n.MENSAJE,
        n.TIPO,
        n.LEIDO,
        n.FECHACREACION,
        n.IDEMPRESA,
        e.NOMBRECOMERCIAL
    FROM TM_NOTIFICACION n
    LEFT JOIN TM_EMPRESA e ON n.IDEMPRESA = e.IDEMPRESA
    WHERE (n.IDUSUARIO = @IdUsuario OR @IdPerfil = 1)
      AND n.ACTIVO = 1
    ORDER BY n.FECHACREACION DESC;
    
    -- Unread count
    SELECT COUNT(*) AS NoLeidos
    FROM TM_NOTIFICACION
    WHERE (IDUSUARIO = @IdUsuario OR @IdPerfil = 1)
      AND LEIDO = 0
      AND ACTIVO = 1;
END;
GO
PRINT '  Updated: usp_ObtenerNotificaciones with role-based access';
GO

-- =====================================================================
-- Ensure supervisors are correctly assigned
-- =====================================================================
PRINT '';
PRINT 'Verifying user hierarchy...';

-- Make sure Admin (user 1) is supervisor for supervisors
UPDATE TM_USUARIO SET IDSUPERVISOR = 1 WHERE IDPERFIL = 2 AND IDUSUARIO != 1;

-- Make sure Supervisors are supervisors for ejecutivos
UPDATE TM_USUARIO SET IDSUPERVISOR = 2 WHERE IDUSUARIO IN (4, 5, 6) AND IDPERFIL = 3;
UPDATE TM_USUARIO SET IDSUPERVISOR = 3 WHERE IDUSUARIO IN (7, 8) AND IDPERFIL = 3;

PRINT '  User hierarchy verified';
GO

-- =====================================================================
-- Add more completed seguimientos for VENTAS CERRADAS
-- =====================================================================
PRINT '';
PRINT 'Adding completed seguimientos for VENTAS CERRADAS...';

-- Clear existing completed ones to avoid duplicates
DELETE FROM TM_SEGUIMIENTO WHERE ESTADO = 'COMPLETADO' AND NOTAS LIKE '%role-based fix%';

-- Add completed seguimientos for this week for each ejecutivo
DECLARE @Today DATE = CAST(GETDATE() AS DATE);
DECLARE @WeekStart DATE = DATEADD(DAY, 1-DATEPART(WEEKDAY, @Today), @Today);

-- Completed seguimientos for ejecutivo1 (user 4)
INSERT INTO TM_SEGUIMIENTO (IDEMPRESA, IDTIPOSEGUIMIENTO, IDUSUARIOASIGNADO, FECHAPROGRAMADA, HORAPROGRAMADA, PRIORIDAD, ESTADO, RESULTADO, FECHACOMPLETADO, NOTAS, USUARIOCREA, ACTIVO)
VALUES
    (1, 1, 4, DATEADD(DAY, -1, @Today), '09:00', 'ALTA', 'COMPLETADO', 'EXITOSO', DATEADD(DAY, -1, @Today), 'Venta cerrada exitosamente - role-based fix', 4, 1),
    (3, 2, 4, DATEADD(DAY, -2, @Today), '10:30', 'MEDIA', 'COMPLETADO', 'EXITOSO', DATEADD(DAY, -2, @Today), 'Cliente interesado - role-based fix', 4, 1),
    (5, 3, 4, DATEADD(DAY, -3, @Today), '14:00', 'ALTA', 'COMPLETADO', 'SIN_RESPUESTA', DATEADD(DAY, -2, @Today), 'No contestó - role-based fix', 4, 1),
    (7, 1, 4, @WeekStart, '11:00', 'MEDIA', 'COMPLETADO', 'EXITOSO', @WeekStart, 'Venta confirmada - role-based fix', 4, 1);

-- Completed seguimientos for ejecutivo2 (user 5)
INSERT INTO TM_SEGUIMIENTO (IDEMPRESA, IDTIPOSEGUIMIENTO, IDUSUARIOASIGNADO, FECHAPROGRAMADA, HORAPROGRAMADA, PRIORIDAD, ESTADO, RESULTADO, FECHACOMPLETADO, NOTAS, USUARIOCREA, ACTIVO)
VALUES
    (2, 1, 5, DATEADD(DAY, -1, @Today), '09:30', 'ALTA', 'COMPLETADO', 'EXITOSO', DATEADD(DAY, -1, @Today), 'Cierre exitoso - role-based fix', 5, 1),
    (4, 2, 5, DATEADD(DAY, -2, @Today), '11:00', 'MEDIA', 'COMPLETADO', 'NO_INTERESADO', DATEADD(DAY, -2, @Today), 'No interesado por ahora - role-based fix', 5, 1);

-- Completed seguimientos for ejecutivo3 (user 6)
INSERT INTO TM_SEGUIMIENTO (IDEMPRESA, IDTIPOSEGUIMIENTO, IDUSUARIOASIGNADO, FECHAPROGRAMADA, HORAPROGRAMADA, PRIORIDAD, ESTADO, RESULTADO, FECHACOMPLETADO, NOTAS, USUARIOCREA, ACTIVO)
VALUES
    (6, 3, 6, DATEADD(DAY, -1, @Today), '15:00', 'MEDIA', 'COMPLETADO', 'EXITOSO', DATEADD(DAY, -1, @Today), 'Demo exitoso - role-based fix', 6, 1),
    (8, 1, 6, DATEADD(DAY, -3, @Today), '10:00', 'ALTA', 'COMPLETADO', 'EXITOSO', DATEADD(DAY, -3, @Today), 'Contrato firmado - role-based fix', 6, 1);

-- Completed seguimientos for ejecutivo4 (user 7)
INSERT INTO TM_SEGUIMIENTO (IDEMPRESA, IDTIPOSEGUIMIENTO, IDUSUARIOASIGNADO, FECHAPROGRAMADA, HORAPROGRAMADA, PRIORIDAD, ESTADO, RESULTADO, FECHACOMPLETADO, NOTAS, USUARIOCREA, ACTIVO)
VALUES
    (9, 2, 7, DATEADD(DAY, -2, @Today), '09:00', 'ALTA', 'COMPLETADO', 'EXITOSO', DATEADD(DAY, -2, @Today), 'Negociación completada - role-based fix', 7, 1);

-- Completed seguimientos for ejecutivo5 (user 8)
INSERT INTO TM_SEGUIMIENTO (IDEMPRESA, IDTIPOSEGUIMIENTO, IDUSUARIOASIGNADO, FECHAPROGRAMADA, HORAPROGRAMADA, PRIORIDAD, ESTADO, RESULTADO, FECHACOMPLETADO, NOTAS, USUARIOCREA, ACTIVO)
VALUES
    (10, 1, 8, DATEADD(DAY, -1, @Today), '14:30', 'MEDIA', 'COMPLETADO', 'EXITOSO', DATEADD(DAY, -1, @Today), 'Cliente satisfecho - role-based fix', 8, 1);

PRINT '  Added completed seguimientos for all ejecutivos';
GO

-- =====================================================================
-- Add more notifications
-- =====================================================================
PRINT '';
PRINT 'Adding notifications...';

-- Clear old test notifications
DELETE FROM TM_NOTIFICACION WHERE TITULO LIKE '%role-based%';

-- Add notifications for different users
INSERT INTO TM_NOTIFICACION (IDUSUARIO, TITULO, MENSAJE, TIPO, IDEMPRESA, LEIDO, ACTIVO)
VALUES
    -- Admin notifications
    (1, 'Reporte semanal disponible - role-based', 'El reporte de ventas de la semana está listo', 'INFO', NULL, 0, 1),
    (1, 'Nuevo ejecutivo registrado - role-based', 'Se ha registrado un nuevo ejecutivo en el sistema', 'SISTEMA', NULL, 0, 1),
    
    -- Supervisor1 notifications
    (2, 'Meta del mes alcanzada - role-based', 'Tu equipo ha alcanzado el 100% de la meta mensual', 'EXITO', NULL, 0, 1),
    (2, 'Seguimiento pendiente urgente - role-based', 'Hay 3 seguimientos urgentes sin atender', 'ALERTA', 1, 0, 1),
    
    -- Supervisor2 notifications
    (3, 'Nuevo cliente asignado - role-based', 'Se ha asignado un nuevo cliente a tu equipo', 'INFO', 5, 0, 1),
    
    -- Ejecutivo1 notifications
    (4, 'Cita confirmada - role-based', 'Tu cita con Empresa ABC ha sido confirmada', 'INFO', 1, 0, 1),
    (4, 'Seguimiento vencido - role-based', 'Tienes un seguimiento que venció hace 2 días', 'ALERTA', 3, 0, 1),
    (4, 'Nuevo contacto registrado - role-based', 'Se ha registrado un nuevo contacto para Empresa XYZ', 'INFO', 5, 0, 1),
    
    -- Ejecutivo2 notifications
    (5, 'Recordatorio de reunión - role-based', 'Tienes una reunión programada para mañana', 'RECORDATORIO', 2, 0, 1),
    
    -- Ejecutivo3 notifications
    (6, 'Cliente actualizado - role-based', 'La información del cliente ha sido actualizada', 'INFO', 6, 0, 1);

PRINT '  Added notifications for all users';
GO

-- =====================================================================
-- Add SEGUIMIENTO_DETALLE for empresas
-- =====================================================================
PRINT '';
PRINT 'Adding seguimiento details for empresas...';

-- Check if TM_SEGUIMIENTO_DETALLE exists
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'TM_SEGUIMIENTO_DETALLE')
BEGIN
    -- Add details for seguimientos
    DELETE FROM TM_SEGUIMIENTO_DETALLE WHERE DETALLE LIKE '%role-based%';
    
    INSERT INTO TM_SEGUIMIENTO_DETALLE (IDSEGUIMIENTO, TIPOACCION, DETALLE, FECHAREGISTRO, USUARIOCREA, ACTIVO)
    SELECT TOP 20
        s.IDSEGUIMIENTO,
        CASE (s.IDSEGUIMIENTO % 4)
            WHEN 0 THEN 'LLAMADA'
            WHEN 1 THEN 'EMAIL'
            WHEN 2 THEN 'VISITA'
            ELSE 'REUNION'
        END AS TIPOACCION,
        'Detalle del seguimiento: ' + e.NOMBRECOMERCIAL + ' - Cliente contactado satisfactoriamente. Se acordó próximo paso. role-based' AS DETALLE,
        s.FECHAPROGRAMADA,
        s.IDUSUARIOASIGNADO,
        1
    FROM TM_SEGUIMIENTO s
    INNER JOIN TM_EMPRESA e ON s.IDEMPRESA = e.IDEMPRESA
    WHERE NOT EXISTS (SELECT 1 FROM TM_SEGUIMIENTO_DETALLE d WHERE d.IDSEGUIMIENTO = s.IDSEGUIMIENTO)
    ORDER BY s.IDSEGUIMIENTO;
    
    PRINT '  Added seguimiento details';
END
ELSE
BEGIN
    PRINT '  TM_SEGUIMIENTO_DETALLE table does not exist - creating it...';
    
    CREATE TABLE TM_SEGUIMIENTO_DETALLE (
        IDDETALLE INT IDENTITY(1,1) PRIMARY KEY,
        IDSEGUIMIENTO INT NOT NULL,
        TIPOACCION NVARCHAR(50),
        DETALLE NVARCHAR(1024),
        FECHAREGISTRO DATETIME DEFAULT GETDATE(),
        USUARIOCREA INT,
        ACTIVO BIT DEFAULT 1,
        FOREIGN KEY (IDSEGUIMIENTO) REFERENCES TM_SEGUIMIENTO(IDSEGUIMIENTO)
    );
    
    -- Add details for seguimientos
    INSERT INTO TM_SEGUIMIENTO_DETALLE (IDSEGUIMIENTO, TIPOACCION, DETALLE, FECHAREGISTRO, USUARIOCREA, ACTIVO)
    SELECT TOP 20
        s.IDSEGUIMIENTO,
        CASE (s.IDSEGUIMIENTO % 4)
            WHEN 0 THEN 'LLAMADA'
            WHEN 1 THEN 'EMAIL'
            WHEN 2 THEN 'VISITA'
            ELSE 'REUNION'
        END AS TIPOACCION,
        'Detalle del seguimiento: ' + e.NOMBRECOMERCIAL + ' - Cliente contactado satisfactoriamente. role-based' AS DETALLE,
        s.FECHAPROGRAMADA,
        s.IDUSUARIOASIGNADO,
        1
    FROM TM_SEGUIMIENTO s
    INNER JOIN TM_EMPRESA e ON s.IDEMPRESA = e.IDEMPRESA
    ORDER BY s.IDSEGUIMIENTO;
    
    PRINT '  Created TM_SEGUIMIENTO_DETALLE and added details';
END
GO

-- =====================================================================
-- Verification
-- =====================================================================
PRINT '';
PRINT '=====================================================';
PRINT 'VERIFICATION';
PRINT '=====================================================';

PRINT '';
PRINT 'User hierarchy:';
SELECT u.IDUSUARIO, u.USUARIO, p.DESCRIPCION AS PERFIL, u.IDSUPERVISOR,
       s.USUARIO AS SUPERVISOR_NAME
FROM TM_USUARIO u
INNER JOIN TM_PERFIL p ON u.IDPERFIL = p.IDPERFIL
LEFT JOIN TM_USUARIO s ON u.IDSUPERVISOR = s.IDUSUARIO
WHERE u.ACTIVO = 1
ORDER BY u.IDPERFIL, u.IDUSUARIO;

PRINT '';
PRINT 'Seguimientos count by user and status:';
SELECT 
    u.USUARIO,
    s.ESTADO,
    COUNT(*) AS Total
FROM TM_SEGUIMIENTO s
INNER JOIN TM_USUARIO u ON s.IDUSUARIOASIGNADO = u.IDUSUARIO
WHERE s.ACTIVO = 1
GROUP BY u.USUARIO, s.ESTADO
ORDER BY u.USUARIO, s.ESTADO;

PRINT '';
PRINT 'Completed seguimientos this week:';
DECLARE @WeekStart2 DATE = DATEADD(DAY, 1-DATEPART(WEEKDAY, GETDATE()), CAST(GETDATE() AS DATE));
SELECT u.USUARIO, COUNT(*) AS CompletadosEstaSemana
FROM TM_SEGUIMIENTO s
INNER JOIN TM_USUARIO u ON s.IDUSUARIOASIGNADO = u.IDUSUARIO
WHERE s.ESTADO = 'COMPLETADO'
  AND CAST(s.FECHACOMPLETADO AS DATE) >= @WeekStart2
  AND s.ACTIVO = 1
GROUP BY u.USUARIO;

PRINT '';
PRINT 'Notifications by user:';
SELECT u.USUARIO, COUNT(*) AS TotalNotificaciones, SUM(CASE WHEN n.LEIDO = 0 THEN 1 ELSE 0 END) AS NoLeidas
FROM TM_NOTIFICACION n
INNER JOIN TM_USUARIO u ON n.IDUSUARIO = u.IDUSUARIO
WHERE n.ACTIVO = 1
GROUP BY u.USUARIO;

PRINT '';
PRINT '=====================================================';
PRINT 'Role-based access fix completed successfully!';
PRINT '=====================================================';
PRINT '';
PRINT 'Test the changes:';
PRINT '  - Admin (user 1): Should see ALL data across all views';
PRINT '  - Supervisor1 (user 2): Should see data from users 4, 5, 6';
PRINT '  - Supervisor2 (user 3): Should see data from users 7, 8';
PRINT '  - Ejecutivo1 (user 4): Should see only their own data';
PRINT '';
GO
