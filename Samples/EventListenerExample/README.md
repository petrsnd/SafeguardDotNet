# EventListenerExample Sample

Demonstrates subscribing to real-time events from Safeguard using the SignalR
persistent event listener. Events are printed to the console as they arrive.
The listener automatically reconnects if the connection is interrupted.

## Building

```bash
mvn clean package
```

## Running

```bash
java -jar target/event-listener-1.0-SNAPSHOT-jar-with-dependencies.jar <appliance> [provider] [username] [events...]
```

### Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| appliance | IP or hostname of Safeguard appliance | (required) |
| provider | Identity provider name | `local` |
| username | Username to authenticate | `Admin` |
| events | Event names to subscribe to | `UserCreated UserDeleted` |

You will be prompted for the password. Press Enter to stop listening.

### Example

Listen for access request events:

```bash
java -jar target/event-listener-1.0-SNAPSHOT-jar-with-dependencies.jar \
    safeguard.example.com local Admin \
    AccessRequestCreated AccessRequestApproved AccessRequestDenied
```

### Common Events

| Event | Description |
|-------|-------------|
| `AccessRequestCreated` | A new access request was submitted |
| `AccessRequestApproved` | An access request was approved |
| `AccessRequestDenied` | An access request was denied |
| `AccessRequestExpired` | An access request expired without action |
| `UserCreated` | A new user was created |
| `UserDeleted` | A user was deleted |
| `UserModified` | A user's properties were changed |
| `AssetCreated` | A new asset was added |
| `AssetDeleted` | An asset was removed |
| `AssetModified` | An asset's properties were changed |

## How It Works

1. Connects to Safeguard using password authentication
2. Creates a persistent event listener (auto-reconnects on disconnect)
3. Registers an event handler for each specified event name
4. Starts listening — events are printed to the console as they arrive
5. Press Enter to cleanly disconnect and exit
