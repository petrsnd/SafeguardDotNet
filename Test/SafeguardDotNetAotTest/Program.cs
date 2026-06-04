// Copyright (c) One Identity LLC. All rights reserved.

#pragma warning disable CA1031 // Probes intentionally swallow all exceptions other than the AOT reflection trap.
#pragma warning disable S6966 // Synchronous Console writes are fine for a one-shot probe.

namespace OneIdentity.SafeguardDotNet.AotTest;

using System;
using System.Threading;
using System.Threading.Tasks;

using OneIdentity.SafeguardDotNet;
using OneIdentity.SafeguardDotNet.A2A;
using OneIdentity.SafeguardDotNet.DeviceCodeLogin;
using OneIdentity.SafeguardDotNet.PkceNoninteractiveLogin;
using OneIdentity.SafeguardDotNet.Sps;

/// <summary>
/// AOT cleanliness probe for SafeguardDotNet.
///
/// Purpose
/// =======
/// SafeguardDotNet itself targets netstandard2.0, where the IL/Trim/AOT
/// analyzers do not run. This project targets net10.0 with
/// <c>IsAotCompatible=true</c> and references the four public packages
/// (core SDK, BrowserLogin, DeviceCodeLogin, PkceNoninteractiveLogin), so
/// the analyzers walk every method that is reachable from <see cref="Main"/>.
/// Combined with the repo-wide <c>TreatWarningsAsErrors=true</c> in
/// <c>Directory.Build.props</c>, any reflection-based JSON path (or other
/// AOT-incompatible code) reachable from the SDK's public surface fails
/// the build with IL2026 / IL3050 / IL3053 / IL2104 / etc.
///
/// Runtime check
/// =============
/// The csproj also sets
/// <c>JsonSerializerIsReflectionEnabledByDefault=false</c>, mirroring the
/// runtime configuration that <c>PublishAot=true</c> consumers (e.g.
/// safeguard-mcp) get. Running this binary with the <c>--smoke</c> flag
/// invokes every public auth/JSON entry point inside try/catch blocks; the
/// network calls fail (no real appliance), but if any of them ever reaches
/// reflection-based serialization the runtime throws
/// <c>InvalidOperationException</c> from <c>JsonSerializer</c> — the smoke
/// test reports those distinctly and exits non-zero.
///
/// This binary is not part of any shipping package and does nothing useful
/// at runtime; it exists solely to keep us honest about AOT cleanliness.
/// </summary>
public static class Program
{
    private const string FakeAppliance = "aot-test.invalid";
    private const string ReflectionDisabledMarker = "Reflection-based serialization has been disabled";

    /// <summary>
    /// Entry point. Run with no arguments to act purely as a compile-time
    /// AOT-analyzer probe. Run with <c>--smoke</c> to additionally exercise
    /// the public APIs at runtime under
    /// <c>JsonSerializerIsReflectionEnabledByDefault=false</c>.
    /// </summary>
    /// <param name="args">Command-line arguments.</param>
    /// <returns>0 on success, 1 if a reflection-based JSON path was hit at runtime.</returns>
    public static async Task<int> Main(string[] args)
    {
        if (args.Length == 0 || args[0] != "--smoke")
        {
            Console.WriteLine(
                "SafeguardDotNet AOT probe. Compile-time analyzer coverage only. " +
                "Pass --smoke to exercise the public APIs at runtime.");
            return 0;
        }

        var failures = 0;

        failures += await ProbeAsync("Safeguard.Connect (anonymous)", () =>
        {
            using var c = Safeguard.Connect(FakeAppliance, ignoreSsl: true);
            c.InvokeMethod(Service.Core, Method.Get, "Me");
        }).ConfigureAwait(false);

        failures += await ProbeAsync("Safeguard.Connect (password)", () =>
        {
            using var pw = "x".ToSecureString();
            using var c = Safeguard.Connect(FakeAppliance, "local", "admin", pw, ignoreSsl: true);
            c.InvokeMethod(Service.Core, Method.Get, "Me");
        }).ConfigureAwait(false);

        failures += await ProbeAsync("Safeguard.Connect (certificate by thumbprint)", () =>
        {
            using var c = Safeguard.Connect(FakeAppliance, "0000000000000000000000000000000000000000", ignoreSsl: true);
            c.InvokeMethod(Service.Core, Method.Get, "Me");
        }).ConfigureAwait(false);

        failures += await ProbeAsync("Safeguard.Event.GetPersistentEventListener", () =>
        {
            using var pw = "x".ToSecureString();
            using var listener = Safeguard.Event.GetPersistentEventListener(
                FakeAppliance, "local", "admin", pw, ignoreSsl: true);
        }).ConfigureAwait(false);

        failures += await ProbeAsync("Safeguard.A2A.GetContext + retrieval + broker", () =>
        {
            using var ctx = Safeguard.A2A.GetContext(
                FakeAppliance, "0000000000000000000000000000000000000000", ignoreSsl: true);
            using var apiKey = "key".ToSecureString();
            try
            {
                ctx.GetRetrievableAccounts();
            }
            catch
            {
                // network / handshake failure expected
            }

            try
            {
                ctx.RetrievePassword(apiKey);
            }
            catch
            {
                // network / handshake failure expected
            }

            try
            {
                ctx.BrokerAccessRequest(apiKey, new BrokeredAccessRequest
                {
                    ForUserName = "u",
                    AssetName = "a",
                });
            }
            catch
            {
                // network / handshake failure expected
            }
        }).ConfigureAwait(false);

        failures += await ProbeAsync("Safeguard.A2A.Event.GetPersistentA2AEventListener", () =>
        {
            using var apiKey = "key".ToSecureString();
            using var listener = Safeguard.A2A.Event.GetPersistentA2AEventListener(
                apiKey,
                (eventName, body) => { },
                FakeAppliance,
                "0000000000000000000000000000000000000000",
                ignoreSsl: true);
        }).ConfigureAwait(false);

        failures += await ProbeAsync("Safeguard for Privileged Sessions Connect", () =>
        {
            using var pw = "x".ToSecureString();
            using var sps = SafeguardForPrivilegedSessions.Connect(FakeAppliance, "admin", pw, ignoreSsl: true);
        }).ConfigureAwait(false);

        failures += await ProbeAsync("DeviceCodeLogin.ConnectAsync", async () =>
        {
            await DeviceCodeLogin.ConnectAsync(
                FakeAppliance,
                new DeviceCodeLoginParameters
                {
                    DisplayCallback = _ => { },
                    ClientId = string.Empty,
                    Scope = "rsts:sts:primaryproviderid:local",
                    PollingIntervalSeconds = 1,
                },
                ignoreSsl: true,
                cancellationToken: new CancellationTokenSource(TimeSpan.FromMilliseconds(50)).Token)
                .ConfigureAwait(false);
        }).ConfigureAwait(false);

        failures += await ProbeAsync("PkceNoninteractiveLogin.ConnectAsync", async () =>
        {
            using var pw = "x".ToSecureString();
            await PkceNoninteractiveLogin.ConnectAsync(
                FakeAppliance, "local", "admin", pw, ignoreSsl: true).ConfigureAwait(false);
        }).ConfigureAwait(false);

        // NOTE: We deliberately do NOT smoke-test DefaultBrowserLogin.ConnectAsync.
        // It would launch the user's default browser (Process.Start) before any
        // JSON serialization runs, which is unacceptable for a build-time check.
        // The JSON code paths it uses (AgentBasedLoginUtils.PostAuthorizationCodeFlowAsync
        // and ExchangeRstsTokenForConnectionAsync) are already exercised by the
        // PkceNoninteractiveLogin probe above and the AgentBasedLoginUtils probe below.

        failures += await ProbeAsync("AgentBasedLoginUtils.ExchangeRstsTokenForConnectionAsync", async () =>
        {
            using var token = "fake-rsts-token".ToSecureString();
            await Safeguard.AgentBasedLoginUtils.ExchangeRstsTokenForConnectionAsync(
                FakeAppliance, token, Safeguard.DefaultApiVersion, ignoreSsl: true, CancellationToken.None)
                .ConfigureAwait(false);
        }).ConfigureAwait(false);

        if (failures > 0)
        {
            Console.Error.WriteLine($"AOT smoke test FAILED: {failures} probe(s) hit reflection-based JSON.");
            return 1;
        }

        Console.WriteLine("AOT smoke test passed: no reflection-based JSON paths reached.");
        return 0;
    }

    private static Task<int> ProbeAsync(string name, Action body)
    {
        return ProbeAsync(name, () =>
        {
            body();
            return Task.CompletedTask;
        });
    }

    private static async Task<int> ProbeAsync(string name, Func<Task> body)
    {
        try
        {
            await body().ConfigureAwait(false);
            Console.WriteLine($"[ok]   {name} (unexpected success - network must be available)");
            return 0;
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains(ReflectionDisabledMarker, StringComparison.Ordinal))
        {
            Console.Error.WriteLine($"[FAIL] {name}: {ex.Message}");
            return 1;
        }
        catch (Exception)
        {
            // Anything other than the reflection-disabled exception means the
            // JSON serialization layer behaved correctly. The probe is happy
            // with any network/auth/runtime failure that isn't the AOT trap.
            Console.WriteLine($"[ok]   {name}");
            return 0;
        }
    }
}
