/* =====================================================================
   DB_APPCOMERCIAL - PART 6: VERIFICATION QUERIES
   Version: 2.0
   Date: December 10, 2025
   
   Execute AFTER: 05_sample_data.sql
   
   This script verifies the database was created correctly.
   ===================================================================== */

USE DB_APPCOMERCIAL;
GO

PRINT '=== DATABASE VERIFICATION ===';
PRINT '';
GO

-- ---------------------------------------------------------------------
-- 1. TABLE COUNTS
-- ---------------------------------------------------------------------
PRINT '1. TABLE RECORD COUNTS';
PRINT '----------------------';

SELECT 'TM_PERFIL' AS Tabla, COUNT(*) AS Registros FROM TM_PERFIL
UNION ALL SELECT 'TM_USUARIO', COUNT(*) FROM TM_USUARIO
UNION ALL SELECT 'TM_SEGUIMIENTO_TIPO', COUNT(*) FROM TM_SEGUIMIENTO_TIPO
UNION ALL SELECT 'TM_EMPRESA', COUNT(*) FROM TM_EMPRESA
UNION ALL SELECT 'TM_EMPRESA_SEDE', COUNT(*) FROM TM_EMPRESA_SEDE
UNION ALL SELECT 'TM_SEGUIMIENTO', COUNT(*) FROM TM_SEGUIMIENTO
UNION ALL SELECT 'TM_SEGUIMIENTO_DETALLE', COUNT(*) FROM TM_SEGUIMIENTO_DETALLE
UNION ALL SELECT 'TM_INTERACCION', COUNT(*) FROM TM_INTERACCION
UNION ALL SELECT 'TM_VENTA', COUNT(*) FROM TM_VENTA
UNION ALL SELECT 'TM_NOTIFICACION', COUNT(*) FROM TM_NOTIFICACION
ORDER BY Tabla;
GO

-- ---------------------------------------------------------------------
-- 2. USER HIERARCHY
-- ---------------------------------------------------------------------
PRINT '';
PRINT '2. USER HIERARCHY';
PRINT '-----------------';

SELECT 
    u.IDUSUARIO,
    u.LOGINUSUARIO,
    u.NOMBRES + ' ' + u.APELLIDOPATERNO AS NombreCompleto,
    p.NOMBREPERFIL AS Perfil,
    s.NOMBRES + ' ' + s.APELLIDOPATERNO AS SupervisorNombre,
    u.ACTIVO
FROM TM_USUARIO u
INNER JOIN TM_PERFIL p ON u.IDPERFIL = p.IDPERFIL
LEFT JOIN TM_USUARIO s ON u.IDSUPERVISOR = s.IDUSUARIO
ORDER BY 
    CASE p.NOMBREPERFIL WHEN 'ADMIN' THEN 1 WHEN 'SUPERVISOR' THEN 2 ELSE 3 END,
    u.IDUSUARIO;
GO

-- ---------------------------------------------------------------------
-- 3. TEST LOGIN PROCEDURE
-- ---------------------------------------------------------------------
PRINT '';
PRINT '3. TEST LOGIN (admin/admin123)';
PRINT '------------------------------';

EXEC usp_ValidarLogin @LoginUsuario = 'admin', @Clave = 'admin123';
GO

PRINT '';
PRINT '3b. TEST LOGIN (ejecutivo1/ejec123)';
PRINT '-----------------------------------';

EXEC usp_ValidarLogin @LoginUsuario = 'ejecutivo1', @Clave = 'ejec123';
GO

-- ---------------------------------------------------------------------
-- 4. TEST AGENDA PROCEDURE
-- ---------------------------------------------------------------------
PRINT '';
PRINT '4. TEST AGENDA FOR TODAY (User 4)';
PRINT '---------------------------------';

EXEC usp_ObtenerAgendaDia @IdUsuario = 4, @Fecha = NULL;
GO

-- ---------------------------------------------------------------------
-- 5. TEST PENDING ACCUMULATED
-- ---------------------------------------------------------------------
PRINT '';
PRINT '5. TEST PENDING ACCUMULATED (User 4)';
PRINT '------------------------------------';

EXEC usp_ObtenerPendientesAcumulados @IdUsuario = 4;
GO

-- ---------------------------------------------------------------------
-- 6. TEST FORGOTTEN FOLLOW-UPS
-- ---------------------------------------------------------------------
PRINT '';
PRINT '6. TEST FORGOTTEN FOLLOW-UPS (User 4, 7+ days)';
PRINT '----------------------------------------------';

EXEC usp_ObtenerPendientesOlvidados @IdUsuario = 4, @DiasAntiguedad = 7;
GO

-- ---------------------------------------------------------------------
-- 7. TEST NOTIFICATIONS
-- ---------------------------------------------------------------------
PRINT '';
PRINT '7. TEST NOTIFICATIONS (User 4)';
PRINT '------------------------------';

EXEC usp_ObtenerNotificaciones @IdUsuario = 4, @SoloNoLeidas = 0;
GO

-- ---------------------------------------------------------------------
-- 8. TEST SUPERVISOR DASHBOARD
-- ---------------------------------------------------------------------
PRINT '';
PRINT '8. TEST SUPERVISOR DASHBOARD (Supervisor 2)';
PRINT '-------------------------------------------';

EXEC usp_ObtenerDashboardSupervisor @IdSupervisor = 2;
GO

-- ---------------------------------------------------------------------
-- 9. STORED PROCEDURE LIST
-- ---------------------------------------------------------------------
PRINT '';
PRINT '9. STORED PROCEDURES CREATED';
PRINT '----------------------------';

SELECT 
    name AS StoredProcedure,
    create_date AS CreatedDate
FROM sys.procedures
WHERE type = 'P'
ORDER BY name;
GO

-- ---------------------------------------------------------------------
-- 10. INDEX LIST
-- ---------------------------------------------------------------------
PRINT '';
PRINT '10. INDEXES CREATED';
PRINT '-------------------';

SELECT 
    t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
WHERE i.name LIKE 'IX_%'
ORDER BY t.name, i.name;
GO

-- ---------------------------------------------------------------------
-- 11. SUMMARY
-- ---------------------------------------------------------------------
PRINT '';
PRINT '=== VERIFICATION COMPLETE ===';
PRINT '';
PRINT 'Database: DB_APPCOMERCIAL';
PRINT 'Tables: 10';
PRINT 'Indexes: 8';
PRINT 'Stored Procedures: 19';
PRINT '';
PRINT 'Test Credentials:';
PRINT '  - Admin: admin / admin123';
PRINT '  - Supervisor: supervisor1 / super123';
PRINT '  - Ejecutivo: ejecutivo1 / ejec123';
PRINT '';
PRINT 'All HUs Supported:';
PRINT '  HU001 - Login (usp_ValidarLogin)';
PRINT '  HU002 - Agenda (usp_ObtenerAgendaDia)';
PRINT '  HU003 - Dashboard (usp_ObtenerDashboardSupervisor)';
PRINT '  HU004 - Olvidados (usp_ObtenerPendientesOlvidados)';
PRINT '  HU005 - Acumulados (usp_ObtenerPendientesAcumulados)';
PRINT '  HU006 - Calendario (usp_ObtenerCalendarioSupervisor)';
PRINT '  HU007 - Notificaciones (usp_ObtenerNotificaciones, usp_MarcarNotificacionLeida)';
PRINT '  HU008 - Cerrados (usp_ObtenerCerradosSemana)';
PRINT '  HU009 - CRUD Seguimiento (usp_CrearSeguimiento, usp_ActualizarSeguimiento)';
PRINT '  HU010 - Produccion (usp_ObtenerProduccionDiaria)';
GO
