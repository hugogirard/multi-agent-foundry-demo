import { Routes } from '@angular/router';
import { LoginPage } from './pages/login/login';
import { TravelPage } from './pages/travel/travel';
import { MsalGuard } from '@azure/msal-angular';

export const routes: Routes = [
    {
        path: '',
        component: LoginPage,
    },
    {
        path: 'travel',
        component: TravelPage,
        canActivate: [MsalGuard]
    },
];
