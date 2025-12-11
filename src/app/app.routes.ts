import { Routes } from '@angular/router';
import { AppComercialComponent } from './pages/app-comercial/app-comercial';
import { Login } from './pages/login/login';
import { authGuard } from './guards/auth-guard';

export const routes: Routes = [
    {path: "", redirectTo: "login", pathMatch: "full"},
    {path: "login", component: Login},
    {path: "app-comercial", component: AppComercialComponent, canActivate: [authGuard]}
];
