package com.oneidentity.safeguard.safeguardclient;

import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

@Command(name = "SafeguardJavaTool", mixinStandardHelpOptions = true,
    description = "Non-interactive CLI tool for testing SafeguardJava SDK")
public class ToolOptions {

    @Option(names = {"-a", "--appliance"}, required = true,
        description = "IP address or hostname of Safeguard appliance")
    String appliance;

    @Option(names = {"-x", "--insecure"}, defaultValue = "false",
        description = "Ignore validation of Safeguard appliance SSL certificate")
    boolean insecure;

    @Option(names = {"-p", "--read-password"}, defaultValue = "false",
        description = "Read any required password from console stdin")
    boolean readPassword;

    @Option(names = {"-u", "--username"},
        description = "Safeguard username to use to authenticate")
    String username;

    @Option(names = {"-i", "--identity-provider"},
        description = "Safeguard identity provider to use for rSTS")
    String identityProvider;

    @Option(names = {"-c", "--certificate-file"},
        description = "File path for client certificate")
    String certificateFile;

    @Option(names = {"-t", "--thumbprint"},
        description = "Thumbprint for client certificate in cert store")
    String thumbprint;

    @Option(names = {"-k", "--access-token"},
        description = "Pre-obtained access token for authentication")
    String accessToken;

    @Option(names = {"-A", "--anonymous"}, defaultValue = "false",
        description = "Do not authenticate, call API anonymously")
    boolean anonymous;

    @Option(names = {"-s", "--service"},
        description = "Safeguard service: Core, Appliance, Notification, A2A")
    String service;

    @Option(names = {"-m", "--method"},
        description = "HTTP method: Get, Post, Put, Delete")
    String method;

    @Option(names = {"-U", "--relative-url"},
        description = "API endpoint relative URL")
    String relativeUrl;

    @Option(names = {"-b", "--body"},
        description = "JSON body as string")
    String body;

    @Option(names = {"-f", "--full"}, defaultValue = "false",
        description = "Use InvokeMethodFull and output JSON envelope with StatusCode, Headers, Body")
    boolean full;

    @Option(names = {"-H", "--header"}, split = ",",
        description = "Additional HTTP headers as Key=Value pairs (comma-separated)")
    String[] headers;

    @Option(names = {"-P", "--parameter"}, split = ",",
        description = "Query parameters as Key=Value pairs (comma-separated)")
    String[] parameters;

    @Option(names = {"-T", "--token-lifetime"}, defaultValue = "false",
        description = "Output token lifetime remaining as JSON and skip API invocation")
    boolean tokenLifetime;

    @Option(names = {"-G", "--get-token"}, defaultValue = "false",
        description = "Output the current access token as JSON and exit")
    boolean getToken;

    @Option(names = {"-V", "--verbose"}, defaultValue = "false",
        description = "Display verbose debug output")
    boolean verbose;

    @Option(names = {"--interactive"}, defaultValue = "false",
        description = "Run in interactive menu mode (legacy)")
    boolean interactive;
}
