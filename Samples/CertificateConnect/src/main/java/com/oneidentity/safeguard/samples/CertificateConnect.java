package com.oneidentity.safeguard.samples;

import com.oneidentity.safeguard.safeguardjava.ISafeguardConnection;
import com.oneidentity.safeguard.safeguardjava.Safeguard;
import com.oneidentity.safeguard.safeguardjava.data.Method;
import com.oneidentity.safeguard.safeguardjava.data.Service;

import java.io.Console;

/**
 * Demonstrates connecting to Safeguard using client certificate authentication
 * with a PKCS12 (PFX) file. This is the recommended authentication method for
 * automated processes and services.
 *
 * Prerequisites:
 *   1. Upload the certificate's CA chain to Safeguard as trusted certificates
 *   2. Create a certificate user in Safeguard mapped to the client certificate's thumbprint
 *   3. Have the PKCS12/PFX file and its password available
 */
public class CertificateConnect {

    public static void main(String[] args) {
        if (args.length < 2) {
            System.out.println("Usage: CertificateConnect <appliance> <certificate-file>");
            System.out.println();
            System.out.println("  appliance        - IP address or hostname of Safeguard appliance");
            System.out.println("  certificate-file  - Path to PKCS12/PFX client certificate file");
            System.out.println();
            System.out.println("You will be prompted for the certificate password.");
            return;
        }

        String appliance = args[0];
        String certificateFile = args[1];

        Console console = System.console();
        char[] certPassword;
        if (console != null) {
            certPassword = console.readPassword("Certificate password: ");
        } else {
            System.out.print("Certificate password: ");
            certPassword = new java.util.Scanner(System.in).nextLine().toCharArray();
        }

        ISafeguardConnection connection = null;
        try {
            // Connect to Safeguard using client certificate authentication
            // The certificate file must be in PKCS12 (PFX) format
            connection = Safeguard.connect(appliance, certificateFile, certPassword, null, true, null);

            // Verify the connection by calling the "Me" endpoint
            String me = connection.invokeMethod(Service.Core, Method.Get, "Me",
                    null, null, null, null);
            System.out.println("Authenticated user info:");
            System.out.println(me);

        } catch (Exception ex) {
            System.err.println("Error: " + ex.getMessage());
            ex.printStackTrace();
        } finally {
            if (connection != null) {
                connection.dispose();
            }
            java.util.Arrays.fill(certPassword, '\0');
        }
    }
}
