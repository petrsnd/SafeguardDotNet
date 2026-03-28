package com.oneidentity.safeguard.samples;

import com.oneidentity.safeguard.safeguardjava.ISafeguardConnection;
import com.oneidentity.safeguard.safeguardjava.Safeguard;
import com.oneidentity.safeguard.safeguardjava.data.Method;
import com.oneidentity.safeguard.safeguardjava.data.Service;

import java.io.Console;

/**
 * Demonstrates connecting to Safeguard using username and password authentication,
 * then calling the API to retrieve information about the current user.
 */
public class PasswordConnect {

    public static void main(String[] args) {
        if (args.length < 1) {
            System.out.println("Usage: PasswordConnect <appliance> [provider] [username]");
            System.out.println();
            System.out.println("  appliance  - IP address or hostname of Safeguard appliance");
            System.out.println("  provider   - Identity provider name (default: local)");
            System.out.println("  username   - Username to authenticate (default: Admin)");
            return;
        }

        String appliance = args[0];
        String provider = args.length > 1 ? args[1] : "local";
        String username = args.length > 2 ? args[2] : "Admin";

        Console console = System.console();
        char[] password;
        if (console != null) {
            password = console.readPassword("Password: ");
        } else {
            System.out.print("Password: ");
            password = new java.util.Scanner(System.in).nextLine().toCharArray();
        }

        ISafeguardConnection connection = null;
        try {
            // Connect to Safeguard using password authentication
            // Set ignoreSsl=true for lab environments; use a HostnameVerifier in production
            connection = Safeguard.connect(appliance, provider, username, password, null, true);

            // Call the "Me" endpoint to get info about the authenticated user
            String me = connection.invokeMethod(Service.Core, Method.Get, "Me",
                    null, null, null, null);
            System.out.println("Current user info:");
            System.out.println(me);

            // Get access token lifetime remaining
            int lifetime = connection.getAccessTokenLifetimeRemaining();
            System.out.println("\nToken lifetime remaining: " + lifetime + " seconds");

        } catch (Exception ex) {
            System.err.println("Error: " + ex.getMessage());
            ex.printStackTrace();
        } finally {
            if (connection != null) {
                connection.dispose();
            }
            // Clear password from memory
            java.util.Arrays.fill(password, '\0');
        }
    }
}
