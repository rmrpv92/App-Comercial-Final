/* =====================================================================
   DB_APPCOMERCIAL - PART 7: ADDITIONAL SAMPLE DATA
   Version: 1.00
   Date: December 11, 2025
   
   Execute AFTER: 05_sample_data.sql
   
   Purpose: Add more synthetic data for views that may appear empty:
   - More seguimientos for AGENDA DEL DÍA
   - More pending items for PENDIENTES ACUMULADOS/OLVIDADOS
   - More closed sales for VENTAS CERRADAS
   - Production data for PRODUCCIÓN
   ===================================================================== */

USE DB_APPCOMERCIAL;
GO

PRINT '=== Inserting Additional Sample Data ===';
GO

-- ---------------------------------------------------------------------
-- Variables for date calculations
-- ---------------------------------------------------------------------
DECLARE @Today DATE = CAST(GETDATE() AS DATE);
DECLARE @Yesterday DATE = DATEADD(DAY, -1, @Today);
DECLARE @TwoDaysAgo DATE = DATEADD(DAY, -2, @Today);
DECLARE @ThreeDaysAgo DATE = DATEADD(DAY, -3, @Today);
DECLARE @FourDaysAgo DATE = DATEADD(DAY, -4, @Today);
DECLARE @FiveDaysAgo DATE = DATEADD(DAY, -5, @Today);
DECLARE @OneWeekAgo DATE = DATEADD(DAY, -7, @Today);
DECLARE @TwoWeeksAgo DATE = DATEADD(DAY, -14, @Today);
DECLARE @ThreeWeeksAgo DATE = DATEADD(DAY, -21, @Today);
DECLARE @OneMonthAgo DATE = DATEADD(DAY, -30, @Today);
DECLARE @Tomorrow DATE = DATEADD(DAY, 1, @Today);
DECLARE @InTwoDays DATE = DATEADD(DAY, 2, @Today);
DECLARE @InThreeDays DATE = DATEADD(DAY, 3, @Today);
DECLARE @InOneWeek DATE = DATEADD(DAY, 7, @Today);

-- ---------------------------------------------------------------------
-- MORE SEGUIMIENTOS FOR AGENDA DEL DÍA (Today's appointments)
-- User 4 (ejecutivo1) - more appointments today
-- ---------------------------------------------------------------------
PRINT '  Adding more seguimientos for today (AGENDA DEL DÍA)...';

INSERT INTO TM_SEGUIMIENTO (IDEMPRESA, IDTIPOSEGUIMIENTO, IDUSUARIOASIGNADO, FECHAPROGRAMADA, HORAPROGRAMADA, PRIORIDAD, ESTADO, NOTAS, FECHACOMPLETADO, RESULTADO, USUARIOCREA) VALUES
-- More for user 4 (ejecutivo1)
(4, 4, 4, @Today, '08:00', 'ALTA', 'PENDIENTE', 'Reunión virtual con Servicios Integrales - primera cita del día', NULL, NULL, 1),
(5, 2, 4, @Today, '11:00', 'MEDIA', 'COMPLETADO', 'Llamada de seguimiento completada exitosamente', DATEADD(HOUR, 11, CAST(@Today AS DATETIME)), 'EXITOSO', 1),
(6, 3, 4, @Today, '15:30', 'ALTA', 'PENDIENTE', 'Visita a farmacia para cierre de venta', NULL, NULL, 1),
(7, 1, 4, @Today, '16:30', 'MEDIA', 'PENDIENTE', 'Llamada de seguimiento a transportes', NULL, NULL, 1),

-- More for user 5 (ejecutivo2)
(1, 2, 5, @Today, '08:30', 'MEDIA', 'COMPLETADO', 'Seguimiento matutino completado', DATEADD(HOUR, 8, CAST(@Today AS DATETIME)), 'EXITOSO', 1),
(2, 4, 5, @Today, '11:30', 'ALTA', 'PENDIENTE', 'Reunión virtual con Comercial ABC', NULL, NULL, 1),
(8, 1, 5, @Today, '14:00', 'MEDIA', 'PENDIENTE', 'Llamada a Restaurant El Buen Sabor', NULL, NULL, 1),
(9, 5, 5, @Today, '16:00', 'ALTA', 'PENDIENTE', 'Envío de propuesta a Consultora Legal Plus', NULL, NULL, 1),

-- More for user 6 (ejecutivo3)
(3, 2, 6, @Today, '09:30', 'MEDIA', 'PENDIENTE', 'Seguimiento a Industrias XYZ', NULL, NULL, 1),
(10, 3, 6, @Today, '13:00', 'ALTA', 'PENDIENTE', 'Visita presencial a Agropecuaria Sur', NULL, NULL, 1),
(11, 1, 6, @Today, '15:00', 'BAJA', 'PENDIENTE', 'Llamada de cortesía a Educación Digital', NULL, NULL, 1),

-- More for user 7 (ejecutivo4)
(12, 3, 7, @Today, '10:30', 'ALTA', 'PENDIENTE', 'Visita importante a Minera Andina', NULL, NULL, 1),
(1, 2, 7, @Today, '14:30', 'MEDIA', 'COMPLETADO', 'Seguimiento completado esta tarde', DATEADD(HOUR, 14, CAST(@Today AS DATETIME)), 'SIN_RESPUESTA', 1),

-- More for user 8 (ejecutivo5)
(2, 4, 8, @Today, '09:00', 'MEDIA', 'PENDIENTE', 'Reunión virtual matutina', NULL, NULL, 1),
(3, 2, 8, @Today, '11:00', 'ALTA', 'PENDIENTE', 'Seguimiento urgente', NULL, NULL, 1),
(4, 5, 8, @Today, '15:30', 'ALTA', 'PENDIENTE', 'Envío de propuesta final', NULL, NULL, 1);

GO
PRINT '  Inserted: 17 additional seguimientos for today';
GO

-- ---------------------------------------------------------------------
-- MORE PENDIENTES ACUMULADOS (Accumulated pending - recent past dates)
-- These are pending items from recent days that haven't been completed
-- ---------------------------------------------------------------------
PRINT '  Adding more pendientes acumulados...';

DECLARE @Today2 DATE = CAST(GETDATE() AS DATE);
DECLARE @Yesterday2 DATE = DATEADD(DAY, -1, @Today2);
DECLARE @TwoDaysAgo2 DATE = DATEADD(DAY, -2, @Today2);
DECLARE @ThreeDaysAgo2 DATE = DATEADD(DAY, -3, @Today2);
DECLARE @FourDaysAgo2 DATE = DATEADD(DAY, -4, @Today2);
DECLARE @FiveDaysAgo2 DATE = DATEADD(DAY, -5, @Today2);

INSERT INTO TM_SEGUIMIENTO (IDEMPRESA, IDTIPOSEGUIMIENTO, IDUSUARIOASIGNADO, FECHAPROGRAMADA, HORAPROGRAMADA, PRIORIDAD, ESTADO, NOTAS, FECHACOMPLETADO, RESULTADO, USUARIOCREA) VALUES
-- User 4 accumulated pending
(1, 2, 4, @Yesterday2, '14:00', 'ALTA', 'PENDIENTE', 'Pendiente de ayer - seguimiento urgente', NULL, NULL, 1),
(2, 1, 4, @TwoDaysAgo2, '10:00', 'MEDIA', 'PENDIENTE', 'Pendiente de hace 2 días - llamada', NULL, NULL, 1),
(3, 3, 4, @ThreeDaysAgo2, '11:00', 'ALTA', 'PENDIENTE', 'Visita postergada de hace 3 días', NULL, NULL, 1),
(4, 2, 4, @FourDaysAgo2, '09:00', 'BAJA', 'PENDIENTE', 'Seguimiento acumulado 4 días', NULL, NULL, 1),

-- User 5 accumulated pending
(5, 1, 5, @Yesterday2, '15:00', 'ALTA', 'PENDIENTE', 'Llamada pendiente de ayer', NULL, NULL, 1),
(6, 2, 5, @TwoDaysAgo2, '11:00', 'MEDIA', 'PENDIENTE', 'Seguimiento pendiente 2 días', NULL, NULL, 1),
(7, 4, 5, @ThreeDaysAgo2, '14:00', 'MEDIA', 'PENDIENTE', 'Reunión virtual postergada', NULL, NULL, 1),

-- User 6 accumulated pending
(8, 1, 6, @Yesterday2, '09:00', 'MEDIA', 'PENDIENTE', 'Llamada pendiente de ayer', NULL, NULL, 1),
(9, 2, 6, @TwoDaysAgo2, '10:30', 'ALTA', 'PENDIENTE', 'Seguimiento urgente acumulado', NULL, NULL, 1),
(10, 5, 6, @FourDaysAgo2, '15:00', 'ALTA', 'PENDIENTE', 'Propuesta pendiente de envío', NULL, NULL, 1),

-- User 7 accumulated pending
(11, 2, 7, @Yesterday2, '11:00', 'MEDIA', 'PENDIENTE', 'Seguimiento ayer', NULL, NULL, 1),
(12, 1, 7, @TwoDaysAgo2, '09:30', 'BAJA', 'PENDIENTE', 'Llamada pendiente', NULL, NULL, 1),

-- User 8 accumulated pending
(1, 3, 8, @Yesterday2, '14:00', 'ALTA', 'PENDIENTE', 'Visita pendiente de ayer', NULL, NULL, 1),
(2, 2, 8, @ThreeDaysAgo2, '10:00', 'MEDIA', 'PENDIENTE', 'Seguimiento acumulado', NULL, NULL, 1);

GO
PRINT '  Inserted: 14 additional pendientes acumulados';
GO

-- ---------------------------------------------------------------------
-- MORE PENDIENTES OLVIDADOS (Forgotten pending - older past dates)
-- These are pending items from weeks ago that were forgotten
-- ---------------------------------------------------------------------
PRINT '  Adding more pendientes olvidados...';

DECLARE @Today3 DATE = CAST(GETDATE() AS DATE);
DECLARE @OneWeekAgo3 DATE = DATEADD(DAY, -7, @Today3);
DECLARE @TwoWeeksAgo3 DATE = DATEADD(DAY, -14, @Today3);
DECLARE @ThreeWeeksAgo3 DATE = DATEADD(DAY, -21, @Today3);
DECLARE @OneMonthAgo3 DATE = DATEADD(DAY, -30, @Today3);

INSERT INTO TM_SEGUIMIENTO (IDEMPRESA, IDTIPOSEGUIMIENTO, IDUSUARIOASIGNADO, FECHAPROGRAMADA, HORAPROGRAMADA, PRIORIDAD, ESTADO, NOTAS, FECHACOMPLETADO, RESULTADO, USUARIOCREA) VALUES
-- User 4 forgotten
(5, 1, 4, @TwoWeeksAgo3, '09:00', 'MEDIA', 'PENDIENTE', 'Llamada olvidada hace 2 semanas', NULL, NULL, 1),
(8, 2, 4, @ThreeWeeksAgo3, '11:00', 'BAJA', 'PENDIENTE', 'Seguimiento olvidado hace 3 semanas', NULL, NULL, 1),
(9, 3, 4, @OneMonthAgo3, '14:00', 'MEDIA', 'PENDIENTE', 'Visita nunca realizada - 1 mes', NULL, NULL, 1),

-- User 5 forgotten
(10, 1, 5, @OneWeekAgo3, '10:00', 'ALTA', 'PENDIENTE', 'Llamada urgente olvidada - 1 semana', NULL, NULL, 1),
(11, 2, 5, @TwoWeeksAgo3, '15:00', 'MEDIA', 'PENDIENTE', 'Seguimiento olvidado 2 semanas', NULL, NULL, 1),

-- User 6 forgotten
(12, 4, 6, @TwoWeeksAgo3, '11:00', 'ALTA', 'PENDIENTE', 'Reunión virtual nunca realizada', NULL, NULL, 1),
(1, 1, 6, @ThreeWeeksAgo3, '09:00', 'BAJA', 'PENDIENTE', 'Llamada olvidada completamente', NULL, NULL, 1),

-- User 7 forgotten
(2, 2, 7, @OneWeekAgo3, '10:30', 'MEDIA', 'PENDIENTE', 'Seguimiento olvidado semana pasada', NULL, NULL, 1),
(3, 5, 7, @TwoWeeksAgo3, '14:00', 'ALTA', 'PENDIENTE', 'Propuesta nunca enviada!', NULL, NULL, 1),
(4, 1, 7, @OneMonthAgo3, '11:00', 'MEDIA', 'PENDIENTE', 'Llamada de hace un mes', NULL, NULL, 1),

-- User 8 forgotten
(5, 2, 8, @OneWeekAgo3, '09:00', 'MEDIA', 'PENDIENTE', 'Seguimiento olvidado', NULL, NULL, 1),
(6, 3, 8, @ThreeWeeksAgo3, '15:00', 'ALTA', 'PENDIENTE', 'Visita crítica nunca realizada', NULL, NULL, 1);

GO
PRINT '  Inserted: 12 additional pendientes olvidados';
GO

-- ---------------------------------------------------------------------
-- MORE VENTAS CERRADAS (Closed sales for current week)
-- ---------------------------------------------------------------------
PRINT '  Adding more ventas cerradas...';

DECLARE @Today4 DATE = CAST(GETDATE() AS DATE);
DECLARE @Yesterday4 DATE = DATEADD(DAY, -1, @Today4);
DECLARE @TwoDaysAgo4 DATE = DATEADD(DAY, -2, @Today4);
DECLARE @ThreeDaysAgo4 DATE = DATEADD(DAY, -3, @Today4);
DECLARE @FourDaysAgo4 DATE = DATEADD(DAY, -4, @Today4);
DECLARE @FiveDaysAgo4 DATE = DATEADD(DAY, -5, @Today4);

INSERT INTO TM_VENTA (IDEMPRESA, IDSEGUIMIENTO, IDUSUARIO, FECHAVENTA, MONTO, MONEDA, DESCRIPCION, PRODUCTO, ESTADO, USUARIOCREA) VALUES
-- User 4 sales this week
(1, NULL, 4, @Today4, 8500.00, 'PEN', 'Venta hoy - TechCorp servicio adicional', 'Servicio Premium', 'CERRADA', 1),
(2, NULL, 4, @TwoDaysAgo4, 12000.00, 'PEN', 'Venta hace 2 días - Comercial ABC', 'Plan Empresarial', 'CERRADA', 1),
(3, NULL, 4, @FourDaysAgo4, 25000.00, 'PEN', 'Venta hace 4 días - Industrias XYZ', 'Paquete Industrial', 'CERRADA', 1),

-- User 5 sales this week
(4, NULL, 5, @Yesterday4, 15000.00, 'PEN', 'Venta ayer - Servicios Integrales', 'Plan Completo', 'CERRADA', 1),
(5, NULL, 5, @ThreeDaysAgo4, 32000.00, 'PEN', 'Venta hace 3 días - Constructora Norte', 'Proyecto Construcción', 'CERRADA', 1),

-- User 6 sales this week
(6, NULL, 6, @Today4, 5500.00, 'PEN', 'Venta hoy - Farmacia Salud Total', 'Plan Pyme', 'CERRADA', 1),
(7, NULL, 6, @TwoDaysAgo4, 18000.00, 'PEN', 'Venta hace 2 días - Transportes Rápido', 'Solución Logística', 'CERRADA', 1),

-- User 7 sales this week
(8, NULL, 7, @Yesterday4, 7500.00, 'PEN', 'Venta ayer - Restaurant El Buen Sabor', 'Plan Gastronomía', 'CERRADA', 1),
(9, NULL, 7, @FiveDaysAgo4, 42000.00, 'PEN', 'Venta hace 5 días - Consultora Legal Plus', 'Plan VIP Legal', 'CERRADA', 1),

-- User 8 sales this week
(10, NULL, 8, @Today4, 28000.00, 'PEN', 'Venta hoy - Agropecuaria Sur', 'Plan Agro Premium', 'CERRADA', 1),
(11, NULL, 8, @ThreeDaysAgo4, 9500.00, 'PEN', 'Venta hace 3 días - Educación Digital', 'Licencias Educativas', 'CERRADA', 1),
(12, NULL, 8, @FiveDaysAgo4, 85000.00, 'USD', 'Gran venta - Minera Andina', 'Contrato Minero', 'CERRADA', 1);

GO
PRINT '  Inserted: 12 additional ventas cerradas';
GO

-- ---------------------------------------------------------------------
-- MORE INTERACCIONES (For production tracking)
-- These help populate the PRODUCCIÓN view
-- ---------------------------------------------------------------------
PRINT '  Adding more interacciones for PRODUCCIÓN...';

DECLARE @Today5 DATE = CAST(GETDATE() AS DATE);
DECLARE @Yesterday5 DATE = DATEADD(DAY, -1, @Today5);
DECLARE @TwoDaysAgo5 DATE = DATEADD(DAY, -2, @Today5);

-- User 4 interactions today
INSERT INTO TM_INTERACCION (IDEMPRESA, IDSEGUIMIENTO, IDUSUARIO, FECHAINTERACCION, TIPOINTERACCION, DESCRIPCION, RESULTADO, DURACIONMINUTOS, USUARIOCREA) VALUES
(1, NULL, 4, DATEADD(HOUR, 8, CAST(@Today5 AS DATETIME)), 'LLAMADA', 'Llamada matutina a TechCorp', 'CONTACTADO', 15, 1),
(2, NULL, 4, DATEADD(HOUR, 9, CAST(@Today5 AS DATETIME)), 'EMAIL', 'Envío de información a Comercial ABC', 'ENVIADO', 5, 1),
(3, NULL, 4, DATEADD(HOUR, 10, CAST(@Today5 AS DATETIME)), 'LLAMADA', 'Seguimiento telefónico', 'EXITOSO', 20, 1),
(4, NULL, 4, DATEADD(HOUR, 11, CAST(@Today5 AS DATETIME)), 'LLAMADA', 'Llamada de cierre', 'VENTA_CERRADA', 25, 1),
(5, NULL, 4, DATEADD(HOUR, 14, CAST(@Today5 AS DATETIME)), 'VISITA', 'Visita a Constructora Norte', 'POSITIVO', 45, 1),
(6, NULL, 4, DATEADD(HOUR, 16, CAST(@Today5 AS DATETIME)), 'LLAMADA', 'Última llamada del día', 'CONTACTADO', 10, 1),

-- User 5 interactions today
(7, NULL, 5, DATEADD(HOUR, 8, CAST(@Today5 AS DATETIME)), 'LLAMADA', 'Primera llamada del día', 'CONTACTADO', 12, 1),
(8, NULL, 5, DATEADD(HOUR, 9, CAST(@Today5 AS DATETIME)), 'LLAMADA', 'Seguimiento restaurant', 'INTERESADO', 15, 1),
(9, NULL, 5, DATEADD(HOUR, 10, CAST(@Today5 AS DATETIME)), 'EMAIL', 'Propuesta enviada', 'ENVIADO', 8, 1),
(10, NULL, 5, DATEADD(HOUR, 11, CAST(@Today5 AS DATETIME)), 'LLAMADA', 'Llamada de confirmación', 'EXITOSO', 10, 1),
(11, NULL, 5, DATEADD(HOUR, 14, CAST(@Today5 AS DATETIME)), 'LLAMADA', 'Seguimiento tarde', 'PENDIENTE_RESPUESTA', 12, 1),

-- User 6 interactions today
(12, NULL, 6, DATEADD(HOUR, 9, CAST(@Today5 AS DATETIME)), 'LLAMADA', 'Llamada a minera', 'CONTACTADO', 20, 1),
(1, NULL, 6, DATEADD(HOUR, 10, CAST(@Today5 AS DATETIME)), 'LLAMADA', 'Seguimiento TechCorp', 'EXITOSO', 15, 1),
(2, NULL, 6, DATEADD(HOUR, 11, CAST(@Today5 AS DATETIME)), 'EMAIL', 'Documentación enviada', 'ENVIADO', 5, 1),
(3, NULL, 6, DATEADD(HOUR, 14, CAST(@Today5 AS DATETIME)), 'VISITA', 'Visita industrial', 'MUY_POSITIVO', 60, 1),

-- User 7 interactions today
(4, NULL, 7, DATEADD(HOUR, 8, CAST(@Today5 AS DATETIME)), 'LLAMADA', 'Llamada temprana', 'CONTACTADO', 10, 1),
(5, NULL, 7, DATEADD(HOUR, 10, CAST(@Today5 AS DATETIME)), 'LLAMADA', 'Seguimiento construcción', 'INTERESADO', 18, 1),
(6, NULL, 7, DATEADD(HOUR, 11, CAST(@Today5 AS DATETIME)), 'EMAIL', 'Cotización enviada', 'ENVIADO', 10, 1),
(7, NULL, 7, DATEADD(HOUR, 15, CAST(@Today5 AS DATETIME)), 'LLAMADA', 'Cierre de venta!', 'VENTA_CERRADA', 30, 1),

-- User 8 interactions today
(8, NULL, 8, DATEADD(HOUR, 9, CAST(@Today5 AS DATETIME)), 'LLAMADA', 'Primera llamada', 'CONTACTADO', 12, 1),
(9, NULL, 8, DATEADD(HOUR, 10, CAST(@Today5 AS DATETIME)), 'LLAMADA', 'Seguimiento legal', 'EXITOSO', 20, 1),
(10, NULL, 8, DATEADD(HOUR, 11, CAST(@Today5 AS DATETIME)), 'LLAMADA', 'Llamada agropecuaria', 'INTERESADO', 15, 1),
(11, NULL, 8, DATEADD(HOUR, 14, CAST(@Today5 AS DATETIME)), 'VISITA', 'Visita a cliente', 'POSITIVO', 45, 1),
(12, NULL, 8, DATEADD(HOUR, 16, CAST(@Today5 AS DATETIME)), 'LLAMADA', 'Cierre exitoso', 'VENTA_CERRADA', 25, 1);

GO
PRINT '  Inserted: 24 additional interacciones for production tracking';
GO

-- ---------------------------------------------------------------------
-- MORE NOTIFICACIONES (Alerts for all users)
-- ---------------------------------------------------------------------
PRINT '  Adding more notificaciones...';

INSERT INTO TM_NOTIFICACION (IDUSUARIO, TITULO, MENSAJE, TIPO, LEIDA, TIPOENTIDAD, IDREFERENCIAENTIDAD) VALUES
-- For user 4
(4, 'Cita en 30 minutos', 'Tu cita con TechCorp inicia en 30 minutos', 'RECORDATORIO', 0, 'SEGUIMIENTO', NULL),
(4, 'Propuesta aceptada!', 'El cliente Industrias XYZ aceptó tu propuesta', 'INFO', 0, 'EMPRESA', 3),
(4, 'Pendiente acumulado', 'Tienes 4 seguimientos acumulados de días anteriores', 'ALERTA', 0, NULL, NULL),

-- For user 5
(5, 'Reunión virtual hoy', 'Recuerda tu reunión con Comercial ABC a las 11:30', 'RECORDATORIO', 0, 'SEGUIMIENTO', NULL),
(5, 'Venta registrada', 'Se registró tu venta con Servicios Integrales por S/15,000', 'INFO', 0, 'VENTA', NULL),

-- For user 6
(6, 'Visita importante', 'Tu visita a Agropecuaria Sur está programada para las 13:00', 'RECORDATORIO', 0, 'SEGUIMIENTO', NULL),
(6, 'Felicitaciones!', 'Cerraste 2 ventas esta semana por S/23,500', 'INFO', 0, NULL, NULL),

-- For user 7
(7, 'Visita urgente', 'La visita a Minera Andina es de alta prioridad', 'URGENTE', 0, 'SEGUIMIENTO', NULL),
(7, 'Meta alcanzada!', 'Has alcanzado el 120% de tu meta semanal', 'INFO', 0, NULL, NULL),

-- For user 8
(8, 'Gran venta registrada', 'Se registró tu venta con Minera Andina por $85,000 USD', 'INFO', 0, 'VENTA', NULL),
(8, '3 citas hoy', 'Tienes 3 citas programadas para hoy', 'RECORDATORIO', 0, NULL, NULL),

-- For supervisors
(2, 'Equipo superó meta', 'Tu equipo de 3 ejecutivos superó la meta semanal', 'INFO', 0, NULL, NULL),
(2, 'Alerta de pendientes', 'Ejecutivo Juan Pérez tiene 7 pendientes acumulados', 'ALERTA', 0, 'USUARIO', 4),
(2, 'Reporte listo', 'El reporte diario de producción está disponible', 'INFO', 0, NULL, NULL),

(3, 'Nuevo récord', 'Pedro Sánchez cerró la venta más grande del mes', 'INFO', 0, 'USUARIO', 8),
(3, 'Equipo en buen ritmo', 'Tu equipo mantiene 95% de cumplimiento', 'INFO', 0, NULL, NULL);

GO
PRINT '  Inserted: 16 additional notificaciones';
GO

PRINT '';
PRINT '=== Additional Sample Data Complete ===';
PRINT '';
PRINT 'Summary:';
PRINT '  - 17 seguimientos for AGENDA DEL DÍA (today)';
PRINT '  - 14 pendientes acumulados (recent past)';
PRINT '  - 12 pendientes olvidados (older past)';
PRINT '  - 12 ventas cerradas (this week)';
PRINT '  - 24 interacciones for PRODUCCIÓN tracking';
PRINT '  - 16 notificaciones for alerts';
PRINT '';
PRINT 'Test the application with these credentials:';
PRINT '  - EJECUTIVO: ejecutivo1 / ejec123 (sees 6 tabs)';
PRINT '  - SUPERVISOR: supervisor1 / super123 (sees 8 tabs)';
PRINT '  - ADMIN: admin / admin123 (sees 8 tabs)';
GO
