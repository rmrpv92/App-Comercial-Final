import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface CalendarioItem {
  IDSEGUIMIENTO: number;
  FECHAPROGRAMADA: string;
  HORAPROGRAMADA: string;
  CLIENTE: string;
  USUARIO: string;
  NOMBRE_EJECUTIVO: string;
  PRIORIDAD: string;
  ESTADO: string;
  TIPOSEGUIMIENTO: string;
}

export interface DashboardMetrics {
  PROGRAMADOS_SEMANA: number;
  COMPLETADOS_SEMANA: number;
  PENDIENTES_SEMANA: number;
  CANCELADOS_SEMANA: number;
}

export interface CerradosData {
  metricas: {
    TOTAL_CERRADOS: number;
    MONTO_TOTAL: number;
    DIAS_PROMEDIO_CIERRE: number;
  };
  porDia: {
    DIA_SEMANA: string;
    FECHA: string;
    CANTIDAD: number;
  }[];
  historial: {
    EMPRESA: string;
    SERVICIO: string;
    MONTO: number;
    FECHA: string;
  }[];
}

export interface ProduccionUsuario {
  IDUSUARIO: number;
  USUARIO: string;
  NOMBRE: string;
  CONTACTOS_DEL_DIA: number;
  PENDIENTES_DEL_DIA: number;
  TOTAL_DEL_DIA: number;
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
export class DashboardService {
  private apiUrl = environment.apiUrl;

  constructor(private http: HttpClient) {}

  /**
   * Get supervisor calendar for date range
   */
  getCalendario(
    fechaIni: string,
    fechaFin: string,
    userId: number
  ): Observable<ApiResponse<CalendarioItem[]>> {
    const params = new HttpParams()
      .set('fechaIni', fechaIni)
      .set('fechaFin', fechaFin)
      .set('userId', userId.toString());

    return this.http.get<ApiResponse<CalendarioItem[]>>(
      `${this.apiUrl}/calendario`,
      { params }
    );
  }

  /**
   * Get daily dashboard metrics
   */
  getDashboard(fecha: string, userId: number): Observable<ApiResponse<DashboardMetrics>> {
    const params = new HttpParams()
      .set('fecha', fecha)
      .set('userId', userId.toString());
    return this.http.get<ApiResponse<DashboardMetrics>>(
      `${this.apiUrl}/dashboard`,
      { params }
    );
  }

  /**
   * Get weekly closed deals
   */
  getCerrados(fechaIni: string, fechaFin: string, userId: number): Observable<ApiResponse<CerradosData>> {
    const params = new HttpParams()
      .set('fechaIni', fechaIni)
      .set('fechaFin', fechaFin)
      .set('userId', userId.toString());

    return this.http.get<ApiResponse<CerradosData>>(
      `${this.apiUrl}/cerrados`,
      { params }
    );
  }

  /**
   * Get daily productivity by user
   */
  getProduccion(fecha: string, userId: number): Observable<ApiResponse<ProduccionUsuario[]>> {
    const params = new HttpParams()
      .set('fecha', fecha)
      .set('userId', userId.toString());
    return this.http.get<ApiResponse<ProduccionUsuario[]>>(
      `${this.apiUrl}/produccion`,
      { params }
    );
  }
}
