package com.example.soilair

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.soilair/wifi"
        const val TIMEOUT_MS = 15_000L
    }

    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                "conectarWifi" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                        result.error(
                            "NO_SOPORTADO",
                            "WifiNetworkSpecifier requiere Android 10 o superior.",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    val ssid = call.argument<String>("ssid")
                    val password = call.argument<String>("password")
                    if (ssid.isNullOrBlank()) {
                        result.error("SSID_VACIO", "El SSID no puede estar vacío.", null)
                        return@setMethodCallHandler
                    }
                    conectarWifi(ssid, password ?: "", result)
                }

                "desconectarWifi" -> {
                    desconectarWifi()
                    result.success(null)
                }

                "redActual" -> {
                    result.success(obtenerSsidActual())
                }

                else -> result.notImplemented()
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun conectarWifi(ssid: String, password: String, result: MethodChannel.Result) {
        desconectarWifi()

        val specifier = WifiNetworkSpecifier.Builder()
            .setSsid(ssid)
            .apply { if (password.isNotEmpty()) setWpa2Passphrase(password) }
            .build()

        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(specifier)
            .build()

        val handler = Handler(Looper.getMainLooper())
        var respondido = false

        val timeoutRunnable = Runnable {
            if (!respondido) {
                respondido = true
                desconectarWifi()
                result.error(
                    "TIMEOUT",
                    "No se pudo conectar a $ssid en ${TIMEOUT_MS / 1000}s. " +
                    "Asegúrate de que el ESP32 esté encendido y cerca.",
                    null
                )
            }
        }
        handler.postDelayed(timeoutRunnable, TIMEOUT_MS)

        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                if (respondido) return
                respondido = true
                handler.removeCallbacks(timeoutRunnable)
                connectivityManager?.bindProcessToNetwork(network)
                Handler(Looper.getMainLooper()).post { result.success("conectado") }
            }

            override fun onLost(network: Network) {
                connectivityManager?.bindProcessToNetwork(null)
            }

            override fun onUnavailable() {
                if (respondido) return
                respondido = true
                handler.removeCallbacks(timeoutRunnable)
                Handler(Looper.getMainLooper()).post {
                    result.error(
                        "NO_DISPONIBLE",
                        "La red $ssid no está disponible. Verifica que el ESP32 esté encendido.",
                        null
                    )
                }
            }
        }

        connectivityManager?.requestNetwork(request, networkCallback!!, handler)
    }

    private fun desconectarWifi() {
        networkCallback?.let {
            try { connectivityManager?.unregisterNetworkCallback(it) } catch (_: Exception) {}
            networkCallback = null
        }
        connectivityManager?.bindProcessToNetwork(null)
    }

    private fun obtenerSsidActual(): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val network = connectivityManager?.activeNetwork ?: return null
        val caps = connectivityManager?.getNetworkCapabilities(network) ?: return null
        return if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
            val info = caps.transportInfo
            if (info is android.net.wifi.WifiInfo) info.ssid?.trim('"') else null
        } else null
    }

    override fun onDestroy() {
        desconectarWifi()
        super.onDestroy()
    }
}
