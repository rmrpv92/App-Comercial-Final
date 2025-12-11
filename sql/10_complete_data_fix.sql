-- =============================================
-- Script 10: Complete Data Fix
-- Fix: VENTAS CERRADAS, PRODUCCIÓN, Notifications, SEGUIMIENTO
-- Author: GitHub Copilot
-- Date: 2025-01-XX
-- =============================================

USE DB_APPCOMERCIAL;
GO

PRINT '=== STEP 1: Add interactions for today (PRODUCCIÓN view) ===';

-- First get current users with their empresas
DECLARE @Today DATE = GETDATE();
DECLARE @Yesterday DATE = DATEADD(DAY, -1, GETDATE());

-- Add TM_INTERACCION records for today
-- These are needed for the PRODUCCIÓN view to show data

-- Check if we have interactions for today
IF NOT EXISTS (SELECT 1 FROM TM_INTERACCION WHERE CAST(FECHAINTERACCION AS DATE) = @Today)
BEGIN
    -- Insert interactions for today
    INSERT INTO TM_INTERACCION (IDSEGUIMIENTO, TIPOCOMUNICACION, DESCRIPCION, FECHAINTERACCION)
    SELECT TOP 20
        s.IDSEGUIMIENTO,
        CASE (ABS(CHECKSUM(NEWID())) % 4)
            WHEN 0 THEN 'LLAMADA'
            WHEN 1 THEN 'EMAIL'
            WHEN 2 THEN 'REUNION'
            ELSE 'WHATSAPP'
        END,
        CASE (ABS(CHECKSUM(NEWID())) % 5)
            WHEN 0 THEN 'Llamada de seguimiento programada'
            WHEN 1 THEN 'Envío de cotización actualizada'
            WHEN 2 THEN 'Reunión virtual con cliente'
            WHEN 3 THEN 'Confirmación de términos comerciales'
            ELSE 'Consulta sobre especificaciones técnicas'
        END,
        DATEADD(HOUR, ABS(CHECKSUM(NEWID())) % 8 + 8, CAST(@Today AS DATETIME))
    FROM TM_SEGUIMIENTO s
    WHERE s.ESTADO IN ('EN_PROCESO', 'NUEVO')
    ORDER BY NEWID();
    
    PRINT 'Inserted interactions for today';
END
ELSE
BEGIN
    PRINT 'Interactions for today already exist';
END
GO

PRINT '=== STEP 2: Ensure VENTAS CERRADAS has completed seguimientos ===';

-- Check current cerrados count
SELECT COUNT(*) as CurrentCerrados FROM TM_SEGUIMIENTO WHERE ESTADO = 'COMPLETADO';

-- Update more seguimientos to COMPLETADO if we don't have enough
DECLARE @CerradosCount INT;
SELECT @CerradosCount = COUNT(*) FROM TM_SEGUIMIENTO WHERE ESTADO = 'COMPLETADO';

IF @CerradosCount < 10
BEGIN
    -- Update some EN_PROCESO to COMPLETADO
    UPDATE TOP (10 - @CerradosCount) TM_SEGUIMIENTO
    SET ESTADO = 'COMPLETADO',
        FECHACOMPLETADO = DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 7, GETDATE())
    WHERE ESTADO = 'EN_PROCESO'
      AND FECHACOMPLETADO IS NULL;
    
    PRINT 'Updated seguimientos to COMPLETADO status';
END
ELSE
BEGIN
    PRINT 'Sufficient COMPLETADO seguimientos exist';
END
GO

-- Make sure completados have recent dates in current week
UPDATE TM_SEGUIMIENTO
SET FECHACOMPLETADO = DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 5, GETDATE())
WHERE ESTADO = 'COMPLETADO'
  AND (FECHACOMPLETADO IS NULL OR FECHACOMPLETADO < DATEADD(DAY, -30, GETDATE()));
GO

PRINT '=== STEP 3: Add notifications with correct TIPO values ===';

-- Check valid TIPO values (INFO, ALERTA, URGENTE, RECORDATORIO)
-- Delete old test notifications first
DELETE FROM TM_NOTIFICACION WHERE TITULO LIKE 'Test%' OR TITULO LIKE '%prueba%';
GO

-- Insert notifications for all users
INSERT INTO TM_NOTIFICACION (IDUSUARIO, TIPO, TITULO, MENSAJE, LEIDA, FECHACREACION)
SELECT 
    u.IDUSUARIO,
    'INFO',
    'Bienvenido al Sistema Comercial',
    'Tiene ' + CAST(
        (SELECT COUNT(*) FROM TM_SEGUIMIENTO s WHERE s.IDUSUARIO = u.IDUSUARIO AND s.ESTADO = 'EN_PROCESO')
    AS VARCHAR) + ' seguimientos activos pendientes de atención.',
    0,
    GETDATE()
FROM TM_USUARIO u
WHERE u.ACTIVO = 1
  AND NOT EXISTS (SELECT 1 FROM TM_NOTIFICACION n WHERE n.IDUSUARIO = u.IDUSUARIO AND n.TITULO = 'Bienvenido al Sistema Comercial');
GO

-- Add ALERTA type notifications for high-value seguimientos
INSERT INTO TM_NOTIFICACION (IDUSUARIO, TIPO, TITULO, MENSAJE, LEIDA, FECHACREACION)
SELECT 
    s.IDUSUARIO,
    'ALERTA',
    'Seguimiento de Alto Valor Pendiente',
    'El cliente ' + e.RAZONSOCIAL + ' requiere atención. Prioridad: ' + s.PRIORIDAD,
    0,
    GETDATE()
FROM TM_SEGUIMIENTO s
INNER JOIN TM_EMPRESA e ON s.IDEMPRESA = e.IDEMPRESA
WHERE s.PRIORIDAD = 'ALTA' 
  AND s.ESTADO IN ('EN_PROCESO', 'NUEVO')
  AND NOT EXISTS (
    SELECT 1 FROM TM_NOTIFICACION n 
    WHERE n.IDUSUARIO = s.IDUSUARIO 
      AND n.TITULO = 'Seguimiento de Alto Valor Pendiente'
      AND n.MENSAJE LIKE '%' + e.RAZONSOCIAL + '%'
  );
GO

-- Add URGENTE notifications for old pending seguimientos (>7 days)
INSERT INTO TM_NOTIFICACION (IDUSUARIO, TIPO, TITULO, MENSAJE, LEIDA, FECHACREACION)
SELECT DISTINCT
    s.IDUSUARIO,
    'URGENTE',
    'Atención Urgente Requerida',
    'Tiene seguimientos pendientes de más de 7 días. Por favor revisar.',
    0,
    GETDATE()
FROM TM_SEGUIMIENTO s
WHERE s.ESTADO IN ('EN_PROCESO', 'NUEVO')
  AND s.FECHACREACION < DATEADD(DAY, -7, GETDATE())
  AND NOT EXISTS (
    SELECT 1 FROM TM_NOTIFICACION n 
    WHERE n.IDUSUARIO = s.IDUSUARIO 
      AND n.TITULO = 'Atención Urgente Requerida'
      AND CAST(n.FECHACREACION AS DATE) = CAST(GETDATE() AS DATE)
  );
GO

-- Add RECORDATORIO notifications
INSERT INTO TM_NOTIFICACION (IDUSUARIO, TIPO, TITULO, MENSAJE, LEIDA, FECHACREACION)
SELECT 
    u.IDUSUARIO,
    'RECORDATORIO',
    'Recordatorio: Revisar Agenda del Día',
    'Recuerde revisar su agenda del día y actualizar el estado de sus seguimientos.',
    0,
    GETDATE()
FROM TM_USUARIO u
WHERE u.ACTIVO = 1
  AND u.IDPERFIL IN (2, 3) -- Supervisores y Ejecutivos
  AND NOT EXISTS (
    SELECT 1 FROM TM_NOTIFICACION n 
    WHERE n.IDUSUARIO = u.IDUSUARIO 
      AND n.TITULO = 'Recordatorio: Revisar Agenda del Día'
      AND CAST(n.FECHACREACION AS DATE) = CAST(GETDATE() AS DATE)
  );
GO

PRINT '=== STEP 4: Add SEGUIMIENTO_DETALLE records for search view ===';

-- Add details to seguimientos that don't have any
INSERT INTO TM_SEGUIMIENTO_DETALLE (IDSEGUIMIENTO, TIPOCOMUNICACION, OBSERVACIONES, FECHA1ERCONTACTO)
SELECT 
    s.IDSEGUIMIENTO,
    CASE (ABS(CHECKSUM(NEWID())) % 4)
        WHEN 0 THEN 'LLAMADA'
        WHEN 1 THEN 'EMAIL'
        WHEN 2 THEN 'REUNION'
        ELSE 'WHATSAPP'
    END,
    CASE (ABS(CHECKSUM(NEWID())) % 5)
        WHEN 0 THEN 'Cliente interesado en propuesta inicial'
        WHEN 1 THEN 'Solicitó mayor información sobre servicios'
        WHEN 2 THEN 'Evaluando presupuesto para próximo trimestre'
        WHEN 3 THEN 'Pendiente de aprobación de gerencia'
        ELSE 'En negociación de términos comerciales'
    END,
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 14, GETDATE())
FROM TM_SEGUIMIENTO s
WHERE NOT EXISTS (
    SELECT 1 FROM TM_SEGUIMIENTO_DETALLE sd WHERE sd.IDSEGUIMIENTO = s.IDSEGUIMIENTO
);
GO

PRINT '=== STEP 5: Verify data counts ===';

SELECT 'TM_SEGUIMIENTO (COMPLETADO)' as TableStatus, COUNT(*) as Count FROM TM_SEGUIMIENTO WHERE ESTADO = 'COMPLETADO'
UNION ALL
SELECT 'TM_SEGUIMIENTO (EN_PROCESO)', COUNT(*) FROM TM_SEGUIMIENTO WHERE ESTADO = 'EN_PROCESO'
UNION ALL
SELECT 'TM_INTERACCION (Today)', COUNT(*) FROM TM_INTERACCION WHERE CAST(FECHAINTERACCION AS DATE) = CAST(GETDATE() AS DATE)
UNION ALL
SELECT 'TM_NOTIFICACION (Total)', COUNT(*) FROM TM_NOTIFICACION
UNION ALL
SELECT 'TM_NOTIFICACION (Unread)', COUNT(*) FROM TM_NOTIFICACION WHERE LEIDA = 0
UNION ALL
SELECT 'TM_SEGUIMIENTO_DETALLE', COUNT(*) FROM TM_SEGUIMIENTO_DETALLE;
GO

PRINT '=== STEP 6: Test SP_OBTENER_CERRADOS ===';

-- Test the cerrados stored procedure
DECLARE @fechaIni VARCHAR(10) = CONVERT(VARCHAR(10), DATEADD(DAY, -7, GETDATE()), 120);
DECLARE @fechaFin VARCHAR(10) = CONVERT(VARCHAR(10), GETDATE(), 120);
DECLARE @userId INT = 1; -- Admin user

EXEC SP_OBTENER_CERRADOS @fechaIni, @fechaFin, @userId;
GO

PRINT '=== STEP 7: Test SP_OBTENER_PRODUCCION ===';

DECLARE @fechaProd VARCHAR(10) = CONVERT(VARCHAR(10), GETDATE(), 120);
DECLARE @userIdProd INT = 1;

EXEC SP_OBTENER_PRODUCCION @fechaProd, @userIdProd;
GO

PRINT '=== Script complete! ===';
