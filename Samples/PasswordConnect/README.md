# PasswordConnect Sample

Demonstrates the simplest way to connect to Safeguard: username and password
authentication. After connecting, it calls the `GET Me` endpoint to retrieve
information about the authenticated user.

## Building

```bash
mvn clean package
```

## Running

```bash
java -jar target/password-connect-1.0-SNAPSHOT-jar-with-dependencies.jar <appliance> [provider] [username]
```

### Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| appliance | IP or hostname of Safeguard appliance | (required) |
| provider | Identity provider name | `local` |
| username | Username to authenticate | `Admin` |

You will be prompted for the password.

### Example

```bash
java -jar target/password-connect-1.0-SNAPSHOT-jar-with-dependencies.jar safeguard.example.com local Admin
```
