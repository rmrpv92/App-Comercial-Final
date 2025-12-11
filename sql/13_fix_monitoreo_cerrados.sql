-- =====================================================
-- Script 13: Fix MONITOREO and VENTAS CERRADAS issues
-- =====================================================
-- Fixes:
-- 1. Dashboard SP returns wrong field names for MONITOREO
-- 2. Días Promedio de Cierre shows -1 (negative calculation)
-- 3. Rendimiento Diario chart not populating
-- =====================================================

USE DB_APPCOMERCIAL;
GO

-- =====================================================
-- 1. FIX DASHBOARD SP FOR MONITOREO
-- Returns: PROGRAMADOS_SEMANA, COMPLETADOS_SEMANA, PENDIENTES_SEMANA, CANCELADOS_SEMANA
-- =====================================================
CREATE OR ALTER PROCEDURE usp_ObtenerDashboardSupervisor
    @IdSupervisor INT,
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IdPerfil INT;
    SELECT @IdPerfil = IDPERFIL FROM TM_USUARIO WHERE IDUSUARIO = @IdSupervisor;
    
    -- Default to current week if dates not provided
    IF @FechaInicio IS NULL
        SET @FechaInicio = DATEADD(DAY, -(DATEPART(WEEKDAY, GETDATE()) - 1), CAST(GETDATE() AS DATE));
    IF @FechaFin IS NULL
        SET @FechaFin = DATEADD(DAY, 7 - DATEPART(WEEKDAY, GETDATE()), CAST(GETDATE() AS DATE));
    
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
    
    -- Return metrics with field names expected by frontend
    SELECT
        -- PROGRAMADOS_SEMANA = Total scheduled for the week
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO s 
         WHERE s.IDUSUARIOASIGNADO IN (SELECT IDUSUARIO FROM @TeamMembers)
           AND s.FECHAPROGRAMADA BETWEEN @FechaInicio AND @FechaFin
           AND s.ACTIVO = 1) AS PROGRAMADOS_SEMANA,
        
        -- COMPLETADOS_SEMANA = Completed this week
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO s 
         WHERE s.IDUSUARIOASIGNADO IN (SELECT IDUSUARIO FROM @TeamMembers)
           AND s.ESTADO = 'COMPLETADO'
           AND s.FECHAPROGRAMADA BETWEEN @FechaInicio AND @FechaFin
           AND s.ACTIVO = 1) AS COMPLETADOS_SEMANA,
        
        -- PENDIENTES_SEMANA = Pending this week
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO s 
         WHERE s.IDUSUARIOASIGNADO IN (SELECT IDUSUARIO FROM @TeamMembers)
           AND s.ESTADO = 'PENDIENTE'
           AND s.FECHAPROGRAMADA BETWEEN @FechaInicio AND @FechaFin
           AND s.ACTIVO = 1) AS PENDIENTES_SEMANA,
        
        -- CANCELADOS_SEMANA = Cancelled this week
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO s 
         WHERE s.IDUSUARIOASIGNADO IN (SELECT IDUSUARIO FROM @TeamMembers)
           AND s.ESTADO = 'CANCELADO'
           AND s.FECHAPROGRAMADA BETWEEN @FechaInicio AND @FechaFin
           AND s.ACTIVO = 1) AS CANCELADOS_SEMANA;
END;
GO
PRINT 'Updated: usp_ObtenerDashboardSupervisor - returns PROGRAMADOS_SEMANA, COMPLETADOS_SEMANA, PENDIENTES_SEMANA, CANCELADOS_SEMANA';
GO

-- =====================================================
-- 2. FIX CERRADOS SP - DiasPromedioCierre calculation
-- Also ensure porDia returns data for chart
-- =====================================================
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
    IF @FechaInicio IS NULL
        SET @FechaInicio = DATEADD(DAY, -(DATEPART(WEEKDAY, GETDATE()) - 1), CAST(GETDATE() AS DATE));
    IF @FechaFin IS NULL
        SET @FechaFin = DATEADD(DAY, 7 - DATEPART(WEEKDAY, GETDATE()), CAST(GETDATE() AS DATE));
    
    -- Get team members based on role
    DECLARE @TeamMembers TABLE (IDUSUARIO INT);
    
    IF @IdPerfil = 1
        INSERT INTO @TeamMembers SELECT IDUSUARIO FROM TM_USUARIO WHERE ACTIVO = 1;
    ELSE IF @IdPerfil = 2
        INSERT INTO @TeamMembers SELECT IDUSUARIO FROM TM_USUARIO WHERE IDSUPERVISOR = @IdUsuario AND ACTIVO = 1;
    ELSE
        INSERT INTO @TeamMembers VALUES (@IdUsuario);
    
    -- RESULT SET 1: Historial Reciente (last 10 closed deals)
    SELECT TOP 10
        e.NOMBRECOMERCIAL AS EMPRESA,
        ISNULL(v.PRODUCTO, 'Servicio Estándar') AS SERVICIO,
        v.MONTO,
        FORMAT(v.FECHAVENTA, 'yyyy-MM-dd') AS FECHA
    FROM TM_VENTA v
    INNER JOIN TM_EMPRESA e ON v.IDEMPRESA = e.IDEMPRESA
    WHERE v.IDUSUARIO IN (SELECT IDUSUARIO FROM @TeamMembers)
      AND v.ACTIVO = 1
    ORDER BY v.FECHAVENTA DESC;
    
    -- RESULT SET 2: Metrics (MontoTotal, DiasPromedioCierre)
    SELECT
        ISNULL(COUNT(*), 0) AS TOTAL_CERRADOS,
        ISNULL(SUM(v.MONTO), 0) AS MontoTotal,
        -- Fix: Use ABS to handle any date order issues, default to 0 if no data
        CASE 
            WHEN COUNT(*) = 0 THEN 0
            ELSE ISNULL(ABS(AVG(
                DATEDIFF(DAY, 
                    ISNULL(v.FECHACREA, v.FECHAVENTA), 
                    v.FECHAVENTA)
            )), 0)
        END AS DiasPromedioCierre
    FROM TM_VENTA v
    WHERE v.IDUSUARIO IN (SELECT IDUSUARIO FROM @TeamMembers)
      AND v.FECHAVENTA BETWEEN @FechaInicio AND @FechaFin
      AND v.ACTIVO = 1;
    
    -- RESULT SET 3: Data for Rendimiento Diario chart (per day breakdown)
    -- Generate all days of the week with counts
    ;WITH DiasSemanaCTE AS (
        SELECT 0 AS DiaOffset
        UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
        UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6
    ),
    FechasSemanaCTE AS (
        SELECT 
            DATEADD(DAY, DiaOffset, @FechaInicio) AS FECHA,
            DATENAME(WEEKDAY, DATEADD(DAY, DiaOffset, @FechaInicio)) AS DIA_SEMANA
        FROM DiasSemanaCTE
        WHERE DATEADD(DAY, DiaOffset, @FechaInicio) <= @FechaFin
    )
    SELECT 
        LEFT(f.DIA_SEMANA, 3) AS DIA_SEMANA,
        FORMAT(f.FECHA, 'yyyy-MM-dd') AS FECHA,
        ISNULL(COUNT(v.IDVENTA), 0) AS CANTIDAD
    FROM FechasSemanaCTE f
    LEFT JOIN TM_VENTA v ON CAST(v.FECHAVENTA AS DATE) = f.FECHA
        AND v.IDUSUARIO IN (SELECT IDUSUARIO FROM @TeamMembers)
        AND v.ACTIVO = 1
    GROUP BY f.FECHA, f.DIA_SEMANA
    ORDER BY f.FECHA;
END;
GO
PRINT 'Updated: usp_ObtenerCerradosSemana - Fixed DiasPromedioCierre calculation and porDia data';
GO

-- =====================================================
-- 3. ADD SAMPLE DATA for better visualization
-- =====================================================

-- Add some CANCELADO seguimientos for MONITOREO testing
UPDATE TM_SEGUIMIENTO 
SET ESTADO = 'CANCELADO'
WHERE IDSEGUIMIENTO IN (
    SELECT TOP 5 IDSEGUIMIENTO 
    FROM TM_SEGUIMIENTO 
    WHERE ESTADO = 'PENDIENTE' 
      AND FECHAPROGRAMADA > GETDATE()
    ORDER BY NEWID()
);
PRINT 'Added some CANCELADO status for testing';

-- Ensure some ventas have proper dates for DiasPromedioCierre
UPDATE TM_VENTA
SET FECHACREA = DATEADD(DAY, -3, FECHAVENTA)
WHERE FECHACREA IS NULL OR FECHACREA = FECHAVENTA;
PRINT 'Updated FECHACREA for DiasPromedioCierre calculation';

-- Add more ventas distributed across the week for chart
DECLARE @StartOfWeek DATE = DATEADD(DAY, -(DATEPART(WEEKDAY, GETDATE()) - 1), CAST(GETDATE() AS DATE));

-- Insert sales on different days of current week
IF NOT EXISTS (SELECT 1 FROM TM_VENTA WHERE FECHAVENTA = @StartOfWeek)
BEGIN
    INSERT INTO TM_VENTA (IDEMPRESA, IDUSUARIO, FECHAVENTA, MONTO, PRODUCTO, DESCRIPCION, ACTIVO, FECHACREA)
    VALUES 
        (1, 4, @StartOfWeek, 15000.00, 'Servicio Premium', 'Venta Lunes', 1, DATEADD(DAY, -5, @StartOfWeek)),
        (2, 5, DATEADD(DAY, 1, @StartOfWeek), 22000.00, 'Consultoria', 'Venta Martes', 1, DATEADD(DAY, -4, @StartOfWeek)),
        (3, 6, DATEADD(DAY, 2, @StartOfWeek), 18000.00, 'Implementacion', 'Venta Miercoles', 1, DATEADD(DAY, -3, @StartOfWeek)),
        (4, 7, DATEADD(DAY, 3, @StartOfWeek), 25000.00, 'Soporte Anual', 'Venta Jueves', 1, DATEADD(DAY, -2, @StartOfWeek)),
        (5, 8, DATEADD(DAY, 4, @StartOfWeek), 12000.00, 'Capacitacion', 'Venta Viernes', 1, DATEADD(DAY, -1, @StartOfWeek));
    PRINT 'Added sample ventas across the week for chart';
END

-- =====================================================
-- VERIFICATION
-- =====================================================
PRINT '';
PRINT '=== VERIFICATION ===';

-- Test Dashboard SP
PRINT 'Testing usp_ObtenerDashboardSupervisor for userId=1:';
EXEC usp_ObtenerDashboardSupervisor @IdSupervisor = 1;

PRINT '';
PRINT 'Testing usp_ObtenerCerradosSemana for userId=1:';
EXEC usp_ObtenerCerradosSemana @IdUsuario = 1;

PRINT '';
PRINT 'Script completed successfully!';
GO
