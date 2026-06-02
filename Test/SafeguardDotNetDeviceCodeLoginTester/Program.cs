// Copyright (c) One Identity LLC. All rights reserved.

using System;
using System.Linq;

using OneIdentity.SafeguardDotNet;
using OneIdentity.SafeguardDotNet.DeviceCodeLogin;

using Serilog;

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Debug()
    .WriteTo.Console()
    .CreateLogger();

var useAsync = args.Contains("--async", StringComparer.OrdinalIgnoreCase);
var positionalArgs = args.Where(a => !a.StartsWith("--")).ToArray();

if (positionalArgs.Length < 1)
{
    await Console.Out.WriteLineAsync("Usage: SafeguardDotNetDeviceCodeLoginTester <appliance> [ignoreSsl] [--async]");
    return;
}

var appliance = positionalArgs[0];
var ignoreSsl = positionalArgs.Length > 1 && positionalArgs[1].Equals("true", StringComparison.OrdinalIgnoreCase);

Action<DeviceCodeInfo> displayCallback = info =>
{
    Console.WriteLine();
    Console.WriteLine("═══════════════════════════════════════════════════════");
    Console.WriteLine("  To sign in, open a browser and visit:");
    Console.WriteLine($"  {info.VerificationUriComplete}");
    Console.WriteLine();
    Console.WriteLine($"  Or go to: {info.VerificationUri}");
    Console.WriteLine($"  And enter code: {info.UserCode}");
    Console.WriteLine();
    Console.WriteLine($"  Code expires in {info.ExpiresIn} seconds.");
    Console.WriteLine("═══════════════════════════════════════════════════════");
    Console.WriteLine();
};

try
{
    ISafeguardConnection connection;
    if (useAsync)
    {
        using var cts = Safeguard.AgentBasedLoginUtils.CreateConsoleCancellationToken();
        await Console.Out.WriteLineAsync("Async mode: press Ctrl+C to cancel");
        connection = await DeviceCodeLogin.ConnectAsync(
            appliance,
            new DeviceCodeLoginParameters { DisplayCallback = displayCallback },
            ignoreSsl: ignoreSsl,
            cancellationToken: cts.Token);
    }
    else
    {
        connection = await DeviceCodeLogin.ConnectAsync(
            appliance,
            new DeviceCodeLoginParameters { DisplayCallback = displayCallback },
            ignoreSsl: ignoreSsl);
    }

    await Console.Out.WriteLineAsync("Successfully connected!");
    var me = connection.InvokeMethod(Service.Core, Method.Get, "Me");
    await Console.Out.WriteLineAsync($"Logged in as: {me}");
}
catch (OperationCanceledException)
{
    await Console.Error.WriteLineAsync("Operation cancelled.");
    Environment.ExitCode = 1;
}
catch (SafeguardDotNetException ex)
{
    await Console.Error.WriteLineAsync($"Error: {ex.Message}");
    if (ex.HasResponse)
    {
        await Console.Error.WriteLineAsync($"Response: {ex.Response}");
    }

    Environment.ExitCode = 1;
}
