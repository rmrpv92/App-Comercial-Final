// ...existing code...
import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators, FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { Auth } from '../../services/auth';
import { EmpresaService } from '../../services/empresa';
import { SeguimientoService } from '../../services/seguimiento';
import { DashboardService } from '../../services/dashboard';
import { NotificacionService, Alerta, Notificacion, NotificacionesResponse } from '../../services/notificacion';
import { Subscription } from 'rxjs';

@Component({
  standalone: true,
  selector: 'app-app-comercial',
  imports: [CommonModule, FormsModule, ReactiveFormsModule],
  templateUrl: './app-comercial.html',
  styleUrls: ['./app-comercial.css']
})
export class AppComercialComponent implements OnInit, OnDestroy {
  // All available tabs with their HU mapping and required role levels
  // IDPERFIL: 1=ADMIN, 2=SUPERVISOR, 3=EJECUTIVO
  allViewTabs = [
    { name: 'BÚSQUEDA', hu: null, minRole: 3 },           // Index 0 - All users
    { name: 'AGENDA DEL DÍA', hu: 'HU002', minRole: 3 },  // Index 1 - All users
    { name: 'DASHBOARD', hu: 'HU003', minRole: 3 },       // Index 2 - All users
    { name: 'PENDIENTES ACUMULADOS', hu: 'HU005', minRole: 3 }, // Index 3 - All users
    { name: 'PENDIENTES OLVIDADOS', hu: 'HU004', minRole: 3 },  // Index 4 - All users
    { name: 'MONITOREO', hu: 'HU006', minRole: 2 },       // Index 5 - Supervisors & Admin only
    { name: 'VENTAS CERRADAS', hu: 'HU008', minRole: 3 }, // Index 6 - All users
    { name: 'PRODUCCIÓN', hu: 'HU010', minRole: 2 }       // Index 7 - Supervisors & Admin only
  ];
  
  // Filtered tabs based on user role (populated in ngOnInit)
  viewTabs: string[] = [];
  viewTabsMap: number[] = []; // Maps filtered index to original index
  
  activeView: number = 0; // tracks which top navigation tab is active
  currentUserRole: number = 3; // Default to EJECUTIVO (most restrictive)
  
  tabs = ['DATOS EMPRESA', 'SEGUIMIENTO', 'HISTORICO', 'PROTOCOLOS Y COTIZACIONES'];
  activeTab: number = 0;

  searchText = '';

  // Edit mode state for each tab
  isEditMode = false;
  isSeguimientoEditMode = false;
  isHistoricoEditMode = false;
  isProtocolosEditMode = false;

  // Track which row is being edited
  editingHistoricoIndex: number | null = null;
  editingProtocoloIndex: number | null = null;
  editingCotizacionIndex: number | null = null;

  // Backup for cancel functionality
  historicoBackup: any = null;
  protocoloBackup: any = null;
  cotizacionBackup: any = null;

  // Reactive form for DATOS EMPRESA
  datosEmpresaForm = this.fb.group({
    razonSocial: ['', Validators.required],
    ruc: ['', [Validators.required, Validators.pattern(/^\d{11}$/)]],
    sedePrincipal: [''],
    domicilio: [''],
    nombreContacto: ['', Validators.required],
    cargo: [''],
    email: ['', Validators.email],
    telefono: ['', Validators.pattern(/^\d{9}$/)],
    tipoEmpresa: [''],
    nroTrabajadores: ['', Validators.min(1)],
    actEconomica: [''],
    riesgo: [''],
    sedes: ['']
  });

  // Reactive form for SEGUIMIENTO
  seguimientoForm = this.fb.group({
    tipoCliente: [''],
    fecha1erCto: [''],
    tipoComunic: [''],
    tipoCartera: [''],
    lineaNegocio: [''],
    estatusCliente: [''],
    subLinea: [''],
    detalleEstatus: [''],
    tipoCredito: [''],
    tipoLlamada: [''],
    presupuesto: [''],
    observaciones: ['']
  });

  constructor(
    private fb: FormBuilder,
    private authService: Auth,
    private empresaService: EmpresaService,
    private seguimientoService: SeguimientoService,
    private dashboardService: DashboardService,
    private notificacionService: NotificacionService,
    private router: Router
  ) {}

  ngOnInit() {
    // Check if user is logged in
    if (!this.authService.isLoggedIn()) {
      this.router.navigate(['/login']);
      return;
    }

    this.currentUserId = this.authService.getUserId() || 0;
    this.currentUserName = this.authService.getCurrentUser()?.NOMBRES || 'Usuario';
    this.currentUserRole = this.authService.getCurrentUser()?.IDPERFIL || 3;
    
    console.log('=== AppComercial ngOnInit ===');
    console.log('Current User ID:', this.currentUserId);
    console.log('Current User Name:', this.currentUserName);
    console.log('Current User Role (IDPERFIL):', this.currentUserRole);
    console.log('Full user:', this.authService.getCurrentUser());

    // Filter tabs based on user role
    // Lower IDPERFIL = higher privilege (1=Admin, 2=Supervisor, 3=Ejecutivo)
    this.viewTabs = [];
    this.viewTabsMap = [];
    this.allViewTabs.forEach((tab, originalIndex) => {
      if (this.currentUserRole <= tab.minRole) {
        this.viewTabs.push(tab.name);
        this.viewTabsMap.push(originalIndex);
      }
    });
    console.log('Filtered tabs:', this.viewTabs);
    console.log('Tab mapping:', this.viewTabsMap);

    // Load initial data for the default view (BÚSQUEDA)
    this.loadCompanies();
    this.loadCompanyToForm();
    
    // Disable all form controls initially
    this.datosEmpresaForm.disable();
    this.seguimientoForm.disable();

    // Load notifications (HU007)
    this.loadNotificaciones();
    
    // Start polling for notifications every 60 seconds
    this.notificationSubscription = this.notificacionService.startPolling(this.currentUserId, 60)
      .subscribe({
        next: (data) => {
          this.alertas = data.alertas;
          this.notificaciones = data.notificaciones;
          this.unreadCount = data.noLeidos;
        },
        error: (err) => console.error('Error polling notifications:', err)
      });
  }

  /**
   * Switch between main views and load data accordingly
   * Uses viewTabsMap to convert filtered index to original tab index
   */
  switchView(filteredIndex: number) {
    // Get the original tab index from the mapping
    const originalIndex = this.viewTabsMap[filteredIndex];
    
    console.log('=== switchView called ===');
    console.log('Filtered index:', filteredIndex, 'Original index:', originalIndex);
    console.log('Tab name:', this.viewTabs[filteredIndex]);
    console.log('Current userId:', this.currentUserId);
    
    this.activeView = filteredIndex;
    this.errorMessage = '';
    
    // Load data based on the ORIGINAL tab index
    switch (originalIndex) {
      case 0: // BÚSQUEDA
        if (this.companies.length === 0) {
          this.loadCompanies();
        }
        break;
      case 1: // AGENDA DEL DÍA (HU002)
        this.loadAgendaDia();
        break;
      case 2: // DASHBOARD (HU003 - KPIs + Agenda resumen)
        this.loadDashboardData();
        break;
      case 3: // PENDIENTES ACUMULADOS (HU005)
        this.loadPendientesAcumulados();
        break;
      case 4: // PENDIENTES OLVIDADOS (HU004)
        this.loadPendientesOlvidados();
        break;
      case 5: // MONITOREO (HU006 - Calendar)
        this.loadSupervisorData();
        break;
      case 6: // VENTAS CERRADAS (HU008)
        this.loadCerrados();
        break;
      case 7: // PRODUCCIÓN (HU010)
        this.loadProduccionDiaria();
        break;
    }
  }

  /**
   * Get the original tab index for template conditionals
   */
  getOriginalTabIndex(filteredIndex: number): number {
    return this.viewTabsMap[filteredIndex] ?? -1;
  }

  ngOnDestroy() {
    // Clean up subscription when component is destroyed
    if (this.notificationSubscription) {
      this.notificationSubscription.unsubscribe();
    }
  }

  // Loading states
  isLoadingCompanies = false;
  isLoadingAgenda = false;
  isLoadingPendientes = false;
  isLoadingDashboard = false;
  isLoadingCerrados = false;
  isLoadingProduccion = false;
  isLoadingNotificaciones = false;
  
  // Error states
  errorMessage = '';

  // Current user info
  currentUserId = 0;
  currentUserName = '';

  // Notifications (HU007)
  alertas: Alerta[] = [];
  notificaciones: Notificacion[] = [];
  unreadCount = 0;
  showNotificationsPanel = false;
  notificationSubscription: Subscription | null = null;

  // ========================
  // NOTIFICATIONS METHODS (HU007)
  // ========================

  /**
   * Load notifications and alerts for current user
   */
  loadNotificaciones() {
    if (!this.currentUserId) return;
    
    this.isLoadingNotificaciones = true;
    this.notificacionService.getNotificaciones(this.currentUserId).subscribe({
      next: (data) => {
        this.alertas = data.alertas;
        this.notificaciones = data.notificaciones;
        this.unreadCount = data.noLeidos;
        this.isLoadingNotificaciones = false;
      },
      error: (err) => {
        console.error('Error loading notifications:', err);
        this.isLoadingNotificaciones = false;
      }
    });
  }

  /**
   * Toggle notifications panel visibility
   */
  toggleNotificationsPanel() {
    this.showNotificationsPanel = !this.showNotificationsPanel;
  }

  /**
   * Mark a notification as read
   */
  markAsRead(notification: Notificacion) {
    if (notification.LEIDO) return;
    
    this.notificacionService.marcarComoLeida(notification.IDNOTIFICACION).subscribe({
      next: () => {
        notification.LEIDO = true;
        this.unreadCount = Math.max(0, this.unreadCount - 1);
      },
      error: (err) => console.error('Error marking notification as read:', err)
    });
  }

  /**
   * Navigate to the follow-up from an alert
   */
  goToSeguimientoFromAlert(alerta: Alerta) {
    // Close notifications panel
    this.showNotificationsPanel = false;
    
    // Find and select the company
    const company = this.companies.find(c => c.id === alerta.IDEMPRESA);
    if (company) {
      this.selectCompany(company);
      this.activeView = 0; // Go to BÚSQUEDA view
      this.activeTab = 1; // Go to SEGUIMIENTO tab
    }
  }

  /**
   * Navigate to a company from the agenda view (AGENDA DEL DÍA)
   */
  goToEmpresaFromAgenda(item: any) {
    // Check if the company is already in our loaded list
    let company = this.companies.find(c => c.id === item.IDEMPRESA);
    
    if (company) {
      this.selectCompany(company);
      this.activeView = 0; // Switch to BÚSQUEDA view
      this.activeTab = 1; // Go to SEGUIMIENTO tab
    } else {
      // Company not in list - need to load it
      this.isLoadingCompanies = true;
      this.empresaService.buscarEmpresas(item.NOMBRECOMERCIAL, this.currentUserName).subscribe({
        next: (response: any) => {
          if (response && response.length > 0) {
            // Map API response to our Company interface
            this.companies = response.map((emp: any) => ({
              id: emp.IDEMPRESA,
              name: emp.NOMBRECOMERCIAL,
              ruc: emp.RUC || '',
              razonSocial: emp.RAZONSOCIAL || emp.NOMBRECOMERCIAL,
              direccion: emp.DIRECCION || '',
              contactoNombre: emp.CONTACTO_NOMBRE || '',
              contactoTelefono: emp.CONTACTO_TELEFONO || '',
              contactoEmail: emp.CONTACTO_EMAIL || '',
              contactoCargo: emp.CONTACTO_CARGO || '',
              contactoFechaNacimiento: emp.CONTACTO_FECHANACIMIENTO || '',
              estadoComercial: emp.ESTADOCOMERCIAL || 'PROSPECTO',
              asignadoA: emp.ASIGNADO_A || this.currentUserName,
              lastContact: emp.ULTIMOCONTACTO || new Date().toISOString().split('T')[0],
              segmento: emp.SEGMENTO || '',
              tipoNegocio: emp.TIPONEGOCIO || '',
              notas: emp.NOTAS || ''
            }));
            
            // Find and select the target company
            const targetCompany = this.companies.find(c => c.id === item.IDEMPRESA);
            if (targetCompany) {
              this.selectCompany(targetCompany);
              this.activeView = 0; // Switch to BÚSQUEDA view
              this.activeTab = 1; // Go to SEGUIMIENTO tab
            }
          }
          this.isLoadingCompanies = false;
        },
        error: (err: any) => {
          console.error('Error loading company from agenda:', err);
          this.isLoadingCompanies = false;
        }
      });
    }
  }

  // ========================
  // API INTEGRATION METHODS
  // ========================

  /**
   * Load companies from API (BÚSQUEDA view)
   */
  loadCompanies(searchText?: string) {
    this.isLoadingCompanies = true;
    this.errorMessage = '';

    this.empresaService.buscarEmpresas(searchText, this.currentUserName).subscribe({
      next: (response) => {
        if (response.isSuccess && response.data) {
          // Transform API data to match component structure
          // DB returns: IDEMPRESA, NOMBRECOMERCIAL, RAZONSOCIAL, RUC, TIPOCLIENTE, TIPOCARTERA, 
          //             CONTACTO_NOMBRE, CONTACTO_EMAIL, CONTACTO_TELEFONO
          this.companies = response.data.map((emp: any) => ({
            id: emp.IDEMPRESA,
            name: emp.NOMBRECOMERCIAL || emp.RAZONSOCIAL,
            contact: emp.CONTACTO_NOMBRE,
            phone: emp.CONTACTO_TELEFONO,
            user: this.currentUserName,
            ruc: emp.RUC,
            sedePrincipal: emp.SEDEPRINCIPAL,
            domicilio: emp.DOMICILIO,
            cargo: emp.CONTACTO_CARGO,
            email: emp.CONTACTO_EMAIL,
            tipoEmpresa: emp.TIPOCLIENTE,
            nroTrabajadores: emp.NUMTRABAJADORES?.toString() || '',
            actEconomica: emp.ACTIVIDADECONOMICA,
            riesgo: emp.RIESGO,
            sedes: '',
            tipoCartera: emp.TIPOCARTERA,
            lineaNegocio: emp.LINEANEGOCIO,
            follow: {
              tipoCliente: emp.TIPOCLIENTE || '',
              fecha1erCto: '',
              tipoComunic: '',
              tipoCartera: emp.TIPOCARTERA || '',
              lineaNegocio: emp.LINEANEGOCIO || '',
              estatusCliente: '',
              subLinea: emp.SUBLINEANEGOCIO || '',
              detalleEstatus: '',
              tipoCredito: emp.TIPOCREDITO || '',
              tipoLlamada: '',
              presupuesto: '',
              observaciones: ''
            },
            history: [],
            protocols: [],
            quotes: []
          }));

          if (this.companies.length > 0 && !this.selected) {
            this.selected = this.companies[0];
          }
        }
        this.isLoadingCompanies = false;
      },
      error: (error) => {
        console.error('Error loading companies:', error);
        this.errorMessage = 'Error al cargar empresas';
        this.isLoadingCompanies = false;
      }
    });
  }

  /**
   * Load company details including seguimiento, history, etc.
   */
  loadCompanyDetails(empresaId: number) {
    this.empresaService.obtenerEmpresa(empresaId).subscribe({
      next: (response) => {
        if (response.isSuccess && response.data) {
          const details = response.data;
          
          // Update selected company with full details from usp_ObtenerEmpresa
          // DB columns: IDEMPRESA, NOMBRECOMERCIAL, RAZONSOCIAL, RUC, SEDEPRINCIPAL, DOMICILIO,
          //             CONTACTO_NOMBRE, CONTACTO_EMAIL, CONTACTO_TELEFONO, CONTACTO_CARGO,
          //             TIPOCLIENTE, LINEANEGOCIO, SUBLINEANEGOCIO, TIPOCREDITO, TIPOCARTERA,
          //             ACTIVIDADECONOMICA, RIESGO, NUMTRABAJADORES
          if (this.selected && this.selected.id === empresaId) {
            // Update basic company info with full details
            this.selected.name = details.NOMBRECOMERCIAL || details.RAZONSOCIAL || this.selected.name;
            this.selected.ruc = details.RUC || this.selected.ruc;
            this.selected.sedePrincipal = details.SEDEPRINCIPAL || '';
            this.selected.domicilio = details.DOMICILIO || '';
            this.selected.contact = details.CONTACTO_NOMBRE || '';
            this.selected.cargo = details.CONTACTO_CARGO || '';
            this.selected.email = details.CONTACTO_EMAIL || '';
            this.selected.phone = details.CONTACTO_TELEFONO || '';
            this.selected.tipoEmpresa = details.TIPOCLIENTE || '';
            this.selected.tipoCartera = details.TIPOCARTERA || '';
            this.selected.lineaNegocio = details.LINEANEGOCIO || '';
            this.selected.actEconomica = details.ACTIVIDADECONOMICA || '';
            this.selected.riesgo = details.RIESGO || '';
            this.selected.nroTrabajadores = details.NUMTRABAJADORES?.toString() || '';
            
            // Update follow data from company info
            this.selected.follow.tipoCliente = details.TIPOCLIENTE || '';
            this.selected.follow.tipoCartera = details.TIPOCARTERA || '';
            this.selected.follow.lineaNegocio = details.LINEANEGOCIO || '';
            this.selected.follow.subLinea = details.SUBLINEANEGOCIO || '';
            this.selected.follow.tipoCredito = details.TIPOCREDITO || '';
            
            // Update seguimiento data from recent seguimientos
            if (details.seguimiento && Array.isArray(details.seguimiento) && details.seguimiento.length > 0) {
              const seg = details.seguimiento[0]; // Most recent
              this.selected.follow.estatusCliente = seg.ESTADO || '';
              this.selected.follow.observaciones = seg.RESULTADO || '';
              this.selected.follow.tipoComunic = seg.TIPOSEGUIMIENTO || '';
              this.selected.follow.fecha1erCto = seg.FECHAPROGRAMADA || '';
            }

            // Update history from seguimiento list
            if (details.seguimiento && Array.isArray(details.seguimiento)) {
              this.selected.history = details.seguimiento.map((h: any) => ({
                fecha: h.FECHAPROGRAMADA || '',
                status: h.ESTADO || '',
                contacto: h.TIPOSEGUIMIENTO || '',
                usuario: h.RESULTADO || ''
              }));
            }

            // Update sedes
            if (details.sedes && Array.isArray(details.sedes) && details.sedes.length > 0) {
              this.selected.sedes = details.sedes.length.toString();
            }
            
            // Refresh form with updated data
            this.loadCompanyToForm();
            this.loadSeguimientoToForm();
          }
        }
      },
      error: (error) => {
        console.error('Error loading company details:', error);
      }
    });
  }

  /**
   * Load daily agenda (AGENDA DEL DÍA view)
   */
  loadAgendaDia() {
    console.log('loadAgendaDia called, currentUserId:', this.currentUserId);
    if (this.currentUserId === 0) {
      console.log('Skipping agenda load - userId is 0');
      return;
    }

    this.isLoadingAgenda = true;
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
    console.log('Loading agenda for date:', today);

    this.seguimientoService.getAgendaDia(this.currentUserId, today).subscribe({
      next: (response) => {
        console.log('Agenda API response:', response);
        if (response.isSuccess && response.data) {
          // Store agenda data for display
          this.agendaDiaData = response.data;
          console.log('Agenda data loaded:', this.agendaDiaData.length, 'items');
        } else {
          console.log('Agenda response not successful or no data:', response);
        }
        this.isLoadingAgenda = false;
      },
      error: (error) => {
        console.error('Error loading agenda:', error);
        this.errorMessage = 'Error al cargar agenda del día';
        this.isLoadingAgenda = false;
      }
    });
  }

  /**
   * Load Dashboard data (HU003 - KPIs + Agenda del día)
   * This combines dashboard metrics and agenda data for the DASHBOARD tab
   */
  loadDashboardData() {
    console.log('loadDashboardData called, currentUserId:', this.currentUserId);
    if (this.currentUserId === 0) {
      console.log('Skipping dashboard load - userId is 0');
      return;
    }

    this.isLoadingDashboard = true;
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD

    // Load dashboard metrics (KPIs)
    this.dashboardService.getDashboard(today, this.currentUserId).subscribe({
      next: (response) => {
        console.log('Dashboard metrics response:', response);
        if (response.isSuccess && response.data) {
          this.dashboardMetrics = response.data;
        }
      },
      error: (error) => {
        console.error('Error loading dashboard metrics:', error);
      }
    });

    // Load agenda del día
    this.seguimientoService.getAgendaDia(this.currentUserId, today).subscribe({
      next: (response) => {
        console.log('Dashboard agenda response:', response);
        if (response.isSuccess && response.data) {
          this.agendaDiaData = response.data;
        }
        this.isLoadingDashboard = false;
      },
      error: (error) => {
        console.error('Error loading agenda for dashboard:', error);
        this.isLoadingDashboard = false;
      }
    });
  }

  /**
   * Load accumulated pending (PENDIENTES ACUMULADOS view - HU005)
   */
  loadPendientesAcumulados() {
    console.log('loadPendientesAcumulados called, currentUserId:', this.currentUserId);
    if (this.currentUserId === 0) {
      console.log('Skipping pendientes load - userId is 0');
      return;
    }

    this.isLoadingPendientes = true;

    const prioridad = this.prioridadFilterAcumulados !== 'Todos' ? this.prioridadFilterAcumulados : undefined;
    const fechaIni = this.fechaInicioAcumulados || undefined;
    const fechaFin = this.fechaFinAcumulados || undefined;
    
    console.log('Loading pendientes with filters:', { prioridad, fechaIni, fechaFin });

    this.seguimientoService.getPendientesAcumulados(this.currentUserId, prioridad, fechaIni, fechaFin).subscribe({
      next: (response) => {
        console.log('Pendientes API response:', response);
        if (response.isSuccess && response.data) {
          // Map API response to display format
          // SP returns: IDSEGUIMIENTO, FECHAPROGRAMADA, DiasAcumulado, PRIORIDAD, ESTADO, 
          //             NOMBRECOMERCIAL, CONTACTO_NOMBRE, CONTACTO_TELEFONO, TIPOSEGUIMIENTO
          this.pendientesAcumulados = response.data.map((p: any) => ({
            id: p.IDSEGUIMIENTO,
            fecha: p.FECHAPROGRAMADA ? new Date(p.FECHAPROGRAMADA).toLocaleDateString('es-PE') : '',
            cliente: p.NOMBRECOMERCIAL || p.EMPRESA || '',
            contacto: p.CONTACTO_NOMBRE || p.CONTACTO || '',
            telefono: p.CONTACTO_TELEFONO || '',
            prioridad: p.PRIORIDAD || '',
            estado: p.ESTADO || '',
            tipo: p.TIPOSEGUIMIENTO || '',
            diasAcumulado: p.DiasAcumulado || 0,
            estatusFecha: p.EstatusFecha || ''
          }));
          console.log('Pendientes mapped:', this.pendientesAcumulados.length, 'items');
        } else {
          console.log('Pendientes response not successful or no data');
          this.pendientesAcumulados = [];
        }
        this.isLoadingPendientes = false;
      },
      error: (error) => {
        console.error('Error loading pendientes acumulados:', error);
        this.errorMessage = 'Error al cargar pendientes acumulados';
        this.pendientesAcumulados = [];
        this.isLoadingPendientes = false;
      }
    });
  }

  /**
   * Load forgotten pending (PENDIENTES OLVIDADOS view - HU004)
   */
  loadPendientesOlvidados() {
    if (this.currentUserId === 0) return;

    this.isLoadingPendientes = true;

    const prioridad = this.prioridadFilterOlvidados !== 'Todos' ? this.prioridadFilterOlvidados : undefined;
    const fechaHasta = this.fechaFinOlvidados || undefined;

    this.seguimientoService.getPendientesOlvidados(this.currentUserId, prioridad, fechaHasta).subscribe({
      next: (response) => {
        if (response.isSuccess && response.data) {
          // Map API response to display format
          // SP returns: IDSEGUIMIENTO, FECHAPROGRAMADA, DiasAtraso, PRIORIDAD, ESTADO,
          //             NOMBRECOMERCIAL, CONTACTO_NOMBRE, CONTACTO_TELEFONO, TIPOSEGUIMIENTO
          this.pendientesOlvidados = response.data.map((p: any) => ({
            id: p.IDSEGUIMIENTO,
            fecha: p.FECHAPROGRAMADA ? new Date(p.FECHAPROGRAMADA).toLocaleDateString('es-PE') : '',
            cliente: p.NOMBRECOMERCIAL || p.EMPRESA || '',
            contacto: p.CONTACTO_NOMBRE || p.CONTACTO || '',
            telefono: p.CONTACTO_TELEFONO || '',
            prioridad: p.PRIORIDAD || '',
            estado: p.ESTADO || '',
            tipo: p.TIPOSEGUIMIENTO || '',
            diasAtraso: p.DiasAtraso || 0
          }));
        } else {
          this.pendientesOlvidados = [];
        }
        this.isLoadingPendientes = false;
      },
      error: (error) => {
        console.error('Error loading pendientes olvidados:', error);
        this.errorMessage = 'Error al cargar pendientes olvidados';
        this.pendientesOlvidados = [];
        this.isLoadingPendientes = false;
      }
    });
  }

  /**
   * Load supervisor dashboard and calendar (ASIG. SUPERVISOR view)
   */
  loadSupervisorData() {
    this.isLoadingDashboard = true;
    const today = new Date().toISOString().split('T')[0];

    // Load dashboard metrics
    this.dashboardService.getDashboard(today, this.currentUserId).subscribe({
      next: (response) => {
        if (response.isSuccess && response.data) {
          this.dashboardMetrics = response.data;
        }
        this.isLoadingDashboard = false;
      },
      error: (error) => {
        console.error('Error loading dashboard:', error);
        this.isLoadingDashboard = false;
      }
    });

    // Load calendar (current week)
    const startOfWeek = this.getStartOfWeek();
    const endOfWeek = this.getEndOfWeek();

    this.dashboardService.getCalendario(startOfWeek, endOfWeek, this.currentUserId).subscribe({
      next: (response) => {
        if (response.isSuccess && response.data) {
          this.calendarioData = response.data;
        }
      },
      error: (error) => {
        console.error('Error loading calendario:', error);
      }
    });
  }

  /**
   * Load closed sales (CERRADOS view)
   */
  loadCerrados() {
    this.isLoadingCerrados = true;

    // Get current week dates
    const startOfWeek = this.getStartOfWeek();
    const endOfWeek = this.getEndOfWeek();

    this.dashboardService.getCerrados(startOfWeek, endOfWeek, this.currentUserId).subscribe({
      next: (response) => {
        if (response.isSuccess && response.data) {
          this.cerradosData = response.data;
        }
        this.isLoadingCerrados = false;
      },
      error: (error) => {
        console.error('Error loading cerrados:', error);
        this.errorMessage = 'Error al cargar ventas cerradas';
        this.isLoadingCerrados = false;
      }
    });
  }

  /**
   * Load daily production (PROD. DÍA view - HU010)
   */
  loadProduccionDiaria() {
    this.isLoadingProduccion = true;
    const today = new Date().toISOString().split('T')[0];

    this.dashboardService.getProduccion(today, this.currentUserId).subscribe({
      next: (response) => {
        if (response.isSuccess && response.data) {
          // SP returns: IDUSUARIO, USUARIO, NOMBRE, CONTACTOS_DEL_DIA, PENDIENTES_DEL_DIA, TOTAL_DEL_DIA
          // Or single user: Fecha, TotalProgramados, Completados, Pendientes, Interacciones, VentasDelDia
          if (Array.isArray(response.data)) {
            this.prodDiaUsers = response.data.map((u: any) => ({
              id: u.IDUSUARIO,
              usuario: u.USUARIO || '',
              nombre: u.NOMBRE || u.USUARIO || '',
              contactos: u.CONTACTOS_DEL_DIA || u.Interacciones || 0,
              pendientes: u.PENDIENTES_DEL_DIA || u.Pendientes || 0,
              total: u.TOTAL_DEL_DIA || (u.Completados || 0) + (u.Pendientes || 0)
            }));
          } else {
            // Single user data - current user's production
            const data = response.data as any;
            this.prodDiaUsers = [{
              id: this.currentUserId,
              usuario: this.currentUserName,
              nombre: this.currentUserName,
              contactos: data.Interacciones || 0,
              pendientes: data.Pendientes || 0,
              total: data.TotalProgramados || 0
            }];
          }
        } else {
          this.prodDiaUsers = [];
        }
        this.isLoadingProduccion = false;
      },
      error: (error) => {
        console.error('Error loading producción:', error);
        this.errorMessage = 'Error al cargar producción diaria';
        this.prodDiaUsers = [];
        this.isLoadingProduccion = false;
      }
    });
  }

  /**
   * Helper: Calculate bar width percentage (max 100%)
   */
  getBarWidth(value: number, max: number): number {
    if (!value || !max) return 0;
    return Math.min((value / max) * 100, 100);
  }

  /**
   * Helper: Get start of current week (Monday)
   */
  getStartOfWeek(): string {
    const today = new Date();
    const day = today.getDay();
    const diff = today.getDate() - day + (day === 0 ? -6 : 1); // Adjust when day is Sunday
    const monday = new Date(today.setDate(diff));
    return monday.toISOString().split('T')[0];
  }

  /**
   * Helper: Get end of current week (Sunday)
   */
  getEndOfWeek(): string {
    const today = new Date();
    const day = today.getDay();
    const diff = today.getDate() - day + (day === 0 ? 0 : 7); // Adjust when day is Sunday
    const sunday = new Date(today.setDate(diff));
    return sunday.toISOString().split('T')[0];
  }

  /**
   * Helper: Calculate bar height in pixels for chart (max 150px)
   */
  getBarHeight(cantidad: number): number {
    if (!this.cerradosData?.porDia || this.cerradosData.porDia.length === 0) return 5;
    const maxCantidad = Math.max(...this.cerradosData.porDia.map((d: any) => d.CANTIDAD || 0));
    if (maxCantidad === 0) return 5; // Minimum height
    return Math.max(5, (cantidad / maxCantidad) * 150); // Max 150px height
  }

  /**
   * Logout
   */
  logout() {
    this.authService.logout();
    this.router.navigate(['/login']);
  }

  // API response data storage
  agendaDiaData: any[] = [];
  dashboardMetrics: any = null;
  calendarioData: any[] = [];
  cerradosData: any = null;

  companies: any[] = [];

  selected: any = null;

  // Today's date for AGENDA DEL DÍA
  fechaHoy = new Date().toLocaleDateString('es-PE');
  
  // Formatted date for Dashboard (e.g., "20 DE NOVIEMBRE DEL 2025")
  get fechaHoyFormateado(): string {
    const options: Intl.DateTimeFormatOptions = { 
      day: 'numeric', 
      month: 'long', 
      year: 'numeric' 
    };
    const fecha = new Date().toLocaleDateString('es-PE', options).toUpperCase();
    return fecha.replace(' DE ', ' DE ').replace(' DE ', ' DEL ');
  }

  // Get count of pending appointments (PENDIENTE status)
  getCitasPendientes(): number {
    return this.agendaDiaData.filter(item => item.ESTADO === 'PENDIENTE').length;
  }

  // Calculate compliance rate
  getTasaCumplimiento(): number {
    if (this.agendaDiaData.length === 0) return 0;
    const completados = this.agendaDiaData.filter(item => 
      item.ESTADO === 'COMPLETADO' || item.ESTADO === 'REALIZADO'
    ).length;
    return Math.round((completados / this.agendaDiaData.length) * 100);
  }

  // PRODUCCIÓN helpers (HU010)
  getTotalContactos(): number {
    return this.prodDiaUsers.reduce((sum, u) => sum + (u.contactos || 0), 0);
  }

  getTotalPendientes(): number {
    return this.prodDiaUsers.reduce((sum, u) => sum + (u.pendientes || 0), 0);
  }

  getTasaProductividad(): number {
    const totalContactos = this.getTotalContactos();
    const totalProgramados = this.prodDiaUsers.reduce((sum, u) => sum + (u.total || 0), 0);
    if (totalProgramados === 0) return 0;
    return Math.round((totalContactos / totalProgramados) * 100);
  }

  // Open modal for new appointment
  abrirModalNuevaCita() {
    // TODO: Implement modal for creating new appointment
    console.log('Abrir modal nueva cita');
    alert('Funcionalidad de nueva cita en desarrollo');
  }

  // Filtered companies for AGENDA DEL DÍA (today's contacts)
  get companiesAgendaHoy() {
    const today = new Date();
    const todayStr = today.toLocaleDateString('es-PE');
    
    return this.companies.filter(company => {
      const ultimaFecha = this.getUltimaFechaContacto(company);
      return ultimaFecha === todayStr;
    });
  }

  // Data for PENDIENTES OLVIDADOS view (HU004)
  pendientesOlvidados: any[] = [];

  // Data for PENDIENTES ACUMULADOS view (HU005)
  pendientesAcumulados: any[] = [];

  // Filters for PENDIENTES OLVIDADOS
  prioridadFilterOlvidados = 'Todos';
  fechaInicioOlvidados = '';
  fechaFinOlvidados = '';

  // Filters for PENDIENTES ACUMULADOS
  prioridadFilterAcumulados = 'Todos';
  fechaInicioAcumulados = '';
  fechaFinAcumulados = '';

  // Data for PROD. DÍA view
  prodDiaUsers: any[] = [];

  // Sidebar filters
  selectedUserFilter = '';

  // Methods for sidebar actions
  abrirAsignacionClientes() {
    console.log('Abrir asignación de clientes');
    alert('Funcionalidad de asignación de clientes en desarrollo');
  }

  abrirCalendario() {
    console.log('Abrir calendario');
    alert('Funcionalidad de calendario en desarrollo');
  }

  get filteredPendientesOlvidados() {
    // Filter applied by API call
    return this.pendientesOlvidados;
  }

  get filteredPendientesAcumulados() {
    // Filter applied by API call
    return this.pendientesAcumulados;
  }

  parseFecha(fecha: string): Date {
    // Parse DD/MM/YYYY format
    const parts = fecha.split('/');
    if (parts.length === 3) {
      return new Date(parseInt(parts[2]), parseInt(parts[1]) - 1, parseInt(parts[0]));
    }
    return new Date(fecha);
  }

  limpiarFiltrosOlvidados() {
    this.prioridadFilterOlvidados = 'Todos';
    this.fechaInicioOlvidados = '';
    this.fechaFinOlvidados = '';
    this.loadPendientesOlvidados();
  }

  limpiarFiltrosAcumulados() {
    this.prioridadFilterAcumulados = 'Todos';
    this.fechaInicioAcumulados = '';
    this.fechaFinAcumulados = '';
    this.loadPendientesAcumulados();
  }

  // returns the companies filtered by search (now API-based)
  get filteredCompanies() {
    return this.companies;
  }

  // update search text from input and reload companies
  onSearchChange(value: string) {
    this.searchText = value;
    // Reload companies with search filter from API
    this.loadCompanies(value || undefined);
  }

  selectCompany(c: any) {
    this.selected = c;
    this.activeTab = 0;
    this.isEditMode = false;
    this.isSeguimientoEditMode = false;
    this.isHistoricoEditMode = false;
    this.isProtocolosEditMode = false;
    this.editingHistoricoIndex = null;
    this.editingProtocoloIndex = null;
    this.editingCotizacionIndex = null;
    this.historicoBackup = null;
    this.protocoloBackup = null;
    this.cotizacionBackup = null;
    this.loadCompanyToForm();
    this.loadSeguimientoToForm();
    this.datosEmpresaForm.disable();
    this.seguimientoForm.disable();
    
    // Load full company details from API
    if (c && c.id) {
      this.loadCompanyDetails(c.id);
    }
  }

  loadCompanyToForm() {
    if (!this.selected) return;
    
    this.datosEmpresaForm.patchValue({
      razonSocial: this.selected.name || '',
      ruc: this.selected.ruc || '',
      sedePrincipal: this.selected.sedePrincipal || '',
      domicilio: this.selected.domicilio || '',
      nombreContacto: this.selected.contact || '',
      cargo: this.selected.cargo || '',
      email: this.selected.email || '',
      telefono: this.selected.phone || '',
      tipoEmpresa: this.selected.tipoEmpresa || '',
      nroTrabajadores: this.selected.nroTrabajadores || '',
      actEconomica: this.selected.actEconomica || '',
      riesgo: this.selected.riesgo || '',
      sedes: this.selected.sedes || ''
    });
  }

  loadSeguimientoToForm() {
    this.seguimientoForm.patchValue({
      tipoCliente: this.selected.follow.tipoCliente || '',
      fecha1erCto: this.selected.follow.fecha1erCto || '',
      tipoComunic: this.selected.follow.tipoComunic || '',
      tipoCartera: this.selected.follow.tipoCartera || '',
      lineaNegocio: this.selected.follow.lineaNegocio || '',
      estatusCliente: this.selected.follow.estatusCliente || '',
      subLinea: this.selected.follow.subLinea || '',
      detalleEstatus: this.selected.follow.detalleEstatus || '',
      tipoCredito: this.selected.follow.tipoCredito || '',
      tipoLlamada: this.selected.follow.tipoLlamada || '',
      presupuesto: this.selected.follow.presupuesto || '',
      observaciones: this.selected.follow.observaciones || ''
    });
  }

  editarEmpresa() {
    this.isEditMode = true;
    this.datosEmpresaForm.enable();
    this.loadCompanyToForm();
  }

  guardarEmpresa() {
    // Check validity while form is still enabled
    const isValid = this.datosEmpresaForm.valid;
    
    if (isValid && this.selected) {
      const formValues = this.datosEmpresaForm.value;
      
      // Check if this is a new company (not yet saved to DB)
      if (this.selected.isNew) {
        this.crearNuevaEmpresa(formValues);
        return;
      }
      
      // Update existing company - prepare data for API call with correct DB column names
      const empresaData = {
        idEmpresa: this.selected.id,
        NOMBRECOMERCIAL: formValues.razonSocial || '',
        RAZONSOCIAL: formValues.razonSocial || '',
        RUC: formValues.ruc || '',
        SEDEPRINCIPAL: formValues.sedePrincipal || '',
        DOMICILIO: formValues.domicilio || '',
        CONTACTO_NOMBRE: formValues.nombreContacto || '',
        CONTACTO_CARGO: formValues.cargo || '',
        CONTACTO_EMAIL: formValues.email || '',
        CONTACTO_TELEFONO: formValues.telefono || '',
        TIPOCLIENTE: formValues.tipoEmpresa || '',
        ACTIVIDADECONOMICA: formValues.actEconomica || '',
        RIESGO: formValues.riesgo || '',
        NUMTRABAJADORES: formValues.nroTrabajadores ? parseInt(formValues.nroTrabajadores) : null,
        LINEANEGOCIO: this.selected.lineaNegocio || '',
        TIPOCARTERA: this.selected.tipoCartera || '',
        USUARIOMODIFICA: this.currentUserId
      };
      
      // Call API to save
      this.empresaService.actualizarEmpresa(empresaData).subscribe({
        next: (response) => {
          if (response.isSuccess) {
            // Update local data
            this.selected.name = formValues.razonSocial || '';
            this.selected.ruc = formValues.ruc || '';
            this.selected.sedePrincipal = formValues.sedePrincipal || '';
            this.selected.domicilio = formValues.domicilio || '';
            this.selected.contact = formValues.nombreContacto || '';
            this.selected.cargo = formValues.cargo || '';
            this.selected.email = formValues.email || '';
            this.selected.phone = formValues.telefono || '';
            this.selected.tipoEmpresa = formValues.tipoEmpresa || '';
            this.selected.nroTrabajadores = formValues.nroTrabajadores || '';
            this.selected.actEconomica = formValues.actEconomica || '';
            this.selected.riesgo = formValues.riesgo || '';
            
            this.isEditMode = false;
            this.datosEmpresaForm.disable();
            console.log('Empresa guardada exitosamente:', response);
            alert('Empresa actualizada correctamente');
          } else {
            console.error('Error al guardar empresa:', response.errorMessage);
            alert('Error al guardar: ' + response.errorMessage);
          }
        },
        error: (error) => {
          console.error('Error al guardar empresa:', error);
          alert('Error al guardar la empresa. Por favor intente nuevamente.');
        }
      });
    } else {
      // Mark all fields as touched to show validation errors
      Object.keys(this.datosEmpresaForm.controls).forEach(key => {
        this.datosEmpresaForm.get(key)?.markAsTouched();
      });
      alert('Por favor, complete todos los campos requeridos correctamente.');
    }
  }

  cancelarEdicion() {
    // If canceling a new company that hasn't been saved, remove it from the list
    if (this.selected && this.selected.isNew) {
      const index = this.companies.findIndex(c => c.id === this.selected.id);
      if (index !== -1) {
        this.companies.splice(index, 1);
      }
      this.selected = this.companies.length > 0 ? this.companies[0] : null;
    }
    
    this.isEditMode = false;
    this.datosEmpresaForm.disable();
    this.loadCompanyToForm();
  }

  editarSeguimiento() {
    this.isSeguimientoEditMode = true;
    this.seguimientoForm.enable();
    this.loadSeguimientoToForm();
  }

  guardarSeguimiento() {
    if (this.seguimientoForm.valid && this.selected) {
      const formValues = this.seguimientoForm.value;
      
      // If we have an existing seguimiento ID, update it
      if (this.selected.follow.idSeguimiento) {
        const updateData = {
          idSeguimiento: this.selected.follow.idSeguimiento,
          estado: formValues.estatusCliente || 'PENDIENTE',
          detalle: {
            tipoComunicacion: formValues.tipoComunic || '',
            fecha1erContacto: formValues.fecha1erCto || '',
            estatusCliente: formValues.estatusCliente || '',
            detalleEstatus: formValues.detalleEstatus || '',
            tipoLlamada: formValues.tipoLlamada || '',
            presupuesto: formValues.presupuesto ? parseFloat(formValues.presupuesto) : undefined,
            observaciones: formValues.observaciones || ''
          },
          usuarioModifica: this.currentUserId
        };
        
        this.seguimientoService.actualizarSeguimiento(updateData).subscribe({
          next: (response) => {
            if (response.isSuccess) {
              // Update local data
              this.selected.follow.tipoCliente = formValues.tipoCliente || '';
              this.selected.follow.fecha1erCto = formValues.fecha1erCto || '';
              this.selected.follow.tipoComunic = formValues.tipoComunic || '';
              this.selected.follow.tipoCartera = formValues.tipoCartera || '';
              this.selected.follow.lineaNegocio = formValues.lineaNegocio || '';
              this.selected.follow.estatusCliente = formValues.estatusCliente || '';
              this.selected.follow.subLinea = formValues.subLinea || '';
              this.selected.follow.detalleEstatus = formValues.detalleEstatus || '';
              this.selected.follow.tipoCredito = formValues.tipoCredito || '';
              this.selected.follow.tipoLlamada = formValues.tipoLlamada || '';
              this.selected.follow.presupuesto = formValues.presupuesto || '';
              this.selected.follow.observaciones = formValues.observaciones || '';
              
              this.isSeguimientoEditMode = false;
              this.seguimientoForm.disable();
              alert('Seguimiento actualizado correctamente');
            } else {
              alert('Error al actualizar: ' + response.errorMessage);
            }
          },
          error: (error) => {
            console.error('Error al actualizar seguimiento:', error);
            alert('Error al actualizar el seguimiento');
          }
        });
      } else {
        // Create new seguimiento
        const createData = {
          idEmpresa: this.selected.id,
          idUsuarioAsignado: this.currentUserId,
          idUsuarioAsigna: this.currentUserId,
          idTipoSeguimiento: 1, // Default type, should be from form
          prioridad: 'MEDIA',
          fechaProgramada: new Date().toISOString().split('T')[0],
          horaProgramada: '09:00',
          notas: formValues.observaciones || ''
        };
        
        this.seguimientoService.crearSeguimiento(createData).subscribe({
          next: (response) => {
            if (response.isSuccess) {
              // Update local data
              this.selected.follow.idSeguimiento = response.data.idSeguimiento;
              this.selected.follow.tipoCliente = formValues.tipoCliente || '';
              this.selected.follow.fecha1erCto = formValues.fecha1erCto || '';
              this.selected.follow.tipoComunic = formValues.tipoComunic || '';
              this.selected.follow.tipoCartera = formValues.tipoCartera || '';
              this.selected.follow.lineaNegocio = formValues.lineaNegocio || '';
              this.selected.follow.estatusCliente = formValues.estatusCliente || '';
              this.selected.follow.subLinea = formValues.subLinea || '';
              this.selected.follow.detalleEstatus = formValues.detalleEstatus || '';
              this.selected.follow.tipoCredito = formValues.tipoCredito || '';
              this.selected.follow.tipoLlamada = formValues.tipoLlamada || '';
              this.selected.follow.presupuesto = formValues.presupuesto || '';
              this.selected.follow.observaciones = formValues.observaciones || '';
              
              this.isSeguimientoEditMode = false;
              this.seguimientoForm.disable();
              alert('Seguimiento creado correctamente');
            } else {
              alert('Error al crear: ' + response.errorMessage);
            }
          },
          error: (error) => {
            console.error('Error al crear seguimiento:', error);
            alert('Error al crear el seguimiento');
          }
        });
      }
    }
  }

  cancelarSeguimiento() {
    this.isSeguimientoEditMode = false;
    this.seguimientoForm.disable();
    this.loadSeguimientoToForm();
  }

  agregarRegistroHistorico() {
    const today = new Date();
    const fecha = today.toLocaleDateString('es-PE');
    const newRecord = {
      fecha: fecha,
      status: 'NUEVO',
      contacto: this.selected.contact || 'Sin contacto',
      usuario: 'MGUERRA'
    };
    this.selected.history.push(newRecord);
    console.log('Registro histórico agregado:', newRecord);
  }

  agregarProtocolo() {
    const today = new Date();
    const fecha = today.toLocaleDateString('es-PE');
    const newProtocol = {
      fecha: fecha,
      ruta: 'K:\\comercial\\',
      nombre: 'nuevo_protocolo.pdf',
      usuario: 'MGUERRA'
    };
    this.selected.protocols.push(newProtocol);
    console.log('Protocolo agregado:', newProtocol);
  }

  agregarCotizacion() {
    const today = new Date();
    const fecha = today.toLocaleDateString('es-PE');
    const newQuote = {
      fecha: fecha,
      ruta: 'K:\\comercial\\',
      nombre: 'nueva_cotizacion.pdf',
      usuario: 'MGUERRA'
    };
    this.selected.quotes.push(newQuote);
    console.log('Cotización agregada:', newQuote);
  }

  editarHistorico(index: number) {
    // Create backup for cancel functionality
    this.historicoBackup = { ...this.selected.history[index] };
    this.editingHistoricoIndex = index;
  }

  guardarHistorico(index: number) {
    // Changes are already applied via two-way binding
    this.editingHistoricoIndex = null;
    this.historicoBackup = null;
    console.log('Registro histórico guardado:', this.selected.history[index]);
  }

  cancelarHistorico() {
    // Restore from backup
    if (this.editingHistoricoIndex !== null && this.historicoBackup) {
      this.selected.history[this.editingHistoricoIndex] = this.historicoBackup;
    }
    this.editingHistoricoIndex = null;
    this.historicoBackup = null;
  }

  eliminarHistorico(index: number) {
    if (confirm('¿Está seguro de eliminar este registro histórico?')) {
      this.selected.history.splice(index, 1);
      console.log('Registro histórico eliminado');
    }
  }

  editarProtocolo(index: number) {
    // Create backup for cancel functionality
    this.protocoloBackup = { ...this.selected.protocols[index] };
    this.editingProtocoloIndex = index;
  }

  guardarProtocolo(index: number) {
    // Changes are already applied via two-way binding
    this.editingProtocoloIndex = null;
    this.protocoloBackup = null;
    console.log('Protocolo guardado:', this.selected.protocols[index]);
  }

  cancelarProtocolo() {
    // Restore from backup
    if (this.editingProtocoloIndex !== null && this.protocoloBackup) {
      this.selected.protocols[this.editingProtocoloIndex] = this.protocoloBackup;
    }
    this.editingProtocoloIndex = null;
    this.protocoloBackup = null;
  }

  eliminarProtocolo(index: number) {
    if (confirm('¿Está seguro de eliminar este protocolo?')) {
      this.selected.protocols.splice(index, 1);
      console.log('Protocolo eliminado');
    }
  }

  editarCotizacion(index: number) {
    // Create backup for cancel functionality
    this.cotizacionBackup = { ...this.selected.quotes[index] };
    this.editingCotizacionIndex = index;
  }

  guardarCotizacion(index: number) {
    // Changes are already applied via two-way binding
    this.editingCotizacionIndex = null;
    this.cotizacionBackup = null;
    console.log('Cotización guardada:', this.selected.quotes[index]);
  }

  cancelarCotizacion() {
    // Restore from backup
    if (this.editingCotizacionIndex !== null && this.cotizacionBackup) {
      this.selected.quotes[this.editingCotizacionIndex] = this.cotizacionBackup;
    }
    this.editingCotizacionIndex = null;
    this.cotizacionBackup = null;
  }

  eliminarCotizacion(index: number) {
    if (confirm('¿Está seguro de eliminar esta cotización?')) {
      this.selected.quotes.splice(index, 1);
      console.log('Cotización eliminada');
    }
  }

  // Get the most recent contact date from history
  getUltimaFechaContacto(company: any): string {
    if (!company.history || company.history.length === 0) {
      return 'Sin contacto';
    }
    
    // Sort history by date (most recent first) and return the first one
    const sortedHistory = [...company.history].sort((a, b) => {
      const dateA = this.parseFecha(a.fecha);
      const dateB = this.parseFecha(b.fecha);
      return dateB.getTime() - dateA.getTime();
    });
    
    return sortedHistory[0].fecha;
  }

  // Add new company - creates a placeholder for editing, will save to API when guardarEmpresa is called
  agregarNuevaEmpresa() {
    // Create a new company object with temp ID (negative to indicate new)
    const tempId = -(new Date().getTime());
    const newCompany = {
      id: tempId,
      isNew: true, // Flag to indicate this is a new company not yet saved
      name: '',
      contact: '',
      phone: '',
      user: this.currentUserName,
      ruc: '',
      sedePrincipal: '',
      domicilio: '',
      cargo: '',
      email: '',
      tipoEmpresa: '',
      nroTrabajadores: '',
      actEconomica: '',
      riesgo: '',
      sedes: '',
      tipoCartera: '',
      lineaNegocio: '',
      follow: {
        idSeguimiento: null,
        tipoCliente: '',
        fecha1erCto: '',
        tipoComunic: '',
        tipoCartera: '',
        lineaNegocio: '',
        estatusCliente: '',
        subLinea: '',
        detalleEstatus: '',
        tipoCredito: '',
        tipoLlamada: '',
        presupuesto: '',
        observaciones: ''
      },
      history: [],
      protocols: [],
      quotes: []
    };
    
    this.companies.unshift(newCompany); // Add to beginning of list
    this.selectCompany(newCompany);
    // Automatically enter edit mode for new company
    this.editarEmpresa();
  }

  /**
   * Save new company to API - called from guardarEmpresa when company is new
   */
  crearNuevaEmpresa(formValues: any) {
    const empresaData = {
      NOMBRECOMERCIAL: formValues.razonSocial || '',
      RAZONSOCIAL: formValues.razonSocial || '',
      RUC: formValues.ruc || '',
      SEDEPRINCIPAL: formValues.sedePrincipal || '',
      DOMICILIO: formValues.domicilio || '',
      CONTACTO_NOMBRE: formValues.nombreContacto || '',
      CONTACTO_CARGO: formValues.cargo || '',
      CONTACTO_EMAIL: formValues.email || '',
      CONTACTO_TELEFONO: formValues.telefono || '',
      TIPOCLIENTE: formValues.tipoEmpresa || '',
      ACTIVIDADECONOMICA: formValues.actEconomica || '',
      RIESGO: formValues.riesgo || '',
      NUMTRABAJADORES: formValues.nroTrabajadores ? parseInt(formValues.nroTrabajadores) : null,
      USUARIOCREA: this.currentUserId
    };
    
    this.empresaService.insertarEmpresa(empresaData).subscribe({
      next: (response) => {
        if (response.isSuccess && response.data) {
          // Update local data with real ID
          this.selected.id = response.data.idEmpresa;
          this.selected.isNew = false;
          this.selected.name = formValues.razonSocial || '';
          this.selected.ruc = formValues.ruc || '';
          this.selected.sedePrincipal = formValues.sedePrincipal || '';
          this.selected.domicilio = formValues.domicilio || '';
          this.selected.contact = formValues.nombreContacto || '';
          this.selected.cargo = formValues.cargo || '';
          this.selected.email = formValues.email || '';
          this.selected.phone = formValues.telefono || '';
          this.selected.tipoEmpresa = formValues.tipoEmpresa || '';
          this.selected.nroTrabajadores = formValues.nroTrabajadores || '';
          this.selected.actEconomica = formValues.actEconomica || '';
          this.selected.riesgo = formValues.riesgo || '';
          
          this.isEditMode = false;
          this.datosEmpresaForm.disable();
          alert('Empresa creada correctamente con ID: ' + response.data.idEmpresa);
        } else {
          alert('Error al crear: ' + response.errorMessage);
        }
      },
      error: (error) => {
        console.error('Error al crear empresa:', error);
        alert('Error al crear la empresa. Por favor intente nuevamente.');
      }
    });
  }
}
// ...existing code...