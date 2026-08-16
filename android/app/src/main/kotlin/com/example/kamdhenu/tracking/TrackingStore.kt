package com.example.kamdhenu.tracking

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

class TrackingStore(context: Context) :
    SQLiteOpenHelper(
        context,
        "kamdhenu_native_tracking.db",
        null,
        2
    ) {

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.setForeignKeyConstraintsEnabled(true)
    }

    override fun onCreate(db: SQLiteDatabase) {
        createSchema(db)
    }

    private fun createSchema(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS tracking_points (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                client_id TEXT UNIQUE,
                employee_id TEXT,
                work_date TEXT,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL,
                accuracy REAL NOT NULL,
                speed REAL NOT NULL,
                recorded_at INTEGER NOT NULL,
                segment_distance_m REAL NOT NULL,
                total_distance_m REAL NOT NULL,
                synced INTEGER NOT NULL DEFAULT 0
            )
            """.trimIndent()
        )

        db.execSQL(
            """
            CREATE INDEX IF NOT EXISTS idx_tracking_points_employee_day
            ON tracking_points(employee_id, work_date, recorded_at)
            """.trimIndent()
        )

        db.execSQL(
            """
            CREATE INDEX IF NOT EXISTS idx_tracking_points_sync
            ON tracking_points(employee_id, synced, recorded_at)
            """.trimIndent()
        )
    }

    override fun onUpgrade(
        db: SQLiteDatabase,
        oldVersion: Int,
        newVersion: Int,
    ) {
        if (oldVersion < 2) {
            db.execSQL("ALTER TABLE tracking_points ADD COLUMN client_id TEXT")
            db.execSQL("ALTER TABLE tracking_points ADD COLUMN employee_id TEXT")
            db.execSQL("ALTER TABLE tracking_points ADD COLUMN work_date TEXT")
            db.execSQL(
                """
                CREATE UNIQUE INDEX IF NOT EXISTS idx_tracking_points_client_id
                ON tracking_points(client_id)
                """.trimIndent()
            )
            db.execSQL(
                """
                CREATE INDEX IF NOT EXISTS idx_tracking_points_employee_day
                ON tracking_points(employee_id, work_date, recorded_at)
                """.trimIndent()
            )
            db.execSQL(
                """
                CREATE INDEX IF NOT EXISTS idx_tracking_points_sync
                ON tracking_points(employee_id, synced, recorded_at)
                """.trimIndent()
            )
        }
    }

    fun insertPoint(
        employeeId: String,
        workDate: String,
        latitude: Double,
        longitude: Double,
        accuracy: Float,
        speed: Float,
        recordedAt: Long,
        segmentDistanceM: Double,
        totalDistanceM: Double,
    ) {
        writableDatabase.insertOrThrow(
            "tracking_points",
            null,
            ContentValues().apply {
                put("client_id", UUID.randomUUID().toString())
                put("employee_id", employeeId)
                put("work_date", workDate)
                put("latitude", latitude)
                put("longitude", longitude)
                put("accuracy", accuracy.toDouble())
                put("speed", speed.toDouble())
                put("recorded_at", recordedAt)
                put("segment_distance_m", segmentDistanceM)
                put("total_distance_m", totalDistanceM)
                put("synced", 0)
            },
        )
    }

    fun pending(employeeId: String, limit: Int = 100): String {
        val rows = JSONArray()
        readableDatabase.query(
            "tracking_points",
            null,
            "employee_id = ? AND synced = 0 AND client_id IS NOT NULL",
            arrayOf(employeeId),
            null,
            null,
            "recorded_at ASC",
            limit.coerceIn(1, 250).toString(),
        ).use { cursor ->
            val clientIdIx = cursor.getColumnIndexOrThrow("client_id")
            val latIx = cursor.getColumnIndexOrThrow("latitude")
            val lngIx = cursor.getColumnIndexOrThrow("longitude")
            val accIx = cursor.getColumnIndexOrThrow("accuracy")
            val speedIx = cursor.getColumnIndexOrThrow("speed")
            val atIx = cursor.getColumnIndexOrThrow("recorded_at")
            val totalIx = cursor.getColumnIndexOrThrow("total_distance_m")

            while (cursor.moveToNext()) {
                rows.put(
                    JSONObject()
                        .put("id", cursor.getString(clientIdIx))
                        .put("latitude", cursor.getDouble(latIx))
                        .put("longitude", cursor.getDouble(lngIx))
                        .put("accuracy", cursor.getDouble(accIx))
                        .put("speed", cursor.getDouble(speedIx))
                        .put("recordedAtMs", cursor.getLong(atIx))
                        .put("totalDistanceM", cursor.getDouble(totalIx))
                )
            }
        }
        return rows.toString()
    }

    fun todayRoute(employeeId: String, workDate: String): String {
        val rows = JSONArray()
        readableDatabase.query(
            "tracking_points",
            null,
            "employee_id = ? AND work_date = ?",
            arrayOf(employeeId, workDate),
            null,
            null,
            "recorded_at ASC",
        ).use { cursor ->
            val latIx = cursor.getColumnIndexOrThrow("latitude")
            val lngIx = cursor.getColumnIndexOrThrow("longitude")
            val accIx = cursor.getColumnIndexOrThrow("accuracy")
            val speedIx = cursor.getColumnIndexOrThrow("speed")
            val atIx = cursor.getColumnIndexOrThrow("recorded_at")
            val totalIx = cursor.getColumnIndexOrThrow("total_distance_m")

            while (cursor.moveToNext()) {
                rows.put(
                    JSONObject()
                        .put("latitude", cursor.getDouble(latIx))
                        .put("longitude", cursor.getDouble(lngIx))
                        .put("accuracy", cursor.getDouble(accIx))
                        .put("speed", cursor.getDouble(speedIx))
                        .put("recordedAtMs", cursor.getLong(atIx))
                        .put("totalDistanceM", cursor.getDouble(totalIx))
                )
            }
        }
        return rows.toString()
    }

    fun acknowledge(clientIds: List<String>) {
        if (clientIds.isEmpty()) return

        val db = writableDatabase
        db.beginTransaction()
        try {
            clientIds.forEach { clientId ->
                db.update(
                    "tracking_points",
                    ContentValues().apply { put("synced", 1) },
                    "client_id = ?",
                    arrayOf(clientId),
                )
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun latestDistanceM(employeeId: String, workDate: String): Double {
        readableDatabase.rawQuery(
            """
            SELECT COALESCE(MAX(total_distance_m), 0)
            FROM tracking_points
            WHERE employee_id = ? AND work_date = ?
            """.trimIndent(),
            arrayOf(employeeId, workDate),
        ).use { cursor ->
            return if (cursor.moveToFirst()) cursor.getDouble(0) else 0.0
        }
    }

    /** Keep today's route for employee evidence. Only older synced rows go. */
    fun clearOldSynced() {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        writableDatabase.delete(
            "tracking_points",
            "synced = 1 AND work_date IS NOT NULL AND work_date < ?",
            arrayOf(today),
        )
    }
}
