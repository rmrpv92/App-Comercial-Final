-- =============================================
-- Script 10: Complete Data Fix (CORRECTED VERSION)
-- Fix: VENTAS CERRADAS, PRODUCCIÓN, Notifications, SEGUIMIENTO
-- Date: 2025-12-11
-- =============================================

USE DB_APPCOMERCIAL;
GO

PRINT '=== STEP 1: Add interactions for today (PRODUCCIÓN view) ===';

-- TM_INTERACCION uses: IDEMPRESA, IDSEGUIMIENTO, IDUSUARIO, TIPOINTERACCION (not TIPOCOMUNICACION)
DECLARE @Today DATE = GETDATE();

-- Check if we have interactions for today
IF NOT EXISTS (SELECT 1 FROM TM_INTERACCION WHERE CAST(FECHAINTERACCION AS DATE) = @Today)
BEGIN
    -- Insert interactions for today linked to empresas and seguimientos
    INSERT INTO TM_INTERACCION (IDEMPRESA, IDSEGUIMIENTO, IDUSUARIO, TIPOINTERACCION, DESCRIPCION, FECHAINTERACCION)
    SELECT TOP 20
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
            WHEN 0 THEN 'Llamada de seguimiento programada'
            WHEN 1 THEN 'Envío de cotización actualizada'
            WHEN 2 THEN 'Reunión virtual con cliente'
            WHEN 3 THEN 'Confirmación de términos comerciales'
            ELSE 'Consulta sobre especificaciones técnicas'
        END,
        DATEADD(HOUR, ABS(CHECKSUM(NEWID())) % 8 + 8, CAST(@Today AS DATETIME))
    FROM TM_SEGUIMIENTO s
    WHERE s.ESTADO IN ('EN_PROGRESO', 'PENDIENTE')
      AND s.ACTIVO = 1
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
    -- Update some EN_PROGRESO to COMPLETADO (note: constraint uses EN_PROGRESO not EN_PROCESO)
    UPDATE TOP (10 - @CerradosCount) TM_SEGUIMIENTO
    SET ESTADO = 'COMPLETADO',
        FECHACOMPLETADO = DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 7, GETDATE()),
        RESULTADO = 'EXITOSO'
    WHERE ESTADO = 'EN_PROGRESO'
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

PRINT '=== STEP 3: Add notifications with correct columns ===';

-- TM_NOTIFICACION columns: IDUSUARIO, TITULO, MENSAJE, TIPO, LEIDA, FECHACREACION (has default), TIPOENTIDAD, IDREFERENCIAENTIDAD

-- Delete old test notifications first
DELETE FROM TM_NOTIFICACION WHERE TITULO LIKE 'Test%' OR TITULO LIKE '%prueba%';
GO

-- Insert INFO notifications for all users
INSERT INTO TM_NOTIFICACION (IDUSUARIO, TITULO, MENSAJE, TIPO, LEIDA)
SELECT 
    u.IDUSUARIO,
    'Bienvenido al Sistema Comercial',
    'Tiene seguimientos activos pendientes de atención.',
    'INFO',
    0
FROM TM_USUARIO u
WHERE u.ACTIVO = 1
  AND NOT EXISTS (SELECT 1 FROM TM_NOTIFICACION n WHERE n.IDUSUARIO = u.IDUSUARIO AND n.TITULO = 'Bienvenido al Sistema Comercial');
GO

-- Add ALERTA type notifications for high-value seguimientos
INSERT INTO TM_NOTIFICACION (IDUSUARIO, TITULO, MENSAJE, TIPO, LEIDA, TIPOENTIDAD, IDREFERENCIAENTIDAD)
SELECT DISTINCT
    s.IDUSUARIOASIGNADO,
    'Seguimiento de Alto Valor Pendiente',
    'El cliente ' + e.RAZONSOCIAL + ' requiere atención. Prioridad: ' + s.PRIORIDAD,
    'ALERTA',
    0,
    'SEGUIMIENTO',
    s.IDSEGUIMIENTO
FROM TM_SEGUIMIENTO s
INNER JOIN TM_EMPRESA e ON s.IDEMPRESA = e.IDEMPRESA
WHERE s.PRIORIDAD = 'ALTA' 
  AND s.ESTADO IN ('EN_PROGRESO', 'PENDIENTE')
  AND NOT EXISTS (
    SELECT 1 FROM TM_NOTIFICACION n 
    WHERE n.IDUSUARIO = s.IDUSUARIOASIGNADO 
      AND n.TITULO = 'Seguimiento de Alto Valor Pendiente'
      AND n.IDREFERENCIAENTIDAD = s.IDSEGUIMIENTO
  );
GO

-- Add URGENTE notifications for old pending seguimientos (>7 days)
INSERT INTO TM_NOTIFICACION (IDUSUARIO, TITULO, MENSAJE, TIPO, LEIDA)
SELECT DISTINCT
    s.IDUSUARIOASIGNADO,
    'Atención Urgente Requerida',
    'Tiene seguimientos pendientes de más de 7 días. Por favor revisar.',
    'URGENTE',
    0
FROM TM_SEGUIMIENTO s
WHERE s.ESTADO IN ('EN_PROGRESO', 'PENDIENTE')
  AND s.FECHACREA < DATEADD(DAY, -7, GETDATE())
  AND NOT EXISTS (
    SELECT 1 FROM TM_NOTIFICACION n 
    WHERE n.IDUSUARIO = s.IDUSUARIOASIGNADO 
      AND n.TITULO = 'Atención Urgente Requerida'
      AND CAST(n.FECHACREACION AS DATE) = CAST(GETDATE() AS DATE)
  );
GO

-- Add RECORDATORIO notifications
INSERT INTO TM_NOTIFICACION (IDUSUARIO, TITULO, MENSAJE, TIPO, LEIDA)
SELECT 
    u.IDUSUARIO,
    'Recordatorio: Revisar Agenda del Día',
    'Recuerde revisar su agenda del día y actualizar el estado de sus seguimientos.',
    'RECORDATORIO',
    0
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

-- TM_SEGUIMIENTO_DETALLE uses: TIPOCOMUNICACION, OBSERVACIONES, FECHA1ERCONTACTO
-- Already added in previous execution (70 rows affected)
-- Skip if already populated

DECLARE @DetalleCount INT;
SELECT @DetalleCount = COUNT(*) FROM TM_SEGUIMIENTO_DETALLE;

IF @DetalleCount < 50
BEGIN
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
    PRINT 'Added SEGUIMIENTO_DETALLE records';
END
ELSE
BEGIN
    PRINT 'Sufficient SEGUIMIENTO_DETALLE records exist';
END
GO

PRINT '=== STEP 5: Verify data counts ===';

SELECT 'TM_SEGUIMIENTO (COMPLETADO)' as TableStatus, COUNT(*) as Count FROM TM_SEGUIMIENTO WHERE ESTADO = 'COMPLETADO'
UNION ALL
SELECT 'TM_SEGUIMIENTO (EN_PROGRESO)', COUNT(*) FROM TM_SEGUIMIENTO WHERE ESTADO = 'EN_PROGRESO'
UNION ALL
SELECT 'TM_SEGUIMIENTO (PENDIENTE)', COUNT(*) FROM TM_SEGUIMIENTO WHERE ESTADO = 'PENDIENTE'
UNION ALL
SELECT 'TM_INTERACCION (Today)', COUNT(*) FROM TM_INTERACCION WHERE CAST(FECHAINTERACCION AS DATE) = CAST(GETDATE() AS DATE)
UNION ALL
SELECT 'TM_NOTIFICACION (Total)', COUNT(*) FROM TM_NOTIFICACION
UNION ALL
SELECT 'TM_NOTIFICACION (Unread)', COUNT(*) FROM TM_NOTIFICACION WHERE LEIDA = 0
UNION ALL
SELECT 'TM_SEGUIMIENTO_DETALLE', COUNT(*) FROM TM_SEGUIMIENTO_DETALLE;
GO

PRINT '=== STEP 6: Test usp_ObtenerCerradosSemana ===';

-- Test the cerrados stored procedure (correct name)
DECLARE @fechaIni DATE = DATEADD(DAY, -7, GETDATE());
DECLARE @fechaFin DATE = GETDATE();
DECLARE @userId INT = 1; -- Admin user

EXEC usp_ObtenerCerradosSemana @IdUsuario = @userId, @FechaInicio = @fechaIni, @FechaFin = @fechaFin;
GO

PRINT '=== STEP 7: Test usp_ObtenerProduccionDiaria ===';

DECLARE @fechaProd DATE = GETDATE();
DECLARE @userIdProd INT = 1;

EXEC usp_ObtenerProduccionDiaria @IdUsuario = @userIdProd, @Fecha = @fechaProd;
GO

PRINT '=== Script complete! ===';
