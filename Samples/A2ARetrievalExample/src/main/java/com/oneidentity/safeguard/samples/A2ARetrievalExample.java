package com.oneidentity.safeguard.samples;

import com.oneidentity.safeguard.safeguardjava.ISafeguardA2AContext;
import com.oneidentity.safeguard.safeguardjava.Safeguard;
import com.oneidentity.safeguard.safeguardjava.data.A2ARetrievableAccount;

import java.io.Console;
import java.util.List;

/**
 * Demonstrates using Safeguard Application-to-Application (A2A) to retrieve
 * credentials without requiring an interactive login or access request workflow.
 *
 * A2A is the primary integration method for automated systems (scripts, services,
 * CI/CD pipelines) that need to fetch passwords from Safeguard. It requires
 * client certificate authentication and is protected by API keys and IP restrictions.
 *
 * Prerequisites:
 *   1. Register an Application in Safeguard with certificate authentication
 *   2. Configure A2A credential retrieval registrations for the target accounts
 *   3. Note the API key(s) assigned to each retrieval registration
 */
public class A2ARetrievalExample {

    public static void main(String[] args) {
        if (args.length < 3) {
            System.out.println("Usage: A2ARetrievalExample <appliance> <certificate-file> <api-key>");
            System.out.println();
            System.out.println("  appliance        - IP address or hostname of Safeguard appliance");
            System.out.println("  certificate-file  - Path to PKCS12/PFX A2A client certificate");
            System.out.println("  api-key          - A2A API key for the credential retrieval registration");
            System.out.println();
            System.out.println("You will be prompted for the certificate password.");
            return;
        }

        String appliance = args[0];
        String certificateFile = args[1];
        char[] apiKey = args[2].toCharArray();

        Console console = System.console();
        char[] certPassword;
        if (console != null) {
            certPassword = console.readPassword("Certificate password: ");
        } else {
            System.out.print("Certificate password: ");
            certPassword = new java.util.Scanner(System.in).nextLine().toCharArray();
        }

        ISafeguardA2AContext a2aContext = null;
        try {
            // Create an A2A context using certificate authentication
            a2aContext = Safeguard.A2A.getContext(appliance, certificateFile, certPassword, null, true, null);

            // List all retrievable accounts available to this certificate
            System.out.println("Retrievable accounts:");
            List<A2ARetrievableAccount> accounts = a2aContext.getRetrievableAccounts();
            for (A2ARetrievableAccount account : accounts) {
                System.out.println("  Account: " + account.getAccountName()
                        + " (Asset: " + account.getAssetName()
                        + ", ApiKey: " + new String(account.getApiKey()) + ")");
            }

            // Retrieve the password using the API key
            System.out.println("\nRetrieving password for API key: " + new String(apiKey));
            char[] password = a2aContext.retrievePassword(apiKey);
            System.out.println("Password retrieved successfully (length: " + password.length + ")");

            // IMPORTANT: Clear sensitive data from memory when done
            java.util.Arrays.fill(password, '\0');

        } catch (Exception ex) {
            System.err.println("Error: " + ex.getMessage());
            ex.printStackTrace();
        } finally {
            if (a2aContext != null) {
                a2aContext.dispose();
            }
            java.util.Arrays.fill(certPassword, '\0');
            java.util.Arrays.fill(apiKey, '\0');
        }
    }
}
