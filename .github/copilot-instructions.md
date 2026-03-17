# Copilot Instructions for SafeguardJava

## Build Commands

```bash
# Build (requires JDK 8+ and Maven 3.0.5+)
mvn package

# Build with a specific version
mvn package -Drevision=7.5.0

# Build for release (includes source jars, javadoc, GPG signing)
mvn deploy -P release --settings settings/settings.xml

# Clean build
mvn clean package
```

There are no unit tests in the main project. The `tests/safeguardjavaclient/` directory contains an interactive CLI test harness (not automated tests), which requires a live Safeguard appliance to run.

## Architecture

SafeguardJava is a Java SDK for the One Identity Safeguard for Privileged Passwords REST API. It targets Java 8 source/target compatibility and is published to Maven Central as `com.oneidentity.safeguard:safeguardjava`.

### Entry Points

All SDK usage starts through static factory methods:

- **`Safeguard.connect(...)`** — Creates `ISafeguardConnection` instances. Multiple overloads support password, certificate (keystore/file/thumbprint/byte array), and access token authentication.
- **`Safeguard.A2A.getContext(...)`** — Creates `ISafeguardA2AContext` for application-to-application credential retrieval. Only supports certificate authentication.
- **`Safeguard.A2A.Events.getPersistentA2AEventListener(...)`** — Creates auto-reconnecting A2A event listeners.
- **`Safeguard.Persist(connection)`** — Wraps any connection in a `PersistentSafeguardConnection` that auto-refreshes tokens.
- **`SafeguardForPrivilegedSessions.Connect(...)`** — Creates `ISafeguardSessionsConnection` for Safeguard for Privileged Sessions (SPS).

### Package Structure (`com.oneidentity.safeguard.safeguardjava`)

- **Root package** — Public API: `Safeguard`, `ISafeguardConnection`/`SafeguardConnection`, `ISafeguardA2AContext`/`SafeguardA2AContext`, streaming classes, and SPS integration.
- **`authentication/`** — `IAuthenticationMechanism` interface with implementations: `PasswordAuthenticator`, `CertificateAuthenticator`, `AccessTokenAuthenticator`, `AnonymousAuthenticator`, `ManagementServiceAuthenticator`. All extend `AuthenticatorBase`.
- **`event/`** — SignalR-based event system: `ISafeguardEventListener`/`SafeguardEventListener`, persistent (auto-reconnecting) variants, `EventHandlerRegistry` for thread-safe handler management.
- **`restclient/`** — `RestClient` wraps Apache HttpClient 4.5 for all HTTP operations. OkHttp 4.11 is present as a transitive dependency of the Microsoft SignalR client.
- **`data/`** — DTOs and enums (`Service`, `Method`, `KeyFormat`, `SafeguardEventListenerState`, `BrokeredAccessRequestType`).
- **`exceptions/`** — `SafeguardForJavaException` (general), `ArgumentException` (validation), `ObjectDisposedException` (resource lifecycle), `SafeguardEventListenerDisconnectedException`.

### Safeguard API Services

The SDK targets five backend services, represented by the `Service` enum:

| Service | Endpoint Pattern | Auth Required |
|---|---|---|
| `Core` | `/service/core/v{version}` | Yes |
| `Appliance` | `/service/appliance/v{version}` | Yes |
| `Notification` | `/service/notification/v{version}` | No |
| `A2A` | `/service/a2a/v{version}` | Certificate |
| `Management` | `/service/management/v{version}` | Yes |

The default API version is **v4** (since SDK 7.0). Pass `apiVersion` parameter to use v3.

## Key Conventions

### Interface-First Design

Every public type has a corresponding `I`-prefixed interface (`ISafeguardConnection`, `ISafeguardA2AContext`, `ISafeguardEventListener`, `IAuthenticationMechanism`). Code against interfaces, not implementations.

### Dispose Pattern

Connections, A2A contexts, and event listeners implement a `dispose()` method that must be called to release resources. Every public method on these classes guards against use-after-dispose:

```java
if (disposed) {
    throw new ObjectDisposedException("ClassName");
}
```

### Authentication Flow

All authenticators obtain tokens via the embedded Safeguard RSTS (Resource Security Token Service) at `https://{host}/RSTS/oauth2/token`. Password auth uses the `password` grant type; certificate auth uses `client_credentials`. The `AccessTokenAuthenticator` accepts a pre-obtained token but cannot refresh it.

### SSL/TLS Handling

Three modes: `ignoreSsl=true` (uses `NoopHostnameVerifier`), custom `HostnameVerifier` callback, or default Java validation. Certificate contexts (`CertificateContext`) support JKS keystores, PFX files, byte arrays, and Windows certificate store (by thumbprint).

### Error Handling

- Parameter validation throws `ArgumentException`
- HTTP failures throw `SafeguardForJavaException` with status code and response body
- Null HTTP responses throw `SafeguardForJavaException("Unable to connect to ...")`
- Disposed object access throws `ObjectDisposedException`

### Logging

Uses `java.util.logging` (JUL). The SLF4J dependency provides the facade for the SignalR library. Debug-level HTTP wire logging can be enabled via Apache Commons Logging system properties (see `tests/safeguardjavaclient` for examples).

### Sensitive Data as `char[]`

Passwords, access tokens, and API keys are stored as `char[]` rather than `String` to allow explicit clearing from memory.

### Event System Threading

Each event type gets its own handler thread. Handlers for the same event execute sequentially; handlers for different events execute concurrently. The `EventHandlerRegistry` manages thread-safe concurrent dispatch.

### CI/CD

The project uses Azure Pipelines (`azure-pipelines.yml`). Release branches (`master`, `release-*`) deploy to Sonatype/Maven Central with GPG signing. Non-release branches only build and package.
