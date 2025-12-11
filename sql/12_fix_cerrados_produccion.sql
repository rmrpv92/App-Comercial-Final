-- =============================================
-- Script 12: Fix VENTAS CERRADAS and PRODUCCIÓN stored procedures
-- Issues: Missing metrics calculations, wrong data format
-- Date: 2025-12-11
-- =============================================

USE DB_APPCOMERCIAL;
GO

PRINT '=== Fixing usp_ObtenerCerradosSemana ===';
GO

-- =====================================================================
-- HU008: Fixed Cerrados Semana with proper metrics
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
    
    -- RESULT SET 1: Historial detallado (list of completados)
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
    
    -- RESULT SET 2: Métricas/Estadísticas generales
    SELECT 
        COUNT(*) AS TotalCerrados,
        SUM(CASE WHEN s.RESULTADO = 'EXITOSO' THEN 1 ELSE 0 END) AS Exitosos,
        SUM(CASE WHEN s.RESULTADO = 'SIN_RESPUESTA' THEN 1 ELSE 0 END) AS SinRespuesta,
        SUM(CASE WHEN s.RESULTADO = 'NO_INTERESADO' THEN 1 ELSE 0 END) AS NoInteresados,
        -- Calculate average days to close (from FECHACREA to FECHACOMPLETADO)
        ISNULL(AVG(DATEDIFF(DAY, s.FECHACREA, s.FECHACOMPLETADO)), 0) AS DiasPromedioCierre,
        -- Sum MONTO from TM_VENTA linked to completed seguimientos
        ISNULL((SELECT SUM(v.MONTO) FROM TM_VENTA v 
                WHERE v.IDSEGUIMIENTO IN (
                    SELECT s2.IDSEGUIMIENTO FROM TM_SEGUIMIENTO s2 
                    INNER JOIN TM_USUARIO u2 ON s2.IDUSUARIOASIGNADO = u2.IDUSUARIO
                    WHERE s2.ESTADO = 'COMPLETADO' 
                    AND CAST(s2.FECHACOMPLETADO AS DATE) BETWEEN @FechaInicio AND @FechaFin
                    AND s2.ACTIVO = 1
                    AND (@IdPerfil = 1 OR (@IdPerfil = 2 AND u2.IDSUPERVISOR = @IdUsuario) OR (@IdPerfil = 3 AND s2.IDUSUARIOASIGNADO = @IdUsuario))
                )), 0) AS MontoTotal
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
    
    -- RESULT SET 3: Breakdown por día de la semana (for the chart)
    SELECT 
        DATEPART(WEEKDAY, s.FECHACOMPLETADO) AS DiaSemana,
        DATENAME(WEEKDAY, s.FECHACOMPLETADO) AS NombreDia,
        CAST(s.FECHACOMPLETADO AS DATE) AS Fecha,
        COUNT(*) AS CerradosDelDia,
        SUM(CASE WHEN s.RESULTADO = 'EXITOSO' THEN 1 ELSE 0 END) AS ExitososDelDia
    FROM TM_SEGUIMIENTO s
    INNER JOIN TM_USUARIO u ON s.IDUSUARIOASIGNADO = u.IDUSUARIO
    WHERE s.ESTADO = 'COMPLETADO'
      AND CAST(s.FECHACOMPLETADO AS DATE) BETWEEN @FechaInicio AND @FechaFin
      AND s.ACTIVO = 1
      AND (
          @IdPerfil = 1
          OR (@IdPerfil = 2 AND u.IDSUPERVISOR = @IdUsuario)
          OR (@IdPerfil = 3 AND s.IDUSUARIOASIGNADO = @IdUsuario)
      )
    GROUP BY DATEPART(WEEKDAY, s.FECHACOMPLETADO), DATENAME(WEEKDAY, s.FECHACOMPLETADO), CAST(s.FECHACOMPLETADO AS DATE)
    ORDER BY Fecha;
END;
GO
PRINT '  Updated: usp_ObtenerCerradosSemana with proper metrics';
GO

PRINT '=== Fixing usp_ObtenerProduccionDiaria ===';
GO

-- =====================================================================
-- HU010: Fixed Produccion Diaria - Returns aggregated data per user
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
    
    -- Return aggregated data per user (what the frontend expects)
    SELECT 
        u.IDUSUARIO,
        u.LOGINUSUARIO AS USUARIO,
        u.NOMBRES + ' ' + u.APELLIDOPATERNO AS NOMBRE,
        -- Count interactions for today
        (SELECT COUNT(*) FROM TM_INTERACCION i 
         WHERE i.IDUSUARIO = u.IDUSUARIO 
         AND CAST(i.FECHAINTERACCION AS DATE) = @Fecha
         AND i.ACTIVO = 1) AS CONTACTOS_DEL_DIA,
        -- Count pending seguimientos for this user
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO s 
         WHERE s.IDUSUARIOASIGNADO = u.IDUSUARIO 
         AND s.FECHAPROGRAMADA = @Fecha
         AND s.ESTADO IN ('PENDIENTE', 'EN_PROGRESO')
         AND s.ACTIVO = 1) AS PENDIENTES_DEL_DIA,
        -- Total = interactions + pending
        (SELECT COUNT(*) FROM TM_INTERACCION i 
         WHERE i.IDUSUARIO = u.IDUSUARIO 
         AND CAST(i.FECHAINTERACCION AS DATE) = @Fecha
         AND i.ACTIVO = 1) +
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO s 
         WHERE s.IDUSUARIOASIGNADO = u.IDUSUARIO 
         AND s.FECHAPROGRAMADA = @Fecha
         AND s.ESTADO IN ('PENDIENTE', 'EN_PROGRESO')
         AND s.ACTIVO = 1) AS TOTAL_DEL_DIA
    FROM TM_USUARIO u
    WHERE u.ACTIVO = 1
      AND u.IDPERFIL IN (2, 3) -- Only supervisors and ejecutivos (not admin)
      AND (
          @IdPerfil = 1 -- Admin sees all users
          OR (@IdPerfil = 2 AND (u.IDSUPERVISOR = @IdUsuario OR u.IDUSUARIO = @IdUsuario)) -- Supervisor sees team + self
          OR (@IdPerfil = 3 AND u.IDUSUARIO = @IdUsuario) -- Ejecutivo sees only self
      )
    ORDER BY NOMBRE;
END;
GO
PRINT '  Updated: usp_ObtenerProduccionDiaria with aggregated user data';
GO

-- =====================================================================
-- Add sample TM_VENTA data for MONTO calculations
-- =====================================================================
PRINT '=== Adding sample TM_VENTA data ===';
GO

-- Check if TM_VENTA has data
IF NOT EXISTS (SELECT 1 FROM TM_VENTA)
BEGIN
    -- Add sales linked to completed seguimientos
    INSERT INTO TM_VENTA (IDEMPRESA, IDSEGUIMIENTO, IDUSUARIO, FECHAVENTA, MONTO, ESTADO)
    SELECT TOP 15
        s.IDEMPRESA,
        s.IDSEGUIMIENTO,
        s.IDUSUARIOASIGNADO,
        ISNULL(s.FECHACOMPLETADO, GETDATE()),
        CAST((ABS(CHECKSUM(NEWID())) % 50000 + 5000) AS DECIMAL(18,2)), -- Random amount 5000-55000
        'CERRADA'
    FROM TM_SEGUIMIENTO s
    WHERE s.ESTADO = 'COMPLETADO'
      AND s.RESULTADO = 'EXITOSO'
      AND NOT EXISTS (SELECT 1 FROM TM_VENTA v WHERE v.IDSEGUIMIENTO = s.IDSEGUIMIENTO);
    
    PRINT 'Added sample TM_VENTA data';
END
ELSE
BEGIN
    PRINT 'TM_VENTA already has data';
END
GO

-- =====================================================================
-- Add TM_INTERACCION for today if missing (for PRODUCCIÓN)
-- =====================================================================
PRINT '=== Adding interactions for today ===';
GO

DECLARE @Today DATE = GETDATE();

IF NOT EXISTS (SELECT 1 FROM TM_INTERACCION WHERE CAST(FECHAINTERACCION AS DATE) = @Today)
BEGIN
    -- Insert interactions for today linked to empresas
    INSERT INTO TM_INTERACCION (IDEMPRESA, IDSEGUIMIENTO, IDUSUARIO, TIPOINTERACCION, DESCRIPCION, FECHAINTERACCION, RESULTADO)
    SELECT TOP 25
        s.IDEMPRESA,
        s.IDSEGUIMIENTO,
        s.IDUSUARIOASIGNADO,
        CASE (ABS(CHECKSUM(NEWID())) % 4)
            WHEN 0 THEN 'LLAMADA'
            WHEN 1 THEN 'EMAIL'
            WHEN 2 THEN 'REUNION'
            ELSE 'WHATSAPP'
        END,
        CASE (ABS(CHECKSUM(NEWID())) % 5)
            WHEN 0 THEN 'Llamada de seguimiento'
            WHEN 1 THEN 'Envío de cotización'
            WHEN 2 THEN 'Reunión con cliente'
            WHEN 3 THEN 'Confirmación de términos'
            ELSE 'Consulta técnica'
        END,
        DATEADD(HOUR, ABS(CHECKSUM(NEWID())) % 8 + 8, CAST(@Today AS DATETIME)),
        CASE (ABS(CHECKSUM(NEWID())) % 3)
            WHEN 0 THEN 'EXITOSO'
            WHEN 1 THEN 'PENDIENTE'
            ELSE 'EN_PROCESO'
        END
    FROM TM_SEGUIMIENTO s
    WHERE s.ESTADO IN ('EN_PROGRESO', 'PENDIENTE')
      AND s.ACTIVO = 1
    ORDER BY NEWID();
    
    PRINT 'Added interactions for today';
END
ELSE
BEGIN
    PRINT 'Interactions for today already exist';
END
GO

-- =====================================================================
-- Verification
-- =====================================================================
PRINT '=== Verification ===';
GO

-- Test cerrados
PRINT 'Testing usp_ObtenerCerradosSemana:';
DECLARE @fi DATE = DATEADD(DAY, -7, GETDATE());
DECLARE @ff DATE = GETDATE();
EXEC usp_ObtenerCerradosSemana @IdUsuario = 1, @FechaInicio = @fi, @FechaFin = @ff;
GO

-- Test produccion
PRINT 'Testing usp_ObtenerProduccionDiaria:';
EXEC usp_ObtenerProduccionDiaria @IdUsuario = 1, @Fecha = NULL;
GO

-- Data counts
SELECT 'TM_VENTA' as Tabla, COUNT(*) as Registros FROM TM_VENTA
UNION ALL
SELECT 'TM_INTERACCION (Today)', COUNT(*) FROM TM_INTERACCION WHERE CAST(FECHAINTERACCION AS DATE) = CAST(GETDATE() AS DATE);
GO

PRINT '=== Script complete! ===';
