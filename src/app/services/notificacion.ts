import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, BehaviorSubject, interval } from 'rxjs';
import { map, switchMap, tap } from 'rxjs/operators';
import { environment } from '../../environments/environment';

export interface Alerta {
  IDSEGUIMIENTO: number;
  FECHAPROGRAMADA: string;
  HORAPROGRAMADA: string;
  PRIORIDAD: string;
  ESTADO: string;
  IDEMPRESA: number;
  EMPRESA: string;
  CONTACTO: string;
  TIPOSEGUIMIENTO: string;
  HORAS_SIN_ATENCION: number;
  PRESUPUESTO: number | null;
  TIPO_ALERTA: string;
  MENSAJE: string;
}

export interface Notificacion {
  IDNOTIFICACION: number;
  TITULO: string;
  MENSAJE: string;
  TIPO: 'Info' | 'Warning' | 'Alert' | 'Success';
  LEIDO: boolean;
  FECHAENVIO: string;
}

export interface NotificacionesResponse {
  alertas: Alerta[];
  notificaciones: Notificacion[];
  totalAlertas: number;
  totalNotificaciones: number;
  noLeidos: number;
}

export interface ApiResponse<T> {
  isSuccess: boolean;
  errorCode: string;
  errorMessage: string;
  data: T;
}

@Injectable({
  providedIn: 'root'
})
export class NotificacionService {
  private apiUrl = environment.apiUrl;
  
  // BehaviorSubject to track unread count for the notification badge
  private unreadCountSubject = new BehaviorSubject<number>(0);
  public unreadCount$ = this.unreadCountSubject.asObservable();
  
  // BehaviorSubject for alerts
  private alertasSubject = new BehaviorSubject<Alerta[]>([]);
  public alertas$ = this.alertasSubject.asObservable();

  constructor(private http: HttpClient) {}

  /**
   * Get all notifications and alerts for a user (HU007)
   */
  getNotificaciones(userId: number): Observable<NotificacionesResponse> {
    return this.http.get<ApiResponse<NotificacionesResponse>>(
      `${this.apiUrl}/notificaciones/user/${userId}`
    ).pipe(
      map(response => {
        if (response.isSuccess && response.data) {
          // Update the unread count
          this.unreadCountSubject.next(response.data.noLeidos);
          // Update alerts
          this.alertasSubject.next(response.data.alertas);
          return response.data;
        }
        throw new Error(response.errorMessage);
      })
    );
  }

  /**
   * Mark a notification as read
   */
  marcarComoLeida(notificationId: number): Observable<any> {
    return this.http.put<ApiResponse<any>>(
      `${this.apiUrl}/notificaciones/${notificationId}/leida`,
      {}
    ).pipe(
      map(response => {
        if (response.isSuccess) {
          // Decrease unread count
          const current = this.unreadCountSubject.getValue();
          if (current > 0) {
            this.unreadCountSubject.next(current - 1);
          }
          return response.data;
        }
        throw new Error(response.errorMessage);
      })
    );
  }

  /**
   * Start polling for notifications every X seconds
   */
  startPolling(userId: number, intervalSeconds: number = 60): Observable<NotificacionesResponse> {
    return interval(intervalSeconds * 1000).pipe(
      switchMap(() => this.getNotificaciones(userId))
    );
  }

  /**
   * Get current unread count
   */
  getUnreadCount(): number {
    return this.unreadCountSubject.getValue();
  }

  /**
   * Get current alerts
   */
  getAlertas(): Alerta[] {
    return this.alertasSubject.getValue();
  }

  /**
   * Check if there are high-value alerts (for HU007)
   */
  hasHighValueAlerts(): boolean {
    return this.alertasSubject.getValue().length > 0;
  }
}
