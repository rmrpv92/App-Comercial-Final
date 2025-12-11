/* =====================================================================
   DB_APPCOMERCIAL - PART 3: CREATE INDEXES
   Version: 2.0
   Date: December 10, 2025
   
   Execute AFTER: 02_create_tables.sql
   ===================================================================== */

USE DB_APPCOMERCIAL;
GO

PRINT '=== Creating Performance Indexes ===';
GO

-- ---------------------------------------------------------------------
-- Index: TM_USUARIO - Login lookup
-- ---------------------------------------------------------------------
CREATE NONCLUSTERED INDEX IX_USUARIO_LOGIN 
ON TM_USUARIO (LOGINUSUARIO) 
INCLUDE (CLAVE, IDPERFIL, ACTIVO);
GO
PRINT '  Created: IX_USUARIO_LOGIN';
GO

-- ---------------------------------------------------------------------
-- Index: TM_USUARIO - Supervisor lookup
-- ---------------------------------------------------------------------
CREATE NONCLUSTERED INDEX IX_USUARIO_SUPERVISOR 
ON TM_USUARIO (IDSUPERVISOR) 
WHERE IDSUPERVISOR IS NOT NULL;
GO
PRINT '  Created: IX_USUARIO_SUPERVISOR';
GO

-- ---------------------------------------------------------------------
-- Index: TM_SEGUIMIENTO - Date and user lookup (Agenda queries)
-- ---------------------------------------------------------------------
CREATE NONCLUSTERED INDEX IX_SEGUIMIENTO_FECHA_USUARIO 
ON TM_SEGUIMIENTO (FECHAPROGRAMADA, IDUSUARIOASIGNADO, ESTADO) 
INCLUDE (IDEMPRESA, PRIORIDAD, NOTAS);
GO
PRINT '  Created: IX_SEGUIMIENTO_FECHA_USUARIO';
GO

-- ---------------------------------------------------------------------
-- Index: TM_SEGUIMIENTO - State filtering
-- ---------------------------------------------------------------------
CREATE NONCLUSTERED INDEX IX_SEGUIMIENTO_ESTADO 
ON TM_SEGUIMIENTO (ESTADO, ACTIVO) 
INCLUDE (FECHAPROGRAMADA, IDUSUARIOASIGNADO);
GO
PRINT '  Created: IX_SEGUIMIENTO_ESTADO';
GO

-- ---------------------------------------------------------------------
-- Index: TM_EMPRESA - Commercial name search
-- ---------------------------------------------------------------------
CREATE NONCLUSTERED INDEX IX_EMPRESA_NOMBRE 
ON TM_EMPRESA (NOMBRECOMERCIAL);
GO
PRINT '  Created: IX_EMPRESA_NOMBRE';
GO

-- ---------------------------------------------------------------------
-- Index: TM_EMPRESA - RUC lookup
-- ---------------------------------------------------------------------
CREATE NONCLUSTERED INDEX IX_EMPRESA_RUC 
ON TM_EMPRESA (RUC) 
WHERE RUC IS NOT NULL;
GO
PRINT '  Created: IX_EMPRESA_RUC';
GO

-- ---------------------------------------------------------------------
-- Index: TM_VENTA - Date and user lookup (Production queries)
-- ---------------------------------------------------------------------
CREATE NONCLUSTERED INDEX IX_VENTA_FECHA_USUARIO 
ON TM_VENTA (FECHAVENTA, IDUSUARIO) 
INCLUDE (MONTO, IDEMPRESA);
GO
PRINT '  Created: IX_VENTA_FECHA_USUARIO';
GO

-- ---------------------------------------------------------------------
-- Index: TM_NOTIFICACION - User and read status (Notification queries)
-- ---------------------------------------------------------------------
CREATE NONCLUSTERED INDEX IX_NOTIFICACION_USUARIO_LEIDA 
ON TM_NOTIFICACION (IDUSUARIO, LEIDA, ACTIVO) 
INCLUDE (TITULO, MENSAJE, TIPO, FECHACREACION);
GO
PRINT '  Created: IX_NOTIFICACION_USUARIO_LEIDA';
GO

PRINT '';
PRINT 'All 8 indexes created successfully.';
PRINT 'Now run: 04_stored_procedures.sql';
GO
