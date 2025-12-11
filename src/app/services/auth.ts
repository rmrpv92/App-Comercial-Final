import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, BehaviorSubject } from 'rxjs';
import { tap } from 'rxjs/operators';
import { environment } from '../../environments/environment';

export interface LoginRequest {
  userid: string;
  userpwd: string;
}

export interface User {
  IDUSUARIO: number;
  LOGINUSUARIO: string;
  NOMBRES: string;
  APELLIDOPATERNO: string;
  APELLIDOMATERNO: string;
  CORREO: string;
  TELEFONO: string;
  IDPERFIL: number;
}

export interface LoginResponse {
  isSuccess: boolean;
  errorCode: string;
  errorMessage: string;
  data: User | null;
}

@Injectable({
  providedIn: 'root',
})
export class Auth {
  private apiUrl = environment.apiUrl;
  private currentUserSubject = new BehaviorSubject<User | null>(null);
  public currentUser$ = this.currentUserSubject.asObservable();

  constructor(private http: HttpClient) {
    // Load user from localStorage if exists
    const storedUser = localStorage.getItem('currentUser');
    if (storedUser) {
      this.currentUserSubject.next(JSON.parse(storedUser));
    }
  }

  /**
   * Authenticate user
   */
  login(username: string, password: string): Observable<LoginResponse> {
    const body: LoginRequest = {
      userid: username,
      userpwd: password
    };

    console.log('Calling API:', `${this.apiUrl}/login`);
    console.log('Request body:', body);

    return this.http.post<LoginResponse>(`${this.apiUrl}/login`, body).pipe(
      tap(response => {
        console.log('API Response:', response);
        if (response.isSuccess && response.data) {
          // Store user in localStorage
          localStorage.setItem('currentUser', JSON.stringify(response.data));
          this.currentUserSubject.next(response.data);
        }
      })
    );
  }

  /**
   * Logout user
   */
  logout(): void {
    localStorage.removeItem('currentUser');
    this.currentUserSubject.next(null);
  }

  /**
   * Get current user
   */
  getCurrentUser(): User | null {
    return this.currentUserSubject.value;
  }

  /**
   * Check if user is logged in
   */
  isLoggedIn(): boolean {
    return this.currentUserSubject.value !== null;
  }

  /**
   * Get user ID
   */
  getUserId(): number | null {
    const user = this.getCurrentUser();
    return user ? user.IDUSUARIO : null;
  }
}
