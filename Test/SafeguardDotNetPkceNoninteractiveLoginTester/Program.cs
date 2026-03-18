// Copyright (c) One Identity LLC. All rights reserved.

namespace SafeguardDotNetPkceNoninteractiveLoginTester;

using System;
using System.Linq;
using System.Security;

using CommandLine;

using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

using OneIdentity.SafeguardDotNet;
using OneIdentity.SafeguardDotNet.PkceNoninteractiveLogin;

using Serilog;
using Serilog.Sinks.SystemConsole.Themes;

internal class Program
{
    private const string GrantTypeSettingName = "Allowed OAuth2 Grant Types";

    internal class Options
    {
        [Option(
            'a',
            "Appliance",
            Required = true,
            HelpText = "IP address or hostname of Safeguard appliance")]
        public string Appliance { get; set; }

        [Option(
            'x',
            "Insecure",
            Required = false,
            Default = false,
            HelpText = "Ignore validation of Safeguard appliance SSL certificate")]
        public bool Insecure { get; set; }

        [Option(
            'i',
            "IdentityProvider",
            Required = false,
            Default = "local",
            HelpText = "Safeguard identity provider to use for rSTS")]
        public string IdentityProvider { get; set; }

        [Option(
            'u',
            "Username",
            Required = true,
            HelpText = "Optional username to pre-fill in authorization URL")]
        public string Username { get; set; }

        [Option(
            'p',
            "ReadPassword",
            Required = false,
            Default = false,
            HelpText = "Read any required password from console stdin")]
        public bool ReadPassword { get; set; }

        [Option(
            's',
            "SecondaryPassword",
            Required = false,
            Default = null,
            HelpText = "Secondary password or one-time code for multi-factor authentication (e.g. TOTP code)")]
        public string SecondaryPassword { get; set; }

        [Option(
            'v',
            "ApiVersion",
            Required = false,
            Default = 4,
            HelpText = "Version of the Safeguard API to use")]
        public int ApiVersion { get; set; }

        [Option(
            'V',
            "Verbose",
            Required = false,
            Default = false,
            HelpText = "Display verbose debug output")]
        public bool Verbose { get; set; }

        [Option(
            'R',
            "ResourceOwner",
            Required = false,
            Default = null,
            HelpText = "Enable (true) or disable (false) the resource owner password grant type and exit")]
        public bool? ResourceOwner { get; set; }
    }

    private static SecureString PromptForSecret(string name)
    {
        Console.Write($"{name}: ");
        var password = new SecureString();
        while (true)
        {
            var keyInput = Console.ReadKey(true);
            if (keyInput.Key == ConsoleKey.Enter)
            {
                break;
            }

            if (keyInput.Key == ConsoleKey.Backspace)
            {
                if (password.Length <= 0)
                {
                    continue;
                }

                password.RemoveAt(password.Length - 1);
                Console.Write("\b \b");
            }
            else
            {
                password.AppendChar(keyInput.KeyChar);
                Console.Write("*");
            }
        }

        Console.Write(Environment.NewLine);
        return password;
    }

    private static SecureString HandlePassword(bool readFromStdin)
    {
        return readFromStdin ? Console.ReadLine().ToSecureString() : PromptForSecret("Password");
    }

    private static void SetResourceOwnerGrant(ISafeguardConnection connection, bool enable)
    {
        var settingsJson = connection.InvokeMethod(Service.Core, Method.Get, "Settings");
        var settings = JArray.Parse(settingsJson);
        var grantSetting = settings.FirstOrDefault(s => s["Name"]?.ToString() == GrantTypeSettingName);

        if (grantSetting == null)
        {
            throw new SafeguardDotNetException($"Setting '{GrantTypeSettingName}' not found");
        }

        var currentValue = grantSetting["Value"]?.ToString() ?? string.Empty;
        Log.Debug("Current grant types value: {Value}", currentValue);

        var grantTypes = currentValue
            .Split(',', StringSplitOptions.RemoveEmptyEntries)
            .Select(g => g.Trim())
            .ToList();

        var hasResourceOwner = grantTypes.Any(g =>
            g.Equals("ResourceOwner", StringComparison.OrdinalIgnoreCase));

        if (enable && !hasResourceOwner)
        {
            grantTypes.Add("ResourceOwner");
        }
        else if (!enable && hasResourceOwner)
        {
            grantTypes.RemoveAll(g => g.Equals("ResourceOwner", StringComparison.OrdinalIgnoreCase));
        }

        var newValue = string.Join(", ", grantTypes);
        var body = JsonConvert.SerializeObject(new { Value = newValue });
        _ = connection.InvokeMethod(
            Service.Core,
            Method.Put,
            $"Settings/{GrantTypeSettingName}",
            body);

        var envelope = new
        {
            Setting = GrantTypeSettingName,
            PreviousValue = currentValue,
            NewValue = newValue,
            ResourceOwnerEnabled = enable,
        };
        Console.WriteLine(JsonConvert.SerializeObject(envelope));
    }

    private static void Execute(Options opts)
    {
        try
        {
            var config = new LoggerConfiguration();
            config.WriteTo.Console(outputTemplate: "{Message:lj}{NewLine}{Exception}", theme: AnsiConsoleTheme.Code);

            if (opts.Verbose)
            {
                config.MinimumLevel.Debug();
            }
            else
            {
                config.MinimumLevel.Information();
            }

            Log.Logger = config.CreateLogger();

            Log.Information("Starting PKCE non-interactive authentication flow...");
            Log.Information("Connecting to Safeguard...");
            Log.Information("Identity Provider: {IdentityProvider}", opts.IdentityProvider);
            Log.Information("Username: {Username}", opts.Username);
            using var password = HandlePassword(opts.ReadPassword);
            using var secondaryPassword = !string.IsNullOrEmpty(opts.SecondaryPassword)
                ? opts.SecondaryPassword.ToSecureString()
                : null;
            var connection = PkceNoninteractiveLogin.Connect(
                opts.Appliance,
                opts.IdentityProvider,
                opts.Username,
                password,
                secondaryPassword,
                opts.ApiVersion,
                opts.Insecure);

            if (connection != null)
            {
                Log.Information(string.Empty);
                Log.Information("Successfully connected to Safeguard!");

                if (opts.ResourceOwner.HasValue)
                {
                    SetResourceOwnerGrant(connection, opts.ResourceOwner.Value);
                    connection.LogOut();
                    return;
                }

                Log.Information(string.Empty);
                Log.Information("Current user information:");
                Log.Information(connection.InvokeMethod(Service.Core, Method.Get, "Me"));
                Log.Information(string.Empty);
                Log.Information("Press enter to disconnect and quit...");
                Console.ReadLine();
                connection.LogOut();
            }
        }
#pragma warning disable CA1031 // Intentional top-level catch-all for error logging
        catch (Exception ex)
#pragma warning restore CA1031
        {
            Log.Error(ex, "Fatal exception occurred");
            Environment.Exit(1);
        }
    }

    private static void Main(string[] args)
    {
        Parser.Default.ParseArguments<Options>(args)
            .WithParsed(Execute);
    }
}
