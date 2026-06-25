package app.sayitapp.fidelio_wallet

import android.content.ComponentName
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.cardemulation.CardEmulation
import android.nfc.tech.IsoDep
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

class MainActivity : FlutterActivity(), NfcAdapter.ReaderCallback {
    private var pendingReadResult: MethodChannel.Result? = null
    private var pendingReceiveResult: MethodChannel.Result? = null
    private var pendingSendResult: MethodChannel.Result? = null
    private var pendingSendPayload: ByteArray? = null
    private var nfcAdapter: NfcAdapter? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val readTimeout = Runnable {
        finishActiveReaderWithError("NFC_TIMEOUT", "No Fidelio NFC device was detected.")
    }
    private val receiveTimeout = Runnable {
        finishReceiveWithError("NFC_TIMEOUT", "No NFC payload was received.")
    }
    private val payloadReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != FidelioHostApduService.ACTION_PAYLOAD_RECEIVED) return
            finishReceiveWithSuccess(FidelioNfcPayloadStore.getPayload(applicationContext))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(isNfcAvailable())
                "sharePayload" -> sharePayload(call, result)
                "readPayload" -> readPayload(result)
                "sendPayload" -> sendPayload(call, result)
                "receivePayload" -> receivePayload(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onTagDiscovered(tag: Tag?) {
        val isoDep = tag?.let { IsoDep.get(it) }
        if (isoDep == null) {
            finishActiveReaderWithError("UNSUPPORTED_TAG", "The other device does not expose Fidelio NFC access.")
            return
        }

        try {
            isoDep.connect()
            isoDep.timeout = 5000
            requireStatusOk(isoDep.transceive(SELECT_AID_COMMAND))

            val sendPayload = pendingSendPayload
            if (pendingSendResult != null && sendPayload != null) {
                sendPayloadToPeer(isoDep, sendPayload)
                finishSendWithSuccess()
                return
            }

            val infoResponse = isoDep.transceive(GET_INFO_COMMAND)
            requireStatusOk(infoResponse)
            val payloadLength = ByteBuffer.wrap(infoResponse.copyOfRange(0, 4)).int
            if (payloadLength <= 0 || payloadLength > MAX_PAYLOAD_SIZE) {
                throw IllegalStateException("Invalid NFC payload size.")
            }

            val output = ByteArrayOutputStream(payloadLength)
            var offset = 0
            while (offset < payloadLength) {
                val chunkSize = minOf(MAX_CHUNK_SIZE, payloadLength - offset)
                val response = isoDep.transceive(readCommand(offset, chunkSize))
                requireStatusOk(response)
                val chunk = response.copyOfRange(0, response.size - 2)
                output.write(chunk)
                offset += chunk.size
            }

            finishReadWithSuccess(output.toByteArray().toString(Charsets.UTF_8))
        } catch (error: Exception) {
            finishActiveReaderWithError("NFC_FAILED", error.message ?: error.toString())
        } finally {
            try { isoDep.close() } catch (_: Exception) {}
        }
    }

    private fun sharePayload(call: MethodCall, result: MethodChannel.Result) {
        val payload = call.arguments as? String
        if (payload.isNullOrBlank()) {
            result.error("INVALID_PAYLOAD", "The NFC payload is empty.", null)
            return
        }
        if (!isHceAvailable()) {
            result.error("NFC_UNAVAILABLE", "NFC card emulation is not available on this Android device.", null)
            return
        }
        FidelioNfcPayloadStore.setPayload(applicationContext, payload)
        setPreferredHceService()
        result.success(null)
    }

    private fun readPayload(result: MethodChannel.Result) {
        if (!isNfcAvailable()) {
            result.error("NFC_UNAVAILABLE", "NFC is not available or enabled on this Android device.", null)
            return
        }
        if (pendingReadResult != null) {
            result.error("NFC_BUSY", "An NFC read is already in progress.", null)
            return
        }
        pendingReadResult = result
        mainHandler.postDelayed(readTimeout, READ_TIMEOUT_MS)
        enableReaderMode()
    }

    private fun sendPayload(call: MethodCall, result: MethodChannel.Result) {
        val payload = call.arguments as? String
        if (payload.isNullOrBlank()) {
            result.error("INVALID_PAYLOAD", "The NFC payload is empty.", null)
            return
        }
        if (!isNfcAvailable()) {
            result.error("NFC_UNAVAILABLE", "NFC is not available or enabled on this Android device.", null)
            return
        }
        if (pendingSendResult != null || pendingReadResult != null) {
            result.error("NFC_BUSY", "An NFC operation is already in progress.", null)
            return
        }
        pendingSendPayload = payload.toByteArray(Charsets.UTF_8)
        pendingSendResult = result
        mainHandler.postDelayed(readTimeout, READ_TIMEOUT_MS)
        enableReaderMode()
    }

    private fun receivePayload(result: MethodChannel.Result) {
        if (!isHceAvailable()) {
            result.error("NFC_UNAVAILABLE", "NFC card emulation is not available on this Android device.", null)
            return
        }
        if (pendingReceiveResult != null) {
            result.error("NFC_BUSY", "An NFC receive is already in progress.", null)
            return
        }
        FidelioNfcPayloadStore.startReceive(applicationContext)
        setPreferredHceService()
        pendingReceiveResult = result
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                payloadReceiver,
                IntentFilter(FidelioHostApduService.ACTION_PAYLOAD_RECEIVED),
                RECEIVER_NOT_EXPORTED,
            )
        } else {
            registerReceiver(
                payloadReceiver,
                IntentFilter(FidelioHostApduService.ACTION_PAYLOAD_RECEIVED),
            )
        }
        mainHandler.postDelayed(receiveTimeout, READ_TIMEOUT_MS)
    }

    private fun enableReaderMode() {
        nfcAdapter?.enableReaderMode(
            this, this,
            NfcAdapter.FLAG_READER_NFC_A or
                NfcAdapter.FLAG_READER_NFC_B or
                NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK or
                NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS,
            null,
        )
    }

    private fun isNfcAvailable(): Boolean = nfcAdapter?.isEnabled == true

    private fun isHceAvailable(): Boolean =
        isNfcAvailable() &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_NFC_HOST_CARD_EMULATION)

    private fun setPreferredHceService() {
        val adapter = nfcAdapter ?: return
        val cardEmulation = CardEmulation.getInstance(adapter)
        val service = ComponentName(this, FidelioHostApduService::class.java)
        cardEmulation.setPreferredService(this, service)
    }

    private fun finishReadWithSuccess(payload: String) {
        val result = pendingReadResult ?: return
        pendingReadResult = null
        runOnUiThread {
            mainHandler.removeCallbacks(readTimeout)
            nfcAdapter?.disableReaderMode(this)
            result.success(payload)
        }
    }

    private fun finishSendWithSuccess() {
        val result = pendingSendResult ?: return
        pendingSendResult = null
        pendingSendPayload = null
        runOnUiThread {
            mainHandler.removeCallbacks(readTimeout)
            nfcAdapter?.disableReaderMode(this)
            result.success(null)
        }
    }

    private fun finishReadWithError(code: String, message: String) {
        val result = pendingReadResult ?: return
        pendingReadResult = null
        runOnUiThread {
            mainHandler.removeCallbacks(readTimeout)
            nfcAdapter?.disableReaderMode(this)
            result.error(code, message, null)
        }
    }

    private fun finishActiveReaderWithError(code: String, message: String) {
        if (pendingSendResult != null) { finishSendWithError(code, message); return }
        finishReadWithError(code, message)
    }

    private fun finishSendWithError(code: String, message: String) {
        val result = pendingSendResult ?: return
        pendingSendResult = null
        pendingSendPayload = null
        runOnUiThread {
            mainHandler.removeCallbacks(readTimeout)
            nfcAdapter?.disableReaderMode(this)
            result.error(code, message, null)
        }
    }

    private fun finishReceiveWithSuccess(payload: String) {
        val result = pendingReceiveResult ?: return
        pendingReceiveResult = null
        runOnUiThread {
            mainHandler.removeCallbacks(receiveTimeout)
            try { unregisterReceiver(payloadReceiver) } catch (_: Exception) {}
            result.success(payload)
        }
    }

    private fun finishReceiveWithError(code: String, message: String) {
        val result = pendingReceiveResult ?: return
        pendingReceiveResult = null
        runOnUiThread {
            mainHandler.removeCallbacks(receiveTimeout)
            try { unregisterReceiver(payloadReceiver) } catch (_: Exception) {}
            result.error(code, message, null)
        }
    }

    private fun requireStatusOk(response: ByteArray) {
        if (response.size < 2 ||
            response[response.size - 2] != 0x90.toByte() ||
            response[response.size - 1] != 0x00.toByte()
        ) {
            throw IllegalStateException("The other device rejected the NFC request.")
        }
    }

    private fun readCommand(offset: Int, length: Int): ByteArray = byteArrayOf(
        0x80.toByte(), 0xB0.toByte(),
        ((offset ushr 8) and 0xff).toByte(),
        (offset and 0xff).toByte(),
        length.toByte(),
    )

    private fun sendPayloadToPeer(isoDep: IsoDep, payload: ByteArray) {
        requireStatusOk(isoDep.transceive(writeInitCommand(payload.size)))
        var offset = 0
        while (offset < payload.size) {
            val chunkLength = minOf(MAX_CHUNK_SIZE, payload.size - offset)
            val chunk = payload.copyOfRange(offset, offset + chunkLength)
            requireStatusOk(isoDep.transceive(writeChunkCommand(chunk)))
            offset += chunkLength
        }
        requireStatusOk(isoDep.transceive(WRITE_COMMIT_COMMAND))
    }

    private fun writeInitCommand(length: Int): ByteArray =
        byteArrayOf(0x80.toByte(), 0xD0.toByte(), 0x00.toByte(), 0x00.toByte(), 0x04.toByte()) +
            ByteBuffer.allocate(4).putInt(length).array()

    private fun writeChunkCommand(chunk: ByteArray): ByteArray =
        byteArrayOf(0x80.toByte(), 0xD1.toByte(), 0x00.toByte(), 0x00.toByte(), chunk.size.toByte()) + chunk

    companion object {
        private const val CHANNEL_NAME = "fidelio/nfc_access"
        private const val MAX_CHUNK_SIZE = 220
        private const val MAX_PAYLOAD_SIZE = 16 * 1024
        private const val READ_TIMEOUT_MS = 20_000L
        private val SELECT_AID_COMMAND = byteArrayOf(
            0x00.toByte(), 0xA4.toByte(), 0x04.toByte(), 0x00.toByte(), 0x07.toByte(),
            0xF0.toByte(), 0x01.toByte(), 0x02.toByte(), 0x03.toByte(),
            0x04.toByte(), 0x05.toByte(), 0x06.toByte(), 0x00.toByte(),
        )
        private val GET_INFO_COMMAND = byteArrayOf(
            0x80.toByte(), 0xCA.toByte(), 0x00.toByte(), 0x00.toByte(), 0x00.toByte(),
        )
        private val WRITE_COMMIT_COMMAND = byteArrayOf(
            0x80.toByte(), 0xD2.toByte(), 0x00.toByte(), 0x00.toByte(), 0x00.toByte(),
        )
    }
}
