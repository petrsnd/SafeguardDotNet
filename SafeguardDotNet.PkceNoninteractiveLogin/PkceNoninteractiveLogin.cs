// Copyright (c) One Identity LLC. All rights reserved.

namespace OneIdentity.SafeguardDotNet.PkceNoninteractiveLogin;

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security;
using System.Text;
using System.Threading.Tasks;
using System.Web;

using Newtonsoft.Json.Linq;

using Serilog;

/// <summary>
/// Provides PKCE-based authentication to Safeguard without launching a browser.
/// This class enables programmatic authentication by manually handling the OAuth2/PKCE flow.
/// </summary>
public static class PkceNoninteractiveLogin
{
    // rSTS login controller step numbers (from rSTS Login.js)
    private const string StepInit = "1";
    private const string StepPrimaryAuth = "3";
    private const string StepSecondaryInit = "7";
    private const string StepSecondaryAuth = "5";
    private const string StepGenerateClaims = "6";

    /// <summary>
    /// Connect to Safeguard API using PKCE (Proof Key for Code Exchange) authentication without launching a browser.
    /// This method programmatically simulates the browser-based OAuth2/PKCE flow by directly interacting with
    /// the Safeguard login endpoints.
    /// </summary>
    /// <param name="appliance">Network address of the Safeguard appliance.</param>
    /// <param name="provider">Safeguard authentication provider name (e.g. local).</param>
    /// <param name="username">User name to use for authentication.</param>
    /// <param name="password">User password to use for authentication.</param>
    /// <param name="apiVersion">Target API version to use.</param>
    /// <param name="ignoreSsl">Ignore server certificate validation.</param>
    /// <returns>Reusable Safeguard API connection.</returns>
    /// <exception cref="SafeguardDotNetException">Thrown when authentication fails or the API returns an error.</exception>
    public static ISafeguardConnection Connect(
        string appliance,
        string provider,
        string username,
        SecureString password,
        int apiVersion = Safeguard.DefaultApiVersion,
        bool ignoreSsl = false)
    {
        return Connect(appliance, provider, username, password, null, apiVersion, ignoreSsl);
    }

    /// <summary>
    /// Connect to Safeguard API using PKCE (Proof Key for Code Exchange) authentication without launching a browser,
    /// with support for multi-factor authentication (MFA).
    /// This method programmatically simulates the browser-based OAuth2/PKCE flow by directly interacting with
    /// the Safeguard login endpoints. When the identity provider requires a second factor (e.g. TOTP, RADIUS),
    /// the <paramref name="secondaryPassword"/> is submitted as the one-time password.
    /// </summary>
    /// <param name="appliance">Network address of the Safeguard appliance.</param>
    /// <param name="provider">Safeguard authentication provider name (e.g. local).</param>
    /// <param name="username">User name to use for authentication.</param>
    /// <param name="password">User password to use for authentication.</param>
    /// <param name="secondaryPassword">One-time password or code for multi-factor authentication (e.g. TOTP code).
    /// Pass null if MFA is not required.</param>
    /// <param name="apiVersion">Target API version to use.</param>
    /// <param name="ignoreSsl">Ignore server certificate validation.</param>
    /// <returns>Reusable Safeguard API connection.</returns>
    /// <exception cref="SafeguardDotNetException">Thrown when authentication fails, MFA is required but no
    /// secondary password was provided, or the API returns an error.</exception>
    public static ISafeguardConnection Connect(
        string appliance,
        string provider,
        string username,
        SecureString password,
        SecureString secondaryPassword,
        int apiVersion = Safeguard.DefaultApiVersion,
        bool ignoreSsl = false)
    {
        var csrfToken = Safeguard.AgentBasedLoginUtils.GenerateCsrfToken();
        var oauthCodeVerifier = Safeguard.AgentBasedLoginUtils.OAuthCodeVerifier();
        var oauthCodeChallenge = Safeguard.AgentBasedLoginUtils.OAuthCodeChallenge(oauthCodeVerifier);
        var redirectUri = Safeguard.AgentBasedLoginUtils.RedirectUri;

        var http = CreateHttpClient(appliance, csrfToken, ignoreSsl);

        var identityProvider = ResolveIdentityProvider(http, appliance, apiVersion, provider);

        // Form data to submit to the rSTS login screen
        var primaryFormData = $"directoryComboBox={identityProvider}" +
            $"&usernameTextbox={Uri.EscapeDataString(username)}" +
            $"&passwordTextbox={Uri.EscapeDataString(password.ToInsecureString())}" +
            $"&csrfTokenTextbox={csrfToken}";
        var pkceUrl = $"https://{appliance}/RSTS/UserLogin/LoginController?response_type=code&code_challenge_method=S256&" +
            $"code_challenge={oauthCodeChallenge}&redirect_uri={redirectUri}&loginRequestStep=";

        Log.Debug("Calling RSTS for provider initialization");
        RstsRequest(http, pkceUrl + StepInit, primaryFormData);

        Log.Debug("Calling RSTS for primary authentication");
        var (primaryBody, _) = RstsRequest(http, pkceUrl + StepPrimaryAuth, primaryFormData);

        HandleSecondaryAuthentication(http, pkceUrl, primaryFormData, primaryBody, secondaryPassword);

        Log.Debug("Calling RSTS for generate claims");
        var (claimsBody, claimsStatus) = RstsRequest(http, pkceUrl + StepGenerateClaims, primaryFormData);

        if (claimsStatus != HttpStatusCode.OK)
        {
            throw new SafeguardDotNetException(
                $"Failed to generate claims: {claimsBody}", claimsStatus, claimsBody);
        }

        var authorizationCode = ExtractAuthorizationCode(claimsBody);

        Log.Debug("Redeeming RSTS authorization code");

        using var rstsAccessToken = Safeguard.AgentBasedLoginUtils.PostAuthorizationCodeFlow(
            appliance, authorizationCode, oauthCodeVerifier, Safeguard.AgentBasedLoginUtils.RedirectUri);

        Log.Debug("Exchanging RSTS access token");

        var responseObject = Safeguard.AgentBasedLoginUtils.PostLoginResponse(appliance, rstsAccessToken, apiVersion);

        var statusValue = responseObject.GetValue("Status")?.ToString();

        if (string.IsNullOrEmpty(statusValue) || statusValue != "Success")
        {
            throw new SafeguardDotNetException($"Error exchanging RSTS token, status: {statusValue}");
        }

        using var accessToken = responseObject.GetValue("UserToken")?.ToString().ToSecureString();
        return Safeguard.Connect(appliance, accessToken, apiVersion, ignoreSsl);
    }

    private static void HandleSecondaryAuthentication(
        HttpClient http, string pkceUrl, string primaryFormData, string primaryAuthBody, SecureString secondaryPassword)
    {
        JObject primaryResponse;
        try
        {
            primaryResponse = JObject.Parse(primaryAuthBody);
        }
        catch
        {
            return; // Non-JSON response means no secondary auth info
        }

        var secondaryProviderId = primaryResponse["SecondaryProviderID"]?.ToString();

        if (string.IsNullOrEmpty(secondaryProviderId))
        {
            return; // No MFA required
        }

        Log.Debug("Secondary authentication required, provider: {SecondaryProviderId}", secondaryProviderId);

        if (secondaryPassword == null)
        {
            throw new SafeguardDotNetException(
                $"Multi-factor authentication is required (provider: {secondaryProviderId}) " +
                "but no secondary password was provided. Use the secondaryPassword parameter to supply the one-time code.");
        }

        Log.Debug("Calling RSTS for secondary provider initialization");
        var (initBody, initStatus) = RstsRequest(http, pkceUrl + StepSecondaryInit, primaryFormData);

        // Parse the MFA state from the secondary init response
        var mfaState = string.Empty;
        if (initStatus == HttpStatusCode.OK || (int)initStatus == 203)
        {
            try
            {
                var initResponse = JObject.Parse(initBody);
                mfaState = initResponse["State"]?.ToString() ?? string.Empty;
                var mfaMessage = initResponse["Message"]?.ToString();
                if (!string.IsNullOrEmpty(mfaMessage))
                {
                    Log.Debug("MFA prompt: {Message}", mfaMessage);
                }
            }
            catch
            {
                // Proceed without state if response isn't JSON
            }
        }

        // Submit the secondary password (OTP code) along with the primary form data
        var mfaFormData = primaryFormData +
            $"&secondaryLoginTextbox={Uri.EscapeDataString(secondaryPassword.ToInsecureString())}" +
            $"&secondaryAuthenticationStateTextbox={Uri.EscapeDataString(mfaState)}";

        Log.Debug("Calling RSTS for secondary authentication");
        var (mfaBody, mfaStatus) = RstsRequest(http, pkceUrl + StepSecondaryAuth, mfaFormData);

        // Step 5 returns empty string on success, or 203 with error details on failure
        if ((int)mfaStatus == 203)
        {
            var errorMessage = "Secondary authentication failed.";
            try
            {
                var mfaResponse = JObject.Parse(mfaBody);
                errorMessage = mfaResponse["Message"]?.ToString() ?? errorMessage;
            }
            catch
            {
                if (!string.IsNullOrEmpty(mfaBody))
                {
                    errorMessage = mfaBody;
                }
            }

            throw new SafeguardDotNetException(
                $"Multi-factor authentication failed: {errorMessage}");
        }

        if (!IsSuccessStatusCode(mfaStatus))
        {
            throw new SafeguardDotNetException(
                $"Multi-factor authentication failed: {mfaBody}", mfaStatus, mfaBody);
        }

        Log.Debug("Secondary authentication completed successfully");
    }

    private static string ExtractAuthorizationCode(string response)
    {
        string authorizationCode;
        try
        {
            var jsonObject = JObject.Parse(response);
            var relyingPartyUrl = jsonObject["RelyingPartyUrl"]?.ToString();

            if (string.IsNullOrEmpty(relyingPartyUrl))
            {
                throw new SafeguardDotNetException(
                    "rSTS response did not contain a RelyingPartyUrl. " +
                    "The authentication process may be incomplete.");
            }

            // Parse the query string to extract the authorization code
            var uri = new Uri(relyingPartyUrl);
            authorizationCode = HttpUtility.ParseQueryString(uri.Query)["code"];
        }
        catch (SafeguardDotNetException)
        {
            throw;
        }
        catch (Exception ex)
        {
            throw new SafeguardDotNetException("Failed to parse authorization code from rSTS response", ex);
        }

        if (string.IsNullOrEmpty(authorizationCode))
        {
            throw new SafeguardDotNetException("rSTS response did not contain an authorization code");
        }

        return authorizationCode;
    }

    private static string ResolveIdentityProvider(HttpClient http, string appliance, int apiVersion, string provider)
    {
        var coreUrl = $"https://{appliance}/service/core/v{apiVersion}";

        var (response, _) = RstsRequest(http, $"{coreUrl}/AuthenticationProviders", null, HttpMethod.Get, "application/json");
        var jProviders = JArray.Parse(response);
        var knownScopes = new List<(string RstsProviderId, string Name, string RstsProviderScope)>();
        if (jProviders != null)
        {
            knownScopes = jProviders.Select(s => (Id: s["RstsProviderId"].ToString(), Name: s["Name"].ToString(), Scope: s["RstsProviderScope"].ToString())).ToList();
        }

        // try to match what the user typed for provider to an rSTS ID
        var scope = knownScopes.FirstOrDefault(s => string.Equals(s.RstsProviderId, provider, StringComparison.OrdinalIgnoreCase));
        if (scope.RstsProviderId == null)
        {
            scope = knownScopes.FirstOrDefault(s => string.Equals(s.Name, provider, StringComparison.OrdinalIgnoreCase));

            if (scope.Name == null)
            {
                scope = knownScopes.FirstOrDefault(s => CultureInfo.InvariantCulture.CompareInfo.IndexOf(
                    s.RstsProviderId,
                    provider,
                    CompareOptions.IgnoreCase) >= 0);

                if (scope.RstsProviderId == null)
                {
                    throw new SafeguardDotNetException(
                        $"Unable to find scope matching '{provider}' in [{string.Join(",", knownScopes)}]");
                }
            }
        }

        return scope.RstsProviderId;
    }

    /// <summary>
    /// Makes a request to the rSTS login controller, returning the response body and status code.
    /// Throws <see cref="SafeguardDotNetException"/> for HTTP error responses (4xx/5xx) unless
    /// the caller handles specific status codes.
    /// </summary>
    private static (string Body, HttpStatusCode StatusCode) RstsRequest(
        HttpClient http,
        string url,
        string postData,
        HttpMethod method = null,
        string contentType = "application/x-www-form-urlencoded")
    {
        method ??= HttpMethod.Post;

        var req = new HttpRequestMessage
        {
            Method = method,
            RequestUri = new Uri(url, UriKind.Absolute),
        };

        req.Headers.Add("Accept", "application/json");

        if (postData != null)
        {
            req.Content = new StringContent(postData, Encoding.UTF8, contentType);
        }

        try
        {
            var res = http.SendAsync(req).GetAwaiter().GetResult();
            var body = res.Content?.ReadAsStringAsync().GetAwaiter().GetResult() ?? string.Empty;
            var statusCode = res.StatusCode;

            if (!IsSuccessStatusCode(statusCode) && (int)statusCode != 203)
            {
                // rSTS returns plain text error messages on failure (e.g. "Invalid password.")
                var errorMessage = !string.IsNullOrWhiteSpace(body) ? body.Trim() : statusCode.ToString();
                throw new SafeguardDotNetException(
                    $"rSTS authentication error: {errorMessage}", statusCode, body);
            }

            return (body, statusCode);
        }
        catch (TaskCanceledException)
        {
            throw new SafeguardDotNetException($"Request timed out connecting to {url}");
        }
        catch (HttpRequestException ex)
        {
            throw new SafeguardDotNetException($"Unable to connect to {url}: {ex.Message}", ex);
        }
    }

    private static bool IsSuccessStatusCode(HttpStatusCode statusCode)
    {
        return statusCode is >= HttpStatusCode.OK and <= (HttpStatusCode)299;
    }

    private static HttpClient CreateHttpClient(string appliance, string csrfToken, bool ignoreSsl)
    {
        // Create HttpClient with cookie container to maintain session state across requests
        var cookieContainer = new System.Net.CookieContainer();
        cookieContainer.SetCookies(new Uri($"https://{appliance}/RSTS"), $"CsrfToken={csrfToken}");
        var handler = new HttpClientHandler()
        {
            SslProtocols = System.Security.Authentication.SslProtocols.Tls12,
            UseCookies = true,
            CookieContainer = cookieContainer,
        };

        if (ignoreSsl)
        {
#pragma warning disable S4830 // Intentional SSL bypass when user explicitly opts in via ignoreSsl parameter
            handler.ServerCertificateCustomValidationCallback = (message, cert, chain, errors) => true;
#pragma warning restore S4830
        }

        return new HttpClient(handler);
    }
}
