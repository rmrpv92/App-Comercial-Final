/* =====================================================================
   DB_APPCOMERCIAL - PART 5: SAMPLE DATA
   Version: 2.0
   Date: December 10, 2025
   
   Execute AFTER: 04_stored_procedures.sql
   
   Test Credentials:
   - Admin: admin / admin123
   - Supervisor: supervisor1 / super123
   - Ejecutivo: ejecutivo1 / ejec123
   ===================================================================== */

USE DB_APPCOMERCIAL;
GO

PRINT '=== Inserting Sample Data ===';
GO

-- ---------------------------------------------------------------------
-- TM_PERFIL (User Roles)
-- ---------------------------------------------------------------------
SET IDENTITY_INSERT TM_PERFIL ON;

INSERT INTO TM_PERFIL (IDPERFIL, NOMBREPERFIL, DESCRIPCION, ACTIVO) VALUES
(1, 'ADMIN', 'Administrador del sistema con acceso total', 1),
(2, 'SUPERVISOR', 'Supervisor de equipo comercial', 1),
(3, 'EJECUTIVO', 'Ejecutivo comercial de ventas', 1);

SET IDENTITY_INSERT TM_PERFIL OFF;
GO
PRINT '  Inserted: 3 profiles';
GO

-- ---------------------------------------------------------------------
-- TM_USUARIO (Users)
-- Hierarchy: Admin -> Supervisor -> Ejecutivos
-- ---------------------------------------------------------------------
SET IDENTITY_INSERT TM_USUARIO ON;

-- Admin (no supervisor)
INSERT INTO TM_USUARIO (IDUSUARIO, IDPERFIL, LOGINUSUARIO, CLAVE, NOMBRES, APELLIDOPATERNO, APELLIDOMATERNO, EMAIL, TELEFONO, ACTIVO, IDSUPERVISOR)
VALUES (1, 1, 'admin', 'admin123', 'Administrador', 'Sistema', NULL, 'admin@empresa.com', '999000001', 1, NULL);

-- Supervisors (report to admin)
INSERT INTO TM_USUARIO (IDUSUARIO, IDPERFIL, LOGINUSUARIO, CLAVE, NOMBRES, APELLIDOPATERNO, APELLIDOMATERNO, EMAIL, TELEFONO, ACTIVO, IDSUPERVISOR)
VALUES 
(2, 2, 'supervisor1', 'super123', 'Carlos', 'Martinez', 'Lopez', 'cmartinez@empresa.com', '999000002', 1, 1),
(3, 2, 'supervisor2', 'super123', 'Maria', 'Gonzales', 'Perez', 'mgonzales@empresa.com', '999000003', 1, 1);

-- Ejecutivos (report to supervisors)
INSERT INTO TM_USUARIO (IDUSUARIO, IDPERFIL, LOGINUSUARIO, CLAVE, NOMBRES, APELLIDOPATERNO, APELLIDOMATERNO, EMAIL, TELEFONO, ACTIVO, IDSUPERVISOR)
VALUES 
(4, 3, 'ejecutivo1', 'ejec123', 'Juan', 'Perez', 'Vargas', 'jperez@empresa.com', '999000004', 1, 2),
(5, 3, 'ejecutivo2', 'ejec123', 'Ana', 'Rodriguez', 'Luna', 'arodriguez@empresa.com', '999000005', 1, 2),
(6, 3, 'ejecutivo3', 'ejec123', 'Luis', 'Garcia', 'Mendoza', 'lgarcia@empresa.com', '999000006', 1, 2),
(7, 3, 'ejecutivo4', 'ejec123', 'Sofia', 'Torres', 'Diaz', 'storres@empresa.com', '999000007', 1, 3),
(8, 3, 'ejecutivo5', 'ejec123', 'Pedro', 'Sanchez', 'Flores', 'psanchez@empresa.com', '999000008', 1, 3);

SET IDENTITY_INSERT TM_USUARIO OFF;
GO
PRINT '  Inserted: 8 users (1 admin, 2 supervisors, 5 ejecutivos)';
GO

-- ---------------------------------------------------------------------
-- TM_SEGUIMIENTO_TIPO (Follow-up Types)
-- ---------------------------------------------------------------------
SET IDENTITY_INSERT TM_SEGUIMIENTO_TIPO ON;

INSERT INTO TM_SEGUIMIENTO_TIPO (IDTIPOSEGUIMIENTO, NOMBRE, DESCRIPCION, COLOR, ACTIVO) VALUES
(1, 'Llamada Fría', 'Primer contacto telefónico con prospecto', '#3498db', 1),
(2, 'Llamada Seguimiento', 'Seguimiento a cliente existente', '#2ecc71', 1),
(3, 'Visita Presencial', 'Reunión en oficina del cliente', '#e74c3c', 1),
(4, 'Reunión Virtual', 'Videollamada con cliente', '#9b59b6', 1),
(5, 'Envío Propuesta', 'Envío de cotización o propuesta', '#f39c12', 1),
(6, 'Cierre Venta', 'Firma de contrato o cierre', '#1abc9c', 1),
(7, 'Post-Venta', 'Seguimiento después de venta', '#34495e', 1),
(8, 'Reactivación', 'Contacto con cliente inactivo', '#e67e22', 1);

SET IDENTITY_INSERT TM_SEGUIMIENTO_TIPO OFF;
GO
PRINT '  Inserted: 8 follow-up types';
GO

-- ---------------------------------------------------------------------
-- TM_EMPRESA (Companies/Clients)
-- ---------------------------------------------------------------------
SET IDENTITY_INSERT TM_EMPRESA ON;

INSERT INTO TM_EMPRESA (IDEMPRESA, NOMBRECOMERCIAL, RAZONSOCIAL, RUC, SEDEPRINCIPAL, DOMICILIO, CONTACTO_NOMBRE, CONTACTO_EMAIL, CONTACTO_TELEFONO, CONTACTO_CARGO, TIPOCLIENTE, LINEANEGOCIO, TIPOCARTERA, RIESGO, NUMTRABAJADORES, ACTIVO, USUARIOCREA) VALUES
(1, 'TechCorp Peru', 'TechCorp Peru S.A.C.', '20123456789', 'Lima', 'Av. Javier Prado 1234, San Isidro', 'Roberto Diaz', 'rdiaz@techcorp.pe', '999111001', 'Gerente General', 'EMPRESA', 'Tecnologia', 'PREMIUM', 'BAJO', 150, 1, 1),
(2, 'Comercial ABC', 'Comercial ABC E.I.R.L.', '20234567890', 'Lima', 'Jr. Union 567, Cercado de Lima', 'Patricia Luna', 'pluna@comercialabc.pe', '999111002', 'Jefa de Compras', 'EMPRESA', 'Comercio', 'ESTANDAR', 'MEDIO', 45, 1, 1),
(3, 'Industrias XYZ', 'Industrias XYZ S.A.', '20345678901', 'Callao', 'Av. Argentina 890, Callao', 'Fernando Rojas', 'frojas@industriasxyz.pe', '999111003', 'Director Comercial', 'EMPRESA', 'Manufactura', 'PREMIUM', 'BAJO', 300, 1, 1),
(4, 'Servicios Integrales', 'Servicios Integrales Peru S.A.C.', '20456789012', 'Lima', 'Calle Los Pinos 123, Miraflores', 'Carmen Vega', 'cvega@servintegral.pe', '999111004', 'Gerente Administrativo', 'EMPRESA', 'Servicios', 'ESTANDAR', 'BAJO', 80, 1, 1),
(5, 'Constructora Norte', 'Constructora Norte S.A.C.', '20567890123', 'Trujillo', 'Av. España 456, Trujillo', 'Miguel Angel Ruiz', 'maruiz@constnorte.pe', '999111005', 'Gerente de Proyectos', 'EMPRESA', 'Construccion', 'VIP', 'MEDIO', 200, 1, 1),
(6, 'Farmacia Salud Total', 'Farmacia Salud Total E.I.R.L.', '20678901234', 'Lima', 'Av. Brasil 789, Jesus Maria', 'Lucia Mendez', 'lmendez@saludtotal.pe', '999111006', 'Propietaria', 'PYME', 'Salud', 'ESTANDAR', 'BAJO', 15, 1, 1),
(7, 'Transportes Rapido', 'Transportes Rapido S.A.C.', '20789012345', 'Lima', 'Av. Colonial 1234, Callao', 'Jose Campos', 'jcampos@transrapido.pe', '999111007', 'Gerente de Operaciones', 'EMPRESA', 'Transporte', 'PREMIUM', 'ALTO', 120, 1, 1),
(8, 'Restaurant El Buen Sabor', 'El Buen Sabor S.R.L.', '20890123456', 'Lima', 'Calle Tacna 567, Miraflores', 'Maria Elena Castro', 'mecastro@buensabor.pe', '999111008', 'Administradora', 'PYME', 'Gastronomia', 'ESTANDAR', 'MEDIO', 25, 1, 1),
(9, 'Consultora Legal Plus', 'Consultora Legal Plus S.A.C.', '20901234567', 'Lima', 'Av. Larco 890, Miraflores', 'Alberto Quispe', 'aquispe@legalplus.pe', '999111009', 'Socio Principal', 'EMPRESA', 'Servicios Legales', 'VIP', 'BAJO', 35, 1, 1),
(10, 'Agropecuaria Sur', 'Agropecuaria Sur S.A.', '20012345678', 'Arequipa', 'Av. Ejercito 123, Arequipa', 'Rosa Paredes', 'rparedes@agrosur.pe', '999111010', 'Gerente General', 'EMPRESA', 'Agropecuario', 'PREMIUM', 'MEDIO', 180, 1, 1),
(11, 'Educacion Digital', 'Educacion Digital Peru S.A.C.', '20123456781', 'Lima', 'Av. Universitaria 456, San Miguel', 'Victor Huaman', 'vhuaman@edudigital.pe', '999111011', 'Director Academico', 'EMPRESA', 'Educacion', 'ESTANDAR', 'BAJO', 60, 1, 1),
(12, 'Minera Andina', 'Minera Andina S.A.', '20234567892', 'Cusco', 'Av. Sol 789, Cusco', 'Raul Gutierrez', 'rgutierrez@mineraandina.pe', '999111012', 'Gerente de Operaciones', 'EMPRESA', 'Mineria', 'VIP', 'ALTO', 500, 1, 1);

SET IDENTITY_INSERT TM_EMPRESA OFF;
GO
PRINT '  Inserted: 12 companies';
GO

-- ---------------------------------------------------------------------
-- TM_EMPRESA_SEDE (Company Locations)
-- ---------------------------------------------------------------------
INSERT INTO TM_EMPRESA_SEDE (IDEMPRESA, NOMBRESEDE, DOMICILIO, TELEFONO, CONTACTO_NOMBRE, ESPRINCIPAL, ACTIVO, USUARIOCREA) VALUES
(1, 'Sede Principal Lima', 'Av. Javier Prado 1234, San Isidro', '01-4567890', 'Roberto Diaz', 1, 1, 1),
(1, 'Sucursal Arequipa', 'Av. Ejercito 567, Arequipa', '054-234567', 'Ana Flores', 0, 1, 1),
(2, 'Sede Principal', 'Jr. Union 567, Cercado de Lima', '01-3456789', 'Patricia Luna', 1, 1, 1),
(3, 'Planta Principal Callao', 'Av. Argentina 890, Callao', '01-4567891', 'Fernando Rojas', 1, 1, 1),
(3, 'Oficina Administrativa Lima', 'Av. Arequipa 234, Lima', '01-2345678', 'Martha Soto', 0, 1, 1),
(5, 'Sede Trujillo', 'Av. España 456, Trujillo', '044-567890', 'Miguel Angel Ruiz', 1, 1, 1),
(5, 'Sede Chiclayo', 'Av. Balta 123, Chiclayo', '074-234567', 'Carlos Medina', 0, 1, 1),
(7, 'Terminal Lima', 'Av. Colonial 1234, Callao', '01-5678901', 'Jose Campos', 1, 1, 1),
(10, 'Sede Arequipa', 'Av. Ejercito 123, Arequipa', '054-345678', 'Rosa Paredes', 1, 1, 1),
(10, 'Sede Tacna', 'Av. Bolognesi 456, Tacna', '052-234567', 'Luis Torres', 0, 1, 1),
(12, 'Oficina Cusco', 'Av. Sol 789, Cusco', '084-234567', 'Raul Gutierrez', 1, 1, 1);
GO
PRINT '  Inserted: 11 company locations';
GO

-- ---------------------------------------------------------------------
-- TM_SEGUIMIENTO (Follow-ups)
-- Using variables for date calculations
-- ---------------------------------------------------------------------
DECLARE @Today DATE = CAST(GETDATE() AS DATE);
DECLARE @Yesterday DATE = DATEADD(DAY, -1, @Today);
DECLARE @TwoDaysAgo DATE = DATEADD(DAY, -2, @Today);
DECLARE @ThreeDaysAgo DATE = DATEADD(DAY, -3, @Today);
DECLARE @OneWeekAgo DATE = DATEADD(DAY, -7, @Today);
DECLARE @TwoWeeksAgo DATE = DATEADD(DAY, -14, @Today);
DECLARE @Tomorrow DATE = DATEADD(DAY, 1, @Today);
DECLARE @InTwoDays DATE = DATEADD(DAY, 2, @Today);
DECLARE @InThreeDays DATE = DATEADD(DAY, 3, @Today);

-- For user 4 (ejecutivo1, reports to supervisor1)
INSERT INTO TM_SEGUIMIENTO (IDEMPRESA, IDTIPOSEGUIMIENTO, IDUSUARIOASIGNADO, FECHAPROGRAMADA, HORAPROGRAMADA, PRIORIDAD, ESTADO, NOTAS, FECHACOMPLETADO, RESULTADO, USUARIOCREA) VALUES
-- Today's follow-ups
(1, 1, 4, @Today, '09:00', 'ALTA', 'PENDIENTE', 'Llamar para presentar nuevo producto', NULL, NULL, 1),
(2, 2, 4, @Today, '10:30', 'MEDIA', 'PENDIENTE', 'Seguimiento cotizacion enviada', NULL, NULL, 1),
(3, 3, 4, @Today, '14:00', 'ALTA', 'PENDIENTE', 'Visita programada con gerente', NULL, NULL, 1),
-- Completed yesterday
(4, 2, 4, @Yesterday, '11:00', 'MEDIA', 'COMPLETADO', 'Seguimiento realizado', DATEADD(HOUR, 11, CAST(@Yesterday AS DATETIME)), 'EXITOSO', 1),
(5, 5, 4, @Yesterday, '15:00', 'ALTA', 'COMPLETADO', 'Propuesta enviada y aceptada', DATEADD(HOUR, 15, CAST(@Yesterday AS DATETIME)), 'EXITOSO', 1),
-- Overdue (forgotten)
(6, 1, 4, @TwoWeeksAgo, '09:00', 'MEDIA', 'PENDIENTE', 'Llamada pendiente desde hace tiempo', NULL, NULL, 1),
(7, 2, 4, @OneWeekAgo, '10:00', 'BAJA', 'PENDIENTE', 'Seguimiento olvidado', NULL, NULL, 1),
-- Future
(8, 4, 4, @Tomorrow, '11:00', 'MEDIA', 'PENDIENTE', 'Reunion virtual programada', NULL, NULL, 1),
(1, 6, 4, @InTwoDays, '15:00', 'ALTA', 'PENDIENTE', 'Cierre de venta esperado', NULL, NULL, 1);

-- For user 5 (ejecutivo2, reports to supervisor1)
INSERT INTO TM_SEGUIMIENTO (IDEMPRESA, IDTIPOSEGUIMIENTO, IDUSUARIOASIGNADO, FECHAPROGRAMADA, HORAPROGRAMADA, PRIORIDAD, ESTADO, NOTAS, FECHACOMPLETADO, RESULTADO, USUARIOCREA) VALUES
(9, 1, 5, @Today, '09:30', 'ALTA', 'PENDIENTE', 'Primera llamada a prospecto VIP', NULL, NULL, 1),
(10, 3, 5, @Today, '14:30', 'MEDIA', 'PENDIENTE', 'Visita de presentacion', NULL, NULL, 1),
(11, 2, 5, @Yesterday, '10:00', 'MEDIA', 'COMPLETADO', 'Seguimiento exitoso', DATEADD(HOUR, 10, CAST(@Yesterday AS DATETIME)), 'EXITOSO', 1),
(12, 1, 5, @OneWeekAgo, '09:00', 'BAJA', 'PENDIENTE', 'Llamada pendiente', NULL, NULL, 1);

-- For user 6 (ejecutivo3, reports to supervisor1)
INSERT INTO TM_SEGUIMIENTO (IDEMPRESA, IDTIPOSEGUIMIENTO, IDUSUARIOASIGNADO, FECHAPROGRAMADA, HORAPROGRAMADA, PRIORIDAD, ESTADO, NOTAS, FECHACOMPLETADO, RESULTADO, USUARIOCREA) VALUES
(1, 7, 6, @Today, '10:00', 'MEDIA', 'PENDIENTE', 'Llamada post-venta', NULL, NULL, 1),
(2, 8, 6, @Tomorrow, '11:00', 'BAJA', 'PENDIENTE', 'Reactivar cuenta inactiva', NULL, NULL, 1),
(3, 2, 6, @ThreeDaysAgo, '09:00', 'ALTA', 'COMPLETADO', 'Seguimiento completado', DATEADD(HOUR, 9, CAST(@ThreeDaysAgo AS DATETIME)), 'SIN_RESPUESTA', 1);

-- For user 7 (ejecutivo4, reports to supervisor2)
INSERT INTO TM_SEGUIMIENTO (IDEMPRESA, IDTIPOSEGUIMIENTO, IDUSUARIOASIGNADO, FECHAPROGRAMADA, HORAPROGRAMADA, PRIORIDAD, ESTADO, NOTAS, FECHACOMPLETADO, RESULTADO, USUARIOCREA) VALUES
(4, 1, 7, @Today, '09:00', 'ALTA', 'PENDIENTE', 'Llamada a nuevo prospecto', NULL, NULL, 1),
(5, 5, 7, @Today, '14:00', 'ALTA', 'PENDIENTE', 'Enviar propuesta formal', NULL, NULL, 1),
(6, 2, 7, @Yesterday, '11:00', 'MEDIA', 'COMPLETADO', 'Seguimiento realizado', DATEADD(HOUR, 11, CAST(@Yesterday AS DATETIME)), 'EXITOSO', 1),
(7, 3, 7, @TwoWeeksAgo, '10:00', 'MEDIA', 'PENDIENTE', 'Visita postergada varias veces', NULL, NULL, 1);

-- For user 8 (ejecutivo5, reports to supervisor2)
INSERT INTO TM_SEGUIMIENTO (IDEMPRESA, IDTIPOSEGUIMIENTO, IDUSUARIOASIGNADO, FECHAPROGRAMADA, HORAPROGRAMADA, PRIORIDAD, ESTADO, NOTAS, FECHACOMPLETADO, RESULTADO, USUARIOCREA) VALUES
(8, 1, 8, @Today, '10:00', 'MEDIA', 'PENDIENTE', 'Primera llamada restaurante', NULL, NULL, 1),
(9, 4, 8, @InThreeDays, '15:00', 'ALTA', 'PENDIENTE', 'Reunion virtual agendada', NULL, NULL, 1),
(10, 2, 8, @TwoDaysAgo, '09:00', 'MEDIA', 'COMPLETADO', 'Seguimiento exitoso', DATEADD(HOUR, 9, CAST(@TwoDaysAgo AS DATETIME)), 'EXITOSO', 1),
(11, 6, 8, @Yesterday, '16:00', 'ALTA', 'COMPLETADO', 'Venta cerrada!', DATEADD(HOUR, 16, CAST(@Yesterday AS DATETIME)), 'EXITOSO', 1);
GO
PRINT '  Inserted: 24 follow-ups';
GO

-- ---------------------------------------------------------------------
-- TM_SEGUIMIENTO_DETALLE (Follow-up Details)
-- ---------------------------------------------------------------------
INSERT INTO TM_SEGUIMIENTO_DETALLE (IDSEGUIMIENTO, TIPOCOMUNICACION, FECHA1ERCONTACTO, ESTATUSCLIENTE, DETALLEESTATUS, TIPOLLAMADA, PRESUPUESTO, OBSERVACIONES, USUARIOCREA) VALUES
(1, 'TELEFONO', DATEADD(DAY, -30, GETDATE()), 'PROSPECTO', 'Interesado en productos premium', 'SALIENTE', 15000.00, 'Cliente con alto potencial', 1),
(2, 'EMAIL', DATEADD(DAY, -15, GETDATE()), 'COTIZADO', 'Cotizacion enviada pendiente respuesta', 'N/A', 8500.00, 'Esperando aprobacion de gerencia', 1),
(3, 'PRESENCIAL', DATEADD(DAY, -45, GETDATE()), 'NEGOCIACION', 'En proceso de negociacion de precios', 'N/A', 45000.00, 'Cliente importante - dar seguimiento prioritario', 1),
(4, 'TELEFONO', DATEADD(DAY, -60, GETDATE()), 'CERRADO', 'Venta concretada', 'SALIENTE', 12000.00, 'Cliente satisfecho', 1),
(5, 'EMAIL', DATEADD(DAY, -20, GETDATE()), 'CERRADO', 'Propuesta aceptada', 'N/A', 25000.00, 'Firma de contrato pendiente', 1),
(9, 'TELEFONO', DATEADD(DAY, -5, GETDATE()), 'PROSPECTO', 'Primer contacto realizado', 'SALIENTE', 5000.00, 'Cliente pyme con potencial', 1),
(10, 'PRESENCIAL', DATEADD(DAY, -10, GETDATE()), 'COTIZADO', 'Visita realizada, cotizacion enviada', 'N/A', 35000.00, 'Empresa grande, decision en comite', 1),
(17, 'TELEFONO', DATEADD(DAY, -3, GETDATE()), 'PROSPECTO', 'Nuevo prospecto interesado', 'SALIENTE', 7500.00, 'Requiere presentacion formal', 1),
(18, 'EMAIL', DATEADD(DAY, -7, GETDATE()), 'NEGOCIACION', 'Negociando terminos', 'N/A', 18000.00, 'Pendiente aprobacion de descuento', 1),
(21, 'TELEFONO', DATEADD(DAY, -1, GETDATE()), 'PROSPECTO', 'Contacto inicial restaurante', 'SALIENTE', 3500.00, 'Interesado en servicios basicos', 1);
GO
PRINT '  Inserted: 10 follow-up details';
GO

-- ---------------------------------------------------------------------
-- TM_INTERACCION (Interaction History)
-- ---------------------------------------------------------------------
DECLARE @Today2 DATE = CAST(GETDATE() AS DATE);
DECLARE @Yesterday2 DATE = DATEADD(DAY, -1, @Today2);
DECLARE @TwoDaysAgo2 DATE = DATEADD(DAY, -2, @Today2);
DECLARE @ThreeDaysAgo2 DATE = DATEADD(DAY, -3, @Today2);
DECLARE @OneWeekAgo2 DATE = DATEADD(DAY, -7, @Today2);

INSERT INTO TM_INTERACCION (IDEMPRESA, IDSEGUIMIENTO, IDUSUARIO, FECHAINTERACCION, TIPOINTERACCION, DESCRIPCION, RESULTADO, DURACIONMINUTOS, USUARIOCREA) VALUES
-- User 4 interactions
(1, 1, 4, DATEADD(HOUR, 9, CAST(@Today2 AS DATETIME)), 'LLAMADA', 'Llamada inicial de presentacion', 'CONTACTADO', 15, 1),
(2, 2, 4, DATEADD(HOUR, 10, CAST(@Today2 AS DATETIME)), 'LLAMADA', 'Seguimiento de cotizacion', 'PENDIENTE_RESPUESTA', 10, 1),
(4, 4, 4, DATEADD(HOUR, 11, CAST(@Yesterday2 AS DATETIME)), 'LLAMADA', 'Seguimiento completado exitosamente', 'EXITOSO', 20, 1),
(5, 5, 4, DATEADD(HOUR, 15, CAST(@Yesterday2 AS DATETIME)), 'EMAIL', 'Envio de propuesta formal', 'ACEPTADO', 5, 1),
-- User 5 interactions
(9, 9, 5, DATEADD(HOUR, 9, CAST(@Today2 AS DATETIME)), 'LLAMADA', 'Primera llamada a cliente VIP', 'CONTACTADO', 25, 1),
(11, 11, 5, DATEADD(HOUR, 10, CAST(@Yesterday2 AS DATETIME)), 'LLAMADA', 'Seguimiento exitoso', 'EXITOSO', 15, 1),
-- User 6 interactions
(1, 14, 6, DATEADD(HOUR, 10, CAST(@Today2 AS DATETIME)), 'LLAMADA', 'Llamada post-venta', 'SATISFECHO', 10, 1),
(3, 16, 6, DATEADD(HOUR, 9, CAST(@ThreeDaysAgo2 AS DATETIME)), 'LLAMADA', 'Intento de contacto', 'SIN_RESPUESTA', 5, 1),
-- User 7 interactions
(4, 17, 7, DATEADD(HOUR, 9, CAST(@Today2 AS DATETIME)), 'LLAMADA', 'Llamada de prospeccion', 'CONTACTADO', 20, 1),
(6, 19, 7, DATEADD(HOUR, 11, CAST(@Yesterday2 AS DATETIME)), 'LLAMADA', 'Seguimiento completado', 'EXITOSO', 15, 1),
-- User 8 interactions
(8, 21, 8, DATEADD(HOUR, 10, CAST(@Today2 AS DATETIME)), 'LLAMADA', 'Primera llamada a restaurante', 'CONTACTADO', 12, 1),
(10, 23, 8, DATEADD(HOUR, 9, CAST(@TwoDaysAgo2 AS DATETIME)), 'LLAMADA', 'Seguimiento positivo', 'EXITOSO', 18, 1),
(11, 24, 8, DATEADD(HOUR, 16, CAST(@Yesterday2 AS DATETIME)), 'PRESENCIAL', 'Reunion de cierre', 'VENTA_CERRADA', 45, 1),
-- Additional historical interactions
(1, NULL, 4, DATEADD(DAY, -10, GETDATE()), 'EMAIL', 'Envio de informacion inicial', 'ENVIADO', 5, 1),
(2, NULL, 4, DATEADD(DAY, -8, GETDATE()), 'LLAMADA', 'Llamada de seguimiento', 'CONTACTADO', 12, 1),
(3, NULL, 6, DATEADD(DAY, -15, GETDATE()), 'VISITA', 'Visita de presentacion', 'POSITIVO', 60, 1),
(5, NULL, 7, DATEADD(DAY, -20, GETDATE()), 'EMAIL', 'Propuesta inicial', 'ENVIADO', 10, 1),
(9, NULL, 5, DATEADD(DAY, -5, GETDATE()), 'LLAMADA', 'Contacto inicial', 'INTERESADO', 15, 1),
(12, NULL, 8, DATEADD(DAY, -12, GETDATE()), 'VISITA', 'Presentacion en sitio', 'MUY_INTERESADO', 90, 1),
(7, NULL, 7, DATEADD(DAY, -25, GETDATE()), 'LLAMADA', 'Seguimiento de transporte', 'PENDIENTE', 8, 1);
GO
PRINT '  Inserted: 20 interactions';
GO

-- ---------------------------------------------------------------------
-- TM_VENTA (Sales)
-- ---------------------------------------------------------------------
DECLARE @Today3 DATE = CAST(GETDATE() AS DATE);

INSERT INTO TM_VENTA (IDEMPRESA, IDSEGUIMIENTO, IDUSUARIO, FECHAVENTA, MONTO, MONEDA, DESCRIPCION, PRODUCTO, ESTADO, USUARIOCREA) VALUES
(4, 4, 4, DATEADD(DAY, -1, @Today3), 12000.00, 'PEN', 'Venta de servicios basicos', 'Plan Basico', 'CERRADA', 1),
(5, 5, 4, DATEADD(DAY, -1, @Today3), 25000.00, 'PEN', 'Venta de paquete premium', 'Plan Premium', 'CERRADA', 1),
(11, 11, 5, DATEADD(DAY, -1, @Today3), 8500.00, 'PEN', 'Servicio educativo', 'Licencia Educativa', 'CERRADA', 1),
(6, 19, 7, DATEADD(DAY, -1, @Today3), 5500.00, 'PEN', 'Venta a farmacia', 'Plan Pyme', 'CERRADA', 1),
(11, 24, 8, DATEADD(DAY, -1, @Today3), 18000.00, 'PEN', 'Venta cerrada ayer', 'Plan Empresarial', 'CERRADA', 1),
-- Historical sales
(1, NULL, 4, DATEADD(DAY, -15, @Today3), 35000.00, 'PEN', 'Contrato anual TechCorp', 'Plan Enterprise', 'CERRADA', 1),
(3, NULL, 6, DATEADD(DAY, -20, @Today3), 45000.00, 'PEN', 'Proyecto industrial', 'Solucion Industrial', 'CERRADA', 1),
(12, NULL, 8, DATEADD(DAY, -10, @Today3), 75000.00, 'USD', 'Contrato minero grande', 'Plan Mining Pro', 'CERRADA', 1);
GO
PRINT '  Inserted: 8 sales';
GO

-- ---------------------------------------------------------------------
-- TM_NOTIFICACION (Notifications - HU007)
-- ---------------------------------------------------------------------
DECLARE @Today4 DATE = CAST(GETDATE() AS DATE);

INSERT INTO TM_NOTIFICACION (IDUSUARIO, TITULO, MENSAJE, TIPO, LEIDA, TIPOENTIDAD, IDREFERENCIAENTIDAD) VALUES
-- For user 4 (ejecutivo1)
(4, 'Seguimiento pendiente hoy', 'Tienes 3 seguimientos programados para hoy', 'RECORDATORIO', 0, 'SEGUIMIENTO', 1),
(4, 'Seguimiento atrasado', 'El seguimiento con Farmacia Salud Total tiene 14 dias de atraso', 'ALERTA', 0, 'SEGUIMIENTO', 6),
(4, 'Nueva empresa asignada', 'Se te ha asignado TechCorp Peru como cliente', 'INFO', 1, 'EMPRESA', 1),
(4, 'Meta mensual alcanzada', 'Has alcanzado el 85% de tu meta mensual', 'INFO', 1, NULL, NULL),
-- For user 5 (ejecutivo2)
(5, 'Reunion virtual manana', 'Recuerda tu reunion virtual con Agropecuaria Sur', 'RECORDATORIO', 0, 'SEGUIMIENTO', 10),
(5, 'Seguimiento completado', 'Tu seguimiento con Educacion Digital fue marcado como exitoso', 'INFO', 1, 'SEGUIMIENTO', 11),
-- For user 6 (ejecutivo3)
(6, 'Post-venta pendiente', 'Tienes una llamada de post-venta programada para hoy', 'RECORDATORIO', 0, 'SEGUIMIENTO', 14),
(6, 'Venta registrada', 'Se ha registrado tu venta con Industrias XYZ por S/45,000', 'INFO', 1, 'VENTA', 7),
-- For user 7 (ejecutivo4)
(7, 'Propuesta urgente', 'Debes enviar la propuesta a Constructora Norte hoy', 'URGENTE', 0, 'SEGUIMIENTO', 18),
(7, 'Seguimiento muy atrasado', 'Tienes un seguimiento con 14 dias de atraso', 'ALERTA', 0, 'SEGUIMIENTO', 20),
(7, 'Buen trabajo!', 'Completaste 5 seguimientos esta semana', 'INFO', 1, NULL, NULL),
-- For user 8 (ejecutivo5)
(8, 'Venta cerrada!', 'Felicitaciones! Cerraste la venta con Educacion Digital', 'INFO', 0, 'VENTA', 5),
(8, 'Reunion en 3 dias', 'Tienes una reunion virtual con Consultora Legal Plus', 'RECORDATORIO', 0, 'SEGUIMIENTO', 22),
-- For supervisors
(2, 'Reporte semanal listo', 'El reporte de tu equipo esta disponible', 'INFO', 0, NULL, NULL),
(2, 'Ejecutivo con atrasos', 'Juan Perez tiene 2 seguimientos con mas de 7 dias de atraso', 'ALERTA', 0, 'USUARIO', 4),
(3, 'Nuevo ejecutivo asignado', 'Se ha asignado un nuevo ejecutivo a tu equipo', 'INFO', 1, 'USUARIO', 8),
(3, 'Meta de equipo superada', 'Tu equipo ha superado la meta mensual!', 'INFO', 0, NULL, NULL),
-- For admin
(1, 'Backup completado', 'El backup de la base de datos se completo exitosamente', 'INFO', 1, NULL, NULL);
GO
PRINT '  Inserted: 18 notifications';
GO

PRINT '';
PRINT 'All sample data inserted successfully.';
PRINT 'Now run: 06_verification.sql';
GO
