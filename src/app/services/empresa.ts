import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface Empresa {
  IDEMPRESA: number;
  NOMBRECOMERCIAL: string;
  RAZONSOCIAL?: string;
  RUC?: string;
  SEDEPRINCIPAL?: string;
  DOMICILIO?: string;
  CONTACTO_NOMBRE?: string;
  CONTACTO_EMAIL?: string;
  CONTACTO_TELEFONO?: string;
  CONTACTO_CARGO?: string;
  TIPOCLIENTE?: string;
  LINEANEGOCIO?: string;
  SUBLINEANEGOCIO?: string;
  TIPOCREDITO?: string;
  TIPOCARTERA?: string;
  ACTIVIDADECONOMICA?: string;
  RIESGO?: string;
  NUMTRABAJADORES?: number | null;
  USUARIO_ASIGNADO?: string;
  USUARIOMODIFICA?: number;
  FECHACREA?: string;
  FECHAMODIFICA?: string;
}

export interface EmpresaDetalle extends Empresa {
  sedes?: Sede[];
  seguimiento?: any;
  detalleSeguimiento?: any;
  seguimiento_historial?: any[];
}

export interface Sede {
  IDSEDE: number;
  NOMBRESEDE: string;
  DOMICILIO: string;
  TELEFONO: string;
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
export class EmpresaService {
  private apiUrl = environment.apiUrl;

  constructor(private http: HttpClient) {}

  /**
   * Search companies with optional filters
   */
  buscarEmpresas(searchText?: string, usuario?: string): Observable<ApiResponse<Empresa[]>> {
    let params = new HttpParams();
    if (searchText) params = params.set('search', searchText);
    if (usuario) params = params.set('usuario', usuario);

    return this.http.get<ApiResponse<Empresa[]>>(`${this.apiUrl}/empresas`, { params });
  }

  /**
   * Get company details by ID
   */
  obtenerEmpresa(id: number): Observable<ApiResponse<EmpresaDetalle>> {
    return this.http.get<ApiResponse<EmpresaDetalle>>(`${this.apiUrl}/empresa?id=${id}`);
  }

  /**
   * Create new company
   */
  insertarEmpresa(empresa: Partial<Empresa>): Observable<ApiResponse<{ idEmpresa: number }>> {
    return this.http.post<ApiResponse<{ idEmpresa: number }>>(`${this.apiUrl}/empresa`, empresa);
  }

  /**
   * Update existing company
   */
  actualizarEmpresa(empresa: Partial<Empresa> & { idEmpresa: number }): Observable<ApiResponse<{ rowsAffected: number }>> {
    return this.http.put<ApiResponse<{ rowsAffected: number }>>(`${this.apiUrl}/empresa`, empresa);
  }
}
