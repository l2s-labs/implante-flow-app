package br.com.implateflow.implate_flow

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.util.Base64
import android.util.Log
import androidx.browser.customtabs.CustomTabsIntent
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.workos.android.enums.UserManagementAuthenticationProvider
import com.workos.android.helpers.PublicClient
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class WorkOsSignIn(
    private val context: Context,
    private val openBrowser: (Uri, Boolean) -> Unit,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val lock = Any()
    private var waiter: MethodChannel.Result? = null
    private var signingOut = false
    private var consumedCode: String? = null
    private var pendingClientId: String? = null
    private var pendingVerifier: String? = null
    private var pendingState: String? = null
    private var prefs: SharedPreferences? = null

    fun start(clientId: String, redirectUri: String, result: MethodChannel.Result) {
        if (waiter != null) {
            result.error("busy", "Já existe um login em andamento.", null)
            return
        }
        waiter = result
        signingOut = false
        consumedCode = null
        scope.launch {
            try {
                val authorization = withContext(Dispatchers.IO) {
                    PublicClient.create(clientId = clientId).getAuthorizationUrlWithPkce(redirectUri)
                }
                val withProvider = Uri.parse(authorization.url).buildUpon()
                    .appendQueryParameter("provider", UserManagementAuthenticationProvider.Authkit.rawValue)
                    .appendQueryParameter("prompt", "login")
                    .appendQueryParameter("max_age", "0")
                    .build()
                pendingClientId = clientId
                pendingVerifier = authorization.codeVerifier
                pendingState = authorization.state
                preferences().edit()
                    .putString(KEY_CLIENT_ID, clientId)
                    .putString(KEY_VERIFIER, authorization.codeVerifier)
                    .putString(KEY_STATE, authorization.state)
                    .remove(KEY_REFRESH)
                    .commit()
                openBrowser(withProvider, true)
            } catch (error: Exception) {
                Log.e(TAG, "Could not start WorkOS sign-in", error)
                fail("Não foi possível abrir o login.")
            }
        }
    }

    fun handleRedirect(uri: Uri?) {
        if (uri == null || uri.scheme != "br.com.implateflow" || uri.host != "auth") return
        if (signingOut) {
            finishSignOut()
            return
        }
        val error = uri.getQueryParameter("error")
        if (!error.isNullOrEmpty()) {
            val description = uri.getQueryParameter("error_description")?.takeIf { it.isNotBlank() }
            fail(description ?: "Login cancelado.")
            return
        }
        val code = uri.getQueryParameter("code")
        val state = uri.getQueryParameter("state")
        if (code.isNullOrEmpty() || code == consumedCode) return
        val result = takeWaiter()
        if (result == null) {
            Log.w(TAG, "Redirect arrived without a pending sign-in")
            return
        }
        consumedCode = code
        val stored = preferences()
        val expected = pendingState ?: stored.getString(KEY_STATE, null)
        val verifier = pendingVerifier ?: stored.getString(KEY_VERIFIER, null)
        val currentClientId = pendingClientId ?: stored.getString(KEY_CLIENT_ID, null)
        clearPending()
        if (verifier.isNullOrEmpty() || state.isNullOrEmpty() || state != expected) {
            result.error("state", "Não foi possível confirmar o login.", null)
            return
        }
        if (currentClientId.isNullOrEmpty()) {
            result.error("client", "Não foi possível concluir o login.", null)
            return
        }
        scope.launch {
            try {
                val identity = withContext(Dispatchers.IO) {
                    exchangeCode(clientId = currentClientId, code = code, codeVerifier = verifier)
                }
                try {
                    preferences().edit()
                        .apply {
                            identity.refreshToken?.let { putString(KEY_REFRESH, it) }
                            identity.sessionId?.let { putString(KEY_SESSION, it) }
                        }
                        .apply()
                } catch (error: Exception) {
                    Log.e(TAG, "Could not store WorkOS session", error)
                }
                result.success(identity.toMap())
            } catch (error: Exception) {
                Log.e(TAG, "WorkOS code exchange failed", error)
                result.error("exchange", error.message?.takeIf { it.isNotBlank() } ?: "Não foi possível concluir o login.", null)
            }
        }
    }

    fun cancelIfAbandoned() {
        if (signingOut) {
            finishSignOut()
            return
        }
        fail("Login cancelado.")
    }

    fun currentIdentity(clientId: String, result: MethodChannel.Result) {
        if (clientId.isEmpty()) {
            result.success(null)
            return
        }
        val refresh = preferences().getString(KEY_REFRESH, null)
        if (refresh.isNullOrEmpty()) {
            result.success(null)
            return
        }
        scope.launch {
            try {
                val identity = withContext(Dispatchers.IO) {
                    refreshIdentity(clientId = clientId, refreshToken = refresh)
                }
                try {
                    preferences().edit()
                        .apply {
                            identity.refreshToken?.let { putString(KEY_REFRESH, it) }
                            identity.sessionId?.let { putString(KEY_SESSION, it) }
                        }
                        .apply()
                } catch (error: Exception) {
                    Log.e(TAG, "Could not store WorkOS session", error)
                }
                result.success(identity.toMap())
            } catch (error: java.io.IOException) {
                Log.w(TAG, "Could not refresh the WorkOS profile (network)", error)
                result.error("network", "Sem conexão para renovar a sessão.", null)
            } catch (error: WorkOsExchangeException) {
                Log.w(TAG, "Could not refresh the WorkOS profile", error)
                clearSession()
                result.success(null)
            } catch (error: Exception) {
                Log.w(TAG, "Could not refresh the WorkOS profile", error)
                result.success(null)
            }
        }
    }

    fun signOut(returnTo: String, result: MethodChannel.Result) {
        if (waiter != null) {
            result.error("busy", "Já existe um login em andamento.", null)
            return
        }
        val sessionId = preferences().getString(KEY_SESSION, null)
        clearSession()
        if (sessionId.isNullOrEmpty()) {
            result.success(null)
            return
        }
        waiter = result
        signingOut = true
        val logout = Uri.parse(LOGOUT_URL).buildUpon()
            .appendQueryParameter("session_id", sessionId)
            .appendQueryParameter("return_to", returnTo)
            .build()
        openBrowser(logout, false)
    }

    private fun takeWaiter(): MethodChannel.Result? {
        val result = waiter
        waiter = null
        return result
    }

    private fun finishSignOut() {
        signingOut = false
        takeWaiter()?.success(null)
        clearSession()
    }

    private fun fail(message: String) {
        signingOut = false
        takeWaiter()?.error("workos", message, null)
        clearPending()
    }

    private fun clearPending() {
        pendingClientId = null
        pendingVerifier = null
        pendingState = null
        preferences().edit()
            .remove(KEY_VERIFIER)
            .remove(KEY_STATE)
            .remove(KEY_CLIENT_ID)
            .apply()
    }

    private fun clearSession() {
        clearPending()
        preferences().edit().remove(KEY_REFRESH).remove(KEY_SESSION).apply()
    }

    private fun preferences(): SharedPreferences {
        synchronized(lock) {
            prefs?.let { return it }
            val created = EncryptedSharedPreferences.create(
                context,
                "workos_auth",
                MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
            prefs = created
            return created
        }
    }

    private fun refreshIdentity(clientId: String, refreshToken: String): WorkOsIdentity {
        return authenticate(
            JSONObject()
                .put("client_id", clientId)
                .put("grant_type", "refresh_token")
                .put("refresh_token", refreshToken),
        )
    }

    private fun exchangeCode(clientId: String, code: String, codeVerifier: String): WorkOsIdentity {
        return authenticate(
            JSONObject()
                .put("client_id", clientId)
                .put("grant_type", "authorization_code")
                .put("code", code)
                .put("code_verifier", codeVerifier),
        )
    }

    private fun authenticate(body: JSONObject): WorkOsIdentity {
        val connection = (URL(AUTHENTICATE_URL).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 30_000
            readTimeout = 30_000
            doOutput = true
            setRequestProperty("Accept", "application/json")
            setRequestProperty("Content-Type", "application/json")
        }
        try {
            connection.outputStream.use { output ->
                output.write(body.toString().toByteArray(Charsets.UTF_8))
            }
            val status = connection.responseCode
            val payload = (if (status in 200..299) connection.inputStream else connection.errorStream)
                ?.bufferedReader()
                ?.use { it.readText() }
                .orEmpty()
            if (status !in 200..299) {
                throw WorkOsExchangeException(exchangeErrorMessage(payload))
            }
            val json = JSONObject(payload)
            val user = json.getJSONObject("user")
            val email = user.getString("email")
            val accessToken = json.optString("access_token").takeIf { it.isNotBlank() }
            return WorkOsIdentity(
                id = user.getString("id"),
                email = email,
                name = registeredName(user, email),
                refreshToken = json.optString("refresh_token").takeIf { it.isNotBlank() },
                accessToken = accessToken,
                sessionId = sessionIdFrom(accessToken ?: ""),
            )
        } finally {
            connection.disconnect()
        }
    }

    companion object {
        private const val TAG = "WorkOsSignIn"
        private const val AUTHENTICATE_URL = "https://api.workos.com/user_management/authenticate"
        private const val LOGOUT_URL = "https://api.workos.com/user_management/sessions/logout"
        private const val KEY_CLIENT_ID = "client_id"
        private const val KEY_VERIFIER = "code_verifier"
        private const val KEY_STATE = "state"
        private const val KEY_REFRESH = "refresh_token"
        private const val KEY_SESSION = "session_id"

        private fun registeredName(user: JSONObject, email: String): String {
            val full = readableField(user, "name")
            if (full.isNotEmpty()) return full
            val combined = listOf("first_name", "last_name")
                .map { readableField(user, it) }
                .filter { it.isNotEmpty() }
                .joinToString(" ")
            return combined.ifEmpty { email }
        }

        /** optString devolve a literal "null" quando o JSON tem null. */
        private fun readableField(user: JSONObject, key: String): String {
            if (user.isNull(key)) return ""
            val value = user.optString(key).trim()
            return if (value.equals("null", ignoreCase = true) || value.equals("undefined", ignoreCase = true)) {
                ""
            } else {
                value
            }
        }

        private fun sessionIdFrom(accessToken: String): String? {
            if (accessToken.isBlank()) return null
            val payload = accessToken.split('.').getOrNull(1) ?: return null
            return try {
                val decoded = String(
                    Base64.decode(payload, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP),
                    Charsets.UTF_8,
                )
                JSONObject(decoded).optString("sid").takeIf { it.isNotBlank() }
            } catch (_: Exception) {
                null
            }
        }

        private fun exchangeErrorMessage(payload: String): String {
            if (payload.isBlank()) return "Não foi possível concluir o login."
            return try {
                val json = JSONObject(payload)
                val message = json.optString("message").takeIf { it.isNotBlank() }
                val param = json.optJSONArray("errors")
                    ?.optJSONObject(0)
                    ?.optString("field")
                    ?.takeIf { it.isNotBlank() }
                    ?: json.optString("param").takeIf { it.isNotBlank() }
                when {
                    message != null && param != null -> "$message ($param)"
                    message != null -> message
                    else -> "Não foi possível concluir o login."
                }
            } catch (_: Exception) {
                "Não foi possível concluir o login."
            }
        }
    }
}

private data class WorkOsIdentity(
    val id: String,
    val email: String,
    val name: String,
    val refreshToken: String?,
    val accessToken: String?,
    val sessionId: String?,
) {
    fun toMap(): HashMap<String, String> = hashMapOf(
        "id" to id,
        "email" to email,
        "name" to name,
        "accessToken" to (accessToken ?: ""),
    )
}

private class WorkOsExchangeException(message: String) : Exception(message)

fun openAuthTab(context: Context, uri: Uri, ephemeral: Boolean) {
    val builder = CustomTabsIntent.Builder().setShowTitle(true)
    if (ephemeral) {
        builder.setEphemeralBrowsingEnabled(true)
    }
    val tabs = builder.build()
    preferredCustomTabsPackage(context)?.let { tabs.intent.setPackage(it) }
    tabs.launchUrl(context, uri)
}

private fun preferredCustomTabsPackage(context: Context): String? {
    val chrome = listOf("com.android.chrome", "com.chrome.beta", "com.google.android.apps.chrome")
    return chrome.firstOrNull { packageSupportsCustomTabs(context, it) }
        ?: customTabsPackages(context).firstOrNull()
}

private fun customTabsPackages(context: Context): List<String> {
    val pm = context.packageManager
    val browsers = pm.queryIntentActivities(Intent(Intent.ACTION_VIEW, Uri.parse("https://authkit.app")), 0)
    return browsers.map { it.activityInfo.packageName }.filter { packageSupportsCustomTabs(context, it) }
}

private fun packageSupportsCustomTabs(context: Context, packageName: String): Boolean {
    val service = Intent("android.support.customtabs.action.CustomTabsService").setPackage(packageName)
    return context.packageManager.resolveService(service, 0) != null
}
