package com.oneidentity.safeguard.safeguardjava;

import com.oneidentity.safeguard.safeguardjava.exceptions.SafeguardForJavaException;
import com.oneidentity.safeguard.safeguardjava.restclient.RestClient;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import javax.net.ssl.HostnameVerifier;
import org.apache.hc.client5.http.impl.classic.CloseableHttpResponse;

/**
 * Utility class for agent-based and PKCE OAuth2 login flows.
 * Provides helpers for generating PKCE code verifiers, code challenges,
 * CSRF tokens, and completing the authorization code exchange.
 */
public final class AgentBasedLoginUtils {

    private static final Logger logger = LoggerFactory.getLogger(AgentBasedLoginUtils.class);

    /** Standard redirect URI for installed applications. */
    public static final String REDIRECT_URI = "urn:InstalledApplication";

    /** Redirect URI for TCP listener-based authentication. */
    public static final String REDIRECT_URI_TCP_LISTENER = "urn:InstalledApplicationTcpListener";

    private static final SecureRandom RANDOM = new SecureRandom();

    private AgentBasedLoginUtils() {
    }

    /**
     * Generates a cryptographically random code verifier for PKCE OAuth2 flow.
     *
     * @return A base64url-encoded code verifier string.
     */
    public static String oAuthCodeVerifier() {
        byte[] bytes = new byte[60];
        RANDOM.nextBytes(bytes);
        return toBase64Url(bytes);
    }

    /**
     * Generates a PKCE code challenge from a code verifier using SHA-256.
     *
     * @param codeVerifier The code verifier string.
     * @return A base64url-encoded SHA-256 hash of the code verifier.
     */
    public static String oAuthCodeChallenge(String codeVerifier) {
        try {
            MessageDigest sha256 = MessageDigest.getInstance("SHA-256");
            byte[] hash = sha256.digest(codeVerifier.getBytes(StandardCharsets.US_ASCII));
            return toBase64Url(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 algorithm not available", e);
        }
    }

    /**
     * Generates a cryptographically random CSRF token.
     *
     * @return A base64url-encoded random token string.
     */
    public static String generateCsrfToken() {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        return toBase64Url(bytes);
    }

    /**
     * Posts the OAuth2 authorization code to complete the PKCE flow and obtain
     * an RSTS access token.
     *
     * @param appliance Network address of the Safeguard appliance.
     * @param authorizationCode The authorization code from the authorization endpoint.
     * @param codeVerifier The PKCE code verifier matching the original code challenge.
     * @param redirectUri The redirect URI used in the authorization request.
     * @param ignoreSsl Whether to ignore SSL certificate validation.
     * @param validationCallback Optional hostname verifier callback.
     * @return The RSTS access token as a char array.
     * @throws SafeguardForJavaException If the token exchange fails.
     */
    public static char[] postAuthorizationCodeFlow(String appliance, String authorizationCode,
            String codeVerifier, String redirectUri, boolean ignoreSsl,
            HostnameVerifier validationCallback) throws SafeguardForJavaException {

        String rstsUrl = String.format("https://%s/RSTS", appliance);
        RestClient rstsClient = new RestClient(rstsUrl, ignoreSsl, validationCallback);

        String body = String.format(
                "{\"grant_type\":\"authorization_code\",\"redirect_uri\":\"%s\",\"code\":\"%s\",\"code_verifier\":\"%s\"}",
                redirectUri, authorizationCode, codeVerifier);

        CloseableHttpResponse response = rstsClient.execPOST("oauth2/token", null, null, null,
                new com.oneidentity.safeguard.safeguardjava.data.JsonBody(body));

        if (response == null) {
            throw new SafeguardForJavaException(
                    String.format("Unable to connect to RSTS service %s", rstsUrl));
        }

        String reply = Utils.getResponse(response);
        if (!Utils.isSuccessful(response.getCode())) {
            throw new SafeguardForJavaException(
                    "Error exchanging authorization code for RSTS token, Error: "
                    + String.format("%d %s", response.getCode(), reply));
        }

        Map<String, String> map = Utils.parseResponse(reply);
        if (!map.containsKey("access_token")) {
            throw new SafeguardForJavaException("RSTS token response did not contain an access_token");
        }

        return map.get("access_token").toCharArray();
    }

    /**
     * Posts the RSTS access token to the Safeguard API to obtain a Safeguard user token.
     *
     * @param appliance Network address of the Safeguard appliance.
     * @param rstsAccessToken The RSTS access token from the OAuth2 flow.
     * @param apiVersion Target API version to use.
     * @param ignoreSsl Whether to ignore SSL certificate validation.
     * @param validationCallback Optional hostname verifier callback.
     * @return A map containing the login response (includes UserToken and Status).
     * @throws SafeguardForJavaException If the token exchange fails.
     */
    public static Map<String, String> postLoginResponse(String appliance, char[] rstsAccessToken,
            int apiVersion, boolean ignoreSsl,
            HostnameVerifier validationCallback) throws SafeguardForJavaException {

        String coreUrl = String.format("https://%s/service/core/v%d", appliance, apiVersion);
        RestClient coreClient = new RestClient(coreUrl, ignoreSsl, validationCallback);

        String body = String.format("{\"StsAccessToken\":\"%s\"}", new String(rstsAccessToken));

        CloseableHttpResponse response = coreClient.execPOST("Token/LoginResponse", null, null, null,
                new com.oneidentity.safeguard.safeguardjava.data.JsonBody(body));

        if (response == null) {
            throw new SafeguardForJavaException(
                    String.format("Unable to connect to web service %s", coreUrl));
        }

        String reply = Utils.getResponse(response);
        if (!Utils.isSuccessful(response.getCode())) {
            throw new SafeguardForJavaException(
                    "Error exchanging RSTS token for Safeguard API access token, Error: "
                    + String.format("%d %s", response.getCode(), reply));
        }

        return Utils.parseResponse(reply);
    }

    /**
     * Converts a byte array to a base64url-encoded string (no padding).
     */
    private static String toBase64Url(byte[] data) {
        // Use java.util.Base64 which is available in Java 8+
        String base64 = java.util.Base64.getEncoder().encodeToString(data);
        // Convert to base64url: replace + with -, / with _, remove trailing =
        return base64.replace('+', '-').replace('/', '_').replaceAll("=+$", "");
    }
}
