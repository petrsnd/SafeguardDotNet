package com.oneidentity.safeguard.samples;

import com.oneidentity.safeguard.safeguardjava.ISafeguardConnection;
import com.oneidentity.safeguard.safeguardjava.ISafeguardEventListener;
import com.oneidentity.safeguard.safeguardjava.Safeguard;
import com.oneidentity.safeguard.safeguardjava.event.ISafeguardEventHandler;
import com.oneidentity.safeguard.safeguardjava.event.PersistentSafeguardEventListenerBase;

import java.io.Console;

/**
 * Demonstrates subscribing to real-time events from Safeguard using the SignalR
 * persistent event listener. The listener automatically reconnects if the connection
 * is interrupted.
 *
 * Events are fired when state changes occur in Safeguard, such as:
 *   - Access request lifecycle events (new, approved, denied, expired, etc.)
 *   - User login/logout events
 *   - Asset discovery and account management events
 *   - Appliance health and configuration changes
 */
public class EventListenerExample {

    public static void main(String[] args) {
        if (args.length < 1) {
            System.out.println("Usage: EventListenerExample <appliance> [provider] [username] [events...]");
            System.out.println();
            System.out.println("  appliance  - IP address or hostname of Safeguard appliance");
            System.out.println("  provider   - Identity provider name (default: local)");
            System.out.println("  username   - Username to authenticate (default: Admin)");
            System.out.println("  events     - Event names to subscribe to (default: UserCreated UserDeleted)");
            System.out.println();
            System.out.println("Common events:");
            System.out.println("  AccessRequestCreated, AccessRequestApproved, AccessRequestDenied");
            System.out.println("  UserCreated, UserDeleted, UserModified");
            System.out.println("  AssetCreated, AssetDeleted, AssetModified");
            System.out.println();
            System.out.println("Press Ctrl+C to stop listening.");
            return;
        }

        String appliance = args[0];
        String provider = args.length > 1 ? args[1] : "local";
        String username = args.length > 2 ? args[2] : "Admin";

        // Collect event names from remaining args, or use defaults
        String[] eventNames;
        if (args.length > 3) {
            eventNames = new String[args.length - 3];
            System.arraycopy(args, 3, eventNames, 0, eventNames.length);
        } else {
            eventNames = new String[]{"UserCreated", "UserDeleted"};
        }

        Console console = System.console();
        char[] password;
        if (console != null) {
            password = console.readPassword("Password: ");
        } else {
            System.out.print("Password: ");
            password = new java.util.Scanner(System.in).nextLine().toCharArray();
        }

        // Create the event handler that will process incoming events
        ISafeguardEventHandler handler = (eventName, eventBody) -> {
            System.out.println("=== Event Received ===");
            System.out.println("Event: " + eventName);
            System.out.println("Body:  " + eventBody);
            System.out.println("======================");
        };

        ISafeguardConnection connection = null;
        ISafeguardEventListener listener = null;
        try {
            // Connect to Safeguard
            connection = Safeguard.connect(appliance, provider, username, password, null, true);
            java.util.Arrays.fill(password, '\0');

            // Create a persistent event listener that auto-reconnects
            listener = Safeguard.Event.getPersistentEventListener(
                    connection, null, true);

            // Register the handler for each event
            for (String eventName : eventNames) {
                listener.registerEventHandler(eventName, handler);
                System.out.println("Registered handler for: " + eventName);
            }

            // Start listening for events
            listener.start();
            System.out.println("\nListening for events... Press Enter to stop.");

            // Wait for user to press Enter
            if (console != null) {
                console.readLine();
            } else {
                System.in.read();
            }

        } catch (Exception ex) {
            System.err.println("Error: " + ex.getMessage());
            ex.printStackTrace();
        } finally {
            if (listener != null) {
                listener.stop();
                listener.dispose();
            }
            if (connection != null) {
                connection.dispose();
            }
        }
    }
}
