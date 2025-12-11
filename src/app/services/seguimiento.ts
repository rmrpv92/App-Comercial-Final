import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface SeguimientoItem {
  IDSEGUIMIENTO: number;
  CLIENTE: string;
  CONTACTO: string;
  TELEFONO: string;
  FECHAPROGRAMADA: string;
  HORAPROGRAMADA: string;
  PRIORIDAD: string;
  ESTADO: string;
  TIPOSEGUIMIENTO: string;
  USUARIO?: string;
  NOMBRE_EJECUTIVO?: string;
}

export interface SeguimientoCreate {
  idEmpresa: number;
  idUsuarioAsignado: number;
  idUsuarioAsigna: number;
  idTipoSeguimiento: number;
  prioridad: string;
  fechaProgramada: string;
  horaProgramada: string;
  notas?: string;
}

export interface SeguimientoUpdate {
  idSeguimiento: number;
  estado?: string;
  detalle?: {
    tipoComunicacion?: string;
    fecha1erContacto?: string;
    estatusCliente?: string;
    detalleEstatus?: string;
    tipoLlamada?: string;
    presupuesto?: number;
    observaciones?: string;
  };
  usuarioModifica?: number;
}

export interface ApiResponse<T> {
  isSuccess: boolean;
  errorCode: string;
  errorMessage: string;
  data: T;
}

@Injectable({
  providedIn: 'root',
})
export class SeguimientoService {
  private apiUrl = environment.apiUrl;

  constructor(private http: HttpClient) {}

  /**
   * Get daily agenda for user
   */
  getAgendaDia(userId: number, fecha: string): Observable<ApiResponse<SeguimientoItem[]>> {
    const params = new HttpParams()
      .set('userId', userId.toString())
      .set('fecha', fecha);
    const url = `${this.apiUrl}/agenda`;
    console.log('SeguimientoService.getAgendaDia - URL:', url);
    console.log('SeguimientoService.getAgendaDia - Params:', { userId, fecha });
    return this.http.get<ApiResponse<SeguimientoItem[]>>(url, { params });
  }

  /**
   * Get accumulated pending items
   */
  getPendientesAcumulados(
    userId: number,
    prioridad?: string,
    fechaIni?: string,
    fechaFin?: string
  ): Observable<ApiResponse<SeguimientoItem[]>> {
    let params = new HttpParams().set('userId', userId.toString());
    if (prioridad) params = params.set('prioridad', prioridad);
    if (fechaIni) params = params.set('fechaIni', fechaIni);
    if (fechaFin) params = params.set('fechaFin', fechaFin);

    return this.http.get<ApiResponse<SeguimientoItem[]>>(
      `${this.apiUrl}/pendientes-acumulados`,
      { params }
    );
  }

  /**
   * Get overdue pending items
   */
  getPendientesOlvidados(
    userId: number,
    prioridad?: string,
    fechaHasta?: string
  ): Observable<ApiResponse<SeguimientoItem[]>> {
    let params = new HttpParams().set('userId', userId.toString());
    if (prioridad) params = params.set('prioridad', prioridad);
    if (fechaHasta) params = params.set('fechaHasta', fechaHasta);

    return this.http.get<ApiResponse<SeguimientoItem[]>>(
      `${this.apiUrl}/pendientes-olvidados`,
      { params }
    );
  }

  /**
   * Create new follow-up
   */
  crearSeguimiento(seguimiento: SeguimientoCreate): Observable<ApiResponse<{ idSeguimiento: number }>> {
    return this.http.post<ApiResponse<{ idSeguimiento: number }>>(
      `${this.apiUrl}/seguimiento`,
      seguimiento
    );
  }

  /**
   * Update follow-up status and details
   */
  actualizarSeguimiento(seguimiento: SeguimientoUpdate): Observable<ApiResponse<{ rowsAffected: number }>> {
    return this.http.put<ApiResponse<{ rowsAffected: number }>>(
      `${this.apiUrl}/seguimiento`,
      seguimiento
    );
  }
}
