package com.bettin.salute_bettin

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.bettin.salute_bettin/file_picker"
    private var pendingResult: MethodChannel.Result? = null

    private val pdfPickerLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        val pending = pendingResult ?: return@registerForActivityResult
        pendingResult = null

        if (result.resultCode != Activity.RESULT_OK) {
            pending.success(null)
            return@registerForActivityResult
        }

        val data = result.data ?: run {
            pending.error("NO_DATA", "Nessun file selezionato", null)
            return@registerForActivityResult
        }

        try {
            val uris = mutableListOf<Uri>()

            // Selezione multipla: clipData contiene tutti i file
            if (data.clipData != null) {
                val clip = data.clipData!!
                for (i in 0 until clip.itemCount) {
                    uris.add(clip.getItemAt(i).uri)
                }
            } else if (data.data != null) {
                // Selezione singola
                uris.add(data.data!!)
            }

            if (uris.isEmpty()) {
                pending.error("NO_URI", "Nessun file selezionato", null)
                return@registerForActivityResult
            }

            // Legge i byte di ogni file e li restituisce come lista
            val result2 = mutableListOf<ByteArray>()
            for (uri in uris) {
                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                if (bytes != null && bytes.isNotEmpty()) {
                    result2.add(bytes)
                }
            }

            if (result2.isEmpty()) {
                pending.error("EMPTY_FILE", "File vuoti o non leggibili", null)
            } else {
                pending.success(result2)
            }
        } catch (e: Exception) {
            pending.error("READ_ERROR", "Errore lettura: ${e.message}", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickPdf" -> {
                        if (pendingResult != null) {
                            result.error("BUSY", "Picker gia aperto", null)
                            return@setMethodCallHandler
                        }
                        pendingResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/pdf"
                            // Abilita selezione multipla
                            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        pdfPickerLauncher.launch(intent)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
