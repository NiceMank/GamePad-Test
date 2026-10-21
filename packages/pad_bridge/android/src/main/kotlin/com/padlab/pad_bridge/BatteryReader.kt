package com.padlab.pad_bridge

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.InputDevice
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Lecture de la batterie d'une manette, hors du thread principal.
 *
 * Pourquoi c'est un fichier à part : `InputDevice.getBatteryState()` est un
 * appel Binder **synchrone** qui, côté système, lit un nœud sysfs. Sur une
 * manette Bluetooth, cette lecture peut bloquer plusieurs secondes. L'appeler
 * depuis le thread principal gèle l'interface (ANR) — c'est exactement ce que
 * faisait la version 0.5.0.
 *
 * Trois sources, essayées dans cet ordre :
 *
 *  1. `getBatteryState()` (Android 12+) — la voie officielle, quand la manette
 *     la renseigne. Beaucoup ne le font pas.
 *  2. Les noeuds « -battery » de /sys/class/power_supply — le noyau expose le niveau
 *     des manettes HID (`hid-AA:BB:...-battery`, `ps-controller-battery-...`).
 *     C'est ce que le pilote a reçu de la manette, donc souvent la seule
 *     valeur disponible.
 *  3. Le cache : une lecture ratée ne doit pas effacer un niveau déjà connu.
 */
class BatteryReader(private val context: Context) {

    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "padlab-battery").apply { isDaemon = true }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    /** Une seule lecture à la fois : une manette récalcitrante ne doit pas
     *  empiler les threads bloqués. */
    private val busy = AtomicBoolean(false)

    private data class Entry(
        val percent: Double?,
        val status: String,
        val source: String,
        val at: Long,
    )

    private val cache = ConcurrentHashMap<Int, Entry>()

    companion object {
        private const val FRESH_MS = 20_000L

        val UNKNOWN = mapOf<String, Any?>(
            "percent" to null,
            "status" to "unknown",
            "source" to "none",
            "reason" to "aucune source disponible",
        )
    }

    /**
     * Répond immédiatement si une valeur fraîche est en cache, sinon lit en
     * tâche de fond et rappelle [onResult].
     *
     * Le rappel est toujours invoqué sur le thread principal (exigence des
     * canaux Flutter).
     */
    fun read(deviceId: Int, onResult: (Map<String, Any?>) -> Unit) {
        val cached = cache[deviceId]
        if (cached != null && System.currentTimeMillis() - cached.at < FRESH_MS) {
            onResult(toMap(cached))
            return
        }
        if (!busy.compareAndSet(false, true)) {
            // Une lecture est déjà en cours : on répond avec ce qu'on a.
            onResult(cached?.let { toMap(it) } ?: UNKNOWN)
            return
        }
        executor.execute {
            val entry = try {
                readNow(deviceId) ?: cached?.copy(at = System.currentTimeMillis())
            } catch (_: Throwable) {
                cached
            } finally {
                busy.set(false)
            }
            if (entry != null) cache[deviceId] = entry
            val payload = entry?.let { toMap(it) } ?: UNKNOWN
            mainHandler.post { onResult(payload) }
        }
    }

    private fun toMap(e: Entry): Map<String, Any?> = mapOf(
        "percent" to e.percent,
        "status" to e.status,
        "source" to e.source,
        "reason" to null,
    )

    /** Lecture réelle. Renvoie `null` si rien n'a pu être obtenu. */
    private fun readNow(deviceId: Int): Entry? {
        val device = InputDevice.getDevice(deviceId) ?: return null

        // 1. API officielle.
        official(device)?.let { return it }

        // 2. Nœud sysfs du noyau.
        sysfs()?.let { return it }

        return null
    }

    private fun official(device: InputDevice): Entry? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
        val state = try {
            device.batteryState
        } catch (_: Throwable) {
            null
        } ?: return null
        if (!state.isPresent) return null
        val capacity = state.capacity
        if (capacity.isNaN()) return null
        val percent = (capacity * 100.0).coerceIn(0.0, 100.0)
        val status = when (state.status) {
            android.os.BatteryManager.BATTERY_STATUS_CHARGING -> "charging"
            android.os.BatteryManager.BATTERY_STATUS_DISCHARGING -> "discharging"
            android.os.BatteryManager.BATTERY_STATUS_FULL -> "full"
            android.os.BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "notCharging"
            else -> "unknown"
        }
        return Entry(percent, status, "android", System.currentTimeMillis())
    }

    /**
     * Le noyau expose une entrée `power_supply` par manette sans fil :
     * « hid-<adresse>-battery », « ps-controller-battery-<adresse> »…
     * On lit `capacity`, et `status` quand il existe.
     *
     * Plusieurs manettes peuvent être branchées : on prend le nœud modifié le
     * plus récemment, qui correspond à celle en train de communiquer. En
     * l'absence de certitude, mieux vaut une valeur plausible qu'aucune —
     * mais elle est alors annoncée comme telle.
     */
    private fun sysfs(): Entry? {
        val dir = File("/sys/class/power_supply")
        val nodes = try {
            dir.listFiles()?.filter { it.isDirectory && it.name.endsWith("-battery") }
                ?: return null
        } catch (_: Throwable) {
            return null
        }
        if (nodes.isEmpty()) return null

        val chosen = nodes.maxByOrNull { it.lastModified() } ?: return null
        val percent = readInt(File(chosen, "capacity"))?.toDouble()?.coerceIn(0.0, 100.0)
            ?: return null
        val status = when (readText(File(chosen, "status"))?.trim()?.lowercase()) {
            "charging" -> "charging"
            "discharging" -> "discharging"
            "full" -> "full"
            "not charging" -> "notCharging"
            else -> "unknown"
        }
        return Entry(percent, status, "kernel", System.currentTimeMillis())
    }

    private fun readText(file: File): String? = try {
        if (file.exists() && file.canRead()) file.readText() else null
    } catch (_: Throwable) {
        null
    }

    private fun readInt(file: File): Int? = readText(file)?.trim()?.toIntOrNull()

    /** Ce que l'application peut annoncer comme sources disponibles. */
    fun diagnostics(): Map<String, Any?> {
        val dir = File("/sys/class/power_supply")
        val nodes = try {
            dir.listFiles()?.filter { it.isDirectory && it.name.endsWith("-battery") }
                ?.map { it.name } ?: emptyList()
        } catch (_: Throwable) {
            emptyList()
        }
        return mapOf(
            "sdkInt" to Build.VERSION.SDK_INT,
            "officialApi" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S),
            "sysfsReadable" to (try {
                dir.canRead()
            } catch (_: Throwable) {
                false
            }),
            "sysfsNodes" to nodes,
            "cachedDevices" to cache.size,
        )
    }

    fun forget(deviceId: Int) {
        cache.remove(deviceId)
    }

    fun shutdown() {
        executor.shutdownNow()
        cache.clear()
    }
}
