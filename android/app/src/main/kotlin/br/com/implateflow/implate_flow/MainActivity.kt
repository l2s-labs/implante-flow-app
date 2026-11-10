package br.com.implateflow.implate_flow

import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var signIn: WorkOsSignIn
    private val handler = Handler(Looper.getMainLooper())
    private var browserOpen = false
    private var abandonAttempt = 0
    private var abandonRunnable: Runnable? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        signIn = WorkOsSignIn(applicationContext) { uri, ephemeral ->
            browserOpen = true
            openAuthTab(this, uri, ephemeral)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "signIn" -> {
                    val clientId = call.argument<String>("clientId").orEmpty()
                    val redirectUri = call.argument<String>("redirectUri").orEmpty()
                    if (clientId.isEmpty() || redirectUri.isEmpty()) {
                        result.error("config", "O login do WorkOS não está configurado.", null)
                        return@setMethodCallHandler
                    }
                    signIn.start(clientId, redirectUri, result)
                }
                "currentIdentity" -> {
                    val clientId = call.argument<String>("clientId").orEmpty()
                    signIn.currentIdentity(clientId, result)
                }
                "signOut" -> {
                    val returnTo = call.argument<String>("redirectUri").orEmpty()
                    if (returnTo.isEmpty()) {
                        signIn.signOut(returnTo = "${getString(R.string.auth_scheme)}://auth/callback", result = result)
                    } else {
                        signIn.signOut(returnTo = returnTo, result = result)
                    }
                }
                else -> result.notImplemented()
            }
        }
        consumeRedirect(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeRedirect(intent)
    }

    override fun onResume() {
        super.onResume()
        if (!browserOpen || !::signIn.isInitialized) return
        val attempt = ++abandonAttempt
        val runnable = Runnable {
            if (browserOpen && attempt == abandonAttempt) {
                browserOpen = false
                signIn.cancelIfAbandoned()
            }
        }
        abandonRunnable = runnable
        handler.postDelayed(runnable, ABANDON_DELAY_MS)
    }

    override fun onPause() {
        cancelAbandon()
        super.onPause()
    }

    private fun consumeRedirect(intent: Intent?) {
        val uri = intent?.data ?: return
        if (uri.scheme != getString(R.string.auth_scheme) || uri.host != "auth") return
        cancelAbandon()
        browserOpen = false
        if (::signIn.isInitialized) {
            signIn.handleRedirect(uri)
        }
        setIntent(Intent(this, MainActivity::class.java))
    }

    private fun cancelAbandon() {
        abandonAttempt++
        abandonRunnable?.let(handler::removeCallbacks)
        abandonRunnable = null
    }

    companion object {
        private const val CHANNEL = "br.com.implateflow/workos"
        private const val ABANDON_DELAY_MS = 1_000L
    }
}
