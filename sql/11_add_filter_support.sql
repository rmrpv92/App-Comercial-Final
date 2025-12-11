-- =============================================
-- Script 11: Add Filter Support to Pending Stored Procedures
-- This updates usp_ObtenerPendientesAcumulados and usp_ObtenerPendientesOlvidados
-- to support filtering by PRIORIDAD and dates
-- =============================================

USE DB_APPCOMERCIAL;
GO

PRINT '=== Updating Stored Procedures with Filter Support ===';
GO

-- =====================================================================
-- HU005: Updated Pendientes Acumulados with Filters
-- =====================================================================
CREATE OR ALTER PROCEDURE usp_ObtenerPendientesAcumulados
    @IdUsuario INT,
    @Prioridad NVARCHAR(16) = NULL,    -- Optional: ALTA, MEDIA, BAJA
    @FechaIni DATE = NULL,              -- Optional: Start date filter
    @FechaFin DATE = NULL               -- Optional: End date filter
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
    WHERE s.ESTADO IN ('PENDIENTE', 'EN_PROCESO', 'NUEVO')
      AND s.ACTIVO = 1
      -- Role-based access
      AND (
          @IdPerfil = 1 -- Admin sees all
          OR (@IdPerfil = 2 AND u.IDSUPERVISOR = @IdUsuario) -- Supervisor sees team
          OR (@IdPerfil = 3 AND s.IDUSUARIOASIGNADO = @IdUsuario) -- Ejecutivo sees own
      )
      -- Optional filters
      AND (@Prioridad IS NULL OR s.PRIORIDAD = @Prioridad)
      AND (@FechaIni IS NULL OR s.FECHAPROGRAMADA >= @FechaIni)
      AND (@FechaFin IS NULL OR s.FECHAPROGRAMADA <= @FechaFin)
    ORDER BY 
        CASE s.PRIORIDAD WHEN 'ALTA' THEN 1 WHEN 'MEDIA' THEN 2 ELSE 3 END,
        s.FECHAPROGRAMADA ASC;
END;
GO
PRINT '  Updated: usp_ObtenerPendientesAcumulados with filter support';
GO

-- =====================================================================
-- HU004: Updated Pendientes Olvidados with Filters
-- =====================================================================
CREATE OR ALTER PROCEDURE usp_ObtenerPendientesOlvidados
    @IdUsuario INT,
    @DiasAntiguedad INT = 7,
    @Prioridad NVARCHAR(16) = NULL,    -- Optional: ALTA, MEDIA, BAJA
    @FechaHasta DATE = NULL             -- Optional: Up to date filter
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IdPerfil INT;
    SELECT @IdPerfil = IDPERFIL FROM TM_USUARIO WHERE IDUSUARIO = @IdUsuario;
    
    SELECT 
        s.IDSEGUIMIENTO,
        s.FECHAPROGRAMADA,
        DATEDIFF(DAY, s.FECHAPROGRAMADA, GETDATE()) AS DiasAtraso,
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
    WHERE s.ESTADO IN ('PENDIENTE', 'EN_PROCESO', 'NUEVO')
      AND s.FECHAPROGRAMADA < CAST(GETDATE() AS DATE)
      AND DATEDIFF(DAY, s.FECHAPROGRAMADA, GETDATE()) >= @DiasAntiguedad
      AND s.ACTIVO = 1
      -- Role-based access
      AND (
          @IdPerfil = 1 -- Admin sees all
          OR (@IdPerfil = 2 AND u.IDSUPERVISOR = @IdUsuario) -- Supervisor sees team
          OR (@IdPerfil = 3 AND s.IDUSUARIOASIGNADO = @IdUsuario) -- Ejecutivo sees own
      )
      -- Optional filters
      AND (@Prioridad IS NULL OR s.PRIORIDAD = @Prioridad)
      AND (@FechaHasta IS NULL OR s.FECHAPROGRAMADA <= @FechaHasta)
    ORDER BY s.FECHAPROGRAMADA ASC;
END;
GO
PRINT '  Updated: usp_ObtenerPendientesOlvidados with filter support';
GO

PRINT '=== Testing Updated Stored Procedures ===';
GO

-- Test acumulados with filter
PRINT 'Testing usp_ObtenerPendientesAcumulados with ALTA filter:';
EXEC usp_ObtenerPendientesAcumulados @IdUsuario = 1, @Prioridad = 'ALTA';
GO

PRINT 'Testing usp_ObtenerPendientesAcumulados without filter (all):';
EXEC usp_ObtenerPendientesAcumulados @IdUsuario = 1;
GO

PRINT '=== Script complete ===';
