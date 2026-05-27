import { Component } from "@angular/core";
import { Router } from "@angular/router";
import { MsalService } from "@azure/msal-angular";


@Component({
    selector: 'login',
    standalone: true,
    templateUrl: './login.html',
    styleUrl: './login.css'
})
export class LoginPage {

    constructor(private router: Router, private authService: MsalService) { }

    ngOnInit() {
        if (this.authService.instance.getActiveAccount() || this.authService.instance.getAllAccounts().length > 0) {
            this.router.navigate(['/travel']);
        }
    }

    login() {
        // Check if user is already logged in
        if (this.authService.instance.getActiveAccount() || this.authService.instance.getAllAccounts().length > 0) {
            this.router.navigate(['/travel']);
            return;
        }

        this.authService.loginRedirect();
    }

}