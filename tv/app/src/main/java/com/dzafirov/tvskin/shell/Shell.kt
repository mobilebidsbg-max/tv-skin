package com.dzafirov.tvskin.shell

import android.content.Context
import android.util.Log
import dadb.AdbKeyPair
import dadb.Dadb
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.File

/** Runs shell commands on the TV itself. */
interface Shell {
    /** Output of [cmd]; throws when the shell can't be reached. */
    suspend fun run(cmd: String): String
}

/**
 * The TV's own adb (network debugging, on `127.0.0.1:5555`), with this app's key. The first connection makes the TV
 * ask "Allow USB debugging?" once; with "Always allow" it never asks again. No Mac needed.
 */
class AdbShell(context: Context) : Shell {
    private val dir = File(context.filesDir, "adb")
    private val mutex = Mutex()
    private var dadb: Dadb? = null

    override suspend fun run(cmd: String): String = mutex.withLock {
        withContext(Dispatchers.IO) {
            try {
                connection().shell(cmd).allOutput
            } catch (e: Exception) {
                Log.w(TAG, "Shell failed once, reconnecting: ${e.message}")
                runCatching { dadb?.close() }
                dadb = null
                connection().shell(cmd).allOutput
            }
        }
    }

    private fun connection(): Dadb = dadb ?: Dadb.create(HOST, PORT, keyPair(), connectTimeout = 5_000, socketTimeout = 30_000).also { dadb = it }

    private fun keyPair(): AdbKeyPair {
        val private = File(dir, "adbkey")
        val public = File(dir, "adbkey.pub")
        if (!private.exists() || !public.exists()) {
            AdbKeyPair.generate(private, public)
            // The TV's "Allow USB debugging?" dialog shows this name.
            public.writeText(public.readText().replace(" unknown@unknown", " TV Skin@tv"))
        }
        return AdbKeyPair.read(private, public)
    }

    private companion object {
        const val TAG = "AdbShell"
        const val HOST = "127.0.0.1"
        const val PORT = 5555
    }
}
