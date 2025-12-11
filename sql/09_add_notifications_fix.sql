-- =====================================================================
-- 09_add_notifications_fix.sql
-- Description: Add notifications with correct TIPO values
-- Valid TIPO values: 'INFO', 'ALERTA', 'URGENTE', 'RECORDATORIO'
-- =====================================================================

USE DB_APPCOMERCIAL;
GO

PRINT 'Adding notifications with correct TIPO values...';

-- Add notifications for different users (using valid TIPO values only)
INSERT INTO TM_NOTIFICACION (IDUSUARIO, TITULO, MENSAJE, TIPO, LEIDA, ACTIVO)
VALUES
    -- Admin notifications
    (1, 'Reporte semanal disponible', 'El reporte de ventas de la semana esta listo', 'INFO', 0, 1),
    (1, 'Nuevo ejecutivo registrado', 'Se ha registrado un nuevo ejecutivo en el sistema', 'INFO', 0, 1),
    
    -- Supervisor1 notifications
    (2, 'Meta del mes alcanzada', 'Tu equipo ha alcanzado el 100% de la meta mensual', 'INFO', 0, 1),
    (2, 'Seguimiento pendiente urgente', 'Hay 3 seguimientos urgentes sin atender', 'URGENTE', 0, 1),
    
    -- Supervisor2 notifications
    (3, 'Nuevo cliente asignado', 'Se ha asignado un nuevo cliente a tu equipo', 'INFO', 0, 1),
    
    -- Ejecutivo1 notifications
    (4, 'Cita confirmada', 'Tu cita con Empresa ABC ha sido confirmada', 'INFO', 0, 1),
    (4, 'Seguimiento vencido', 'Tienes un seguimiento que vencio hace 2 dias', 'ALERTA', 0, 1),
    (4, 'Nuevo contacto registrado', 'Se ha registrado un nuevo contacto para Empresa XYZ', 'INFO', 0, 1),
    
    -- Ejecutivo2 notifications
    (5, 'Recordatorio de reunion', 'Tienes una reunion programada para manana', 'RECORDATORIO', 0, 1),
    
    -- Ejecutivo3 notifications
    (6, 'Cliente actualizado', 'La informacion del cliente ha sido actualizada', 'INFO', 0, 1);

PRINT 'Notifications added successfully!';

-- Verify
SELECT u.LOGINUSUARIO AS USUARIO, COUNT(*) AS TotalNotificaciones, 
       SUM(CASE WHEN n.LEIDA = 0 THEN 1 ELSE 0 END) AS NoLeidas
FROM TM_NOTIFICACION n
INNER JOIN TM_USUARIO u ON n.IDUSUARIO = u.IDUSUARIO
WHERE n.ACTIVO = 1
GROUP BY u.LOGINUSUARIO;
GO
