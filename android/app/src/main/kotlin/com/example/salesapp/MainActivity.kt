package com.brixta.salesapp

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.brixta.salesapp.tracking.FieldTrackingService
import com.brixta.salesapp.tracking.TrackingStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "salesapp/native_tracking"
        private const val PERMISSION_REQUEST = 5101
    }

    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> requestTrackingPermission(result)

                "start" -> {
                    if (!hasFineLocation()) {
                        result.error(
                            "permission",
                            "Location permission is required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    val employeeId = call.argument<String>("employeeId").orEmpty()
                    if (employeeId.isBlank()) {
                        result.error("employee", "Employee ID is required.", null)
                        return@setMethodCallHandler
                    }

                    ContextCompat.startForegroundService(
                        this,
                        Intent(this, FieldTrackingService::class.java).apply {
                            action = FieldTrackingService.ACTION_START
                            putExtra(
                                FieldTrackingService.EXTRA_EMPLOYEE_ID,
                                employeeId,
                            )
                        },
                    )
                    result.success(true)
                }

                "stop" -> {
                    startService(
                        Intent(this, FieldTrackingService::class.java).apply {
                            action = FieldTrackingService.ACTION_STOP
                        },
                    )
                    result.success(true)
                }

                "locateNow" -> {
                    if (FieldTrackingService.isRunning) {
                        startService(
                            Intent(this, FieldTrackingService::class.java).apply {
                                action = FieldTrackingService.ACTION_LOCATE_NOW
                            },
                        )
                        result.success(true)
                    } else {
                        val employeeId = trackingPrefs().getString(
                            FieldTrackingService.PREF_EMPLOYEE,
                            null,
                        )

                        if (employeeId.isNullOrBlank() || !hasFineLocation()) {
                            result.error(
                                "tracking",
                                "Travel meter is not available yet.",
                                null,
                            )
                            return@setMethodCallHandler
                        }

                        ContextCompat.startForegroundService(
                            this,
                            Intent(this, FieldTrackingService::class.java).apply {
                                action = FieldTrackingService.ACTION_LOCATE_NOW
                                putExtra(
                                    FieldTrackingService.EXTRA_EMPLOYEE_ID,
                                    employeeId,
                                )
                            },
                        )
                        result.success(true)
                    }
                }

                "status" -> {
                    val prefs = trackingPrefs()
                    result.success(
                        mapOf(
                            "active" to FieldTrackingService.isRunning,
                            "distanceM" to prefs.getFloat(
                                FieldTrackingService.PREF_DISTANCE,
                                0f,
                            ).toDouble(),
                            "employeeId" to prefs.getString(
                                FieldTrackingService.PREF_EMPLOYEE,
                                null,
                            ),
                            "mode" to prefs.getString(
                                FieldTrackingService.PREF_MODE,
                                FieldTrackingService.MODE_IDLE,
                            ),
                            "speedMps" to prefs.getFloat(
                                FieldTrackingService.PREF_SPEED,
                                0f,
                            ).toDouble(),
                            "lastFixAt" to prefs.getLong(
                                FieldTrackingService.PREF_LAST_FIX_AT,
                                0L,
                            ),
                            "accuracy" to prefs.getFloat(
                                FieldTrackingService.PREF_LAST_ACCURACY,
                                0f,
                            ).toDouble(),
                        ),
                    )
                }

                "currentLocation" -> {
                    if (!hasFineLocation()) {
                        result.error(
                            "permission",
                            "Location permission is required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    val manager = getSystemService(LOCATION_SERVICE) as LocationManager
                    val candidates = listOf(
                        LocationManager.GPS_PROVIDER,
                        LocationManager.NETWORK_PROVIDER,
                    ).mapNotNull { provider ->
                        try {
                            manager.getLastKnownLocation(provider)
                        } catch (_: SecurityException) {
                            null
                        }
                    }

                    val location = candidates
                        .sortedWith(
                            compareByDescending<Location> { it.time }
                                .thenBy {
                                    if (it.hasAccuracy()) it.accuracy
                                    else Float.MAX_VALUE
                                },
                        )
                        .firstOrNull()

                    if (location == null) {
                        result.error(
                            "location",
                            "No recent position is available yet.",
                            null,
                        )
                    } else {
                        result.success(
                            mapOf(
                                "latitude" to location.latitude,
                                "longitude" to location.longitude,
                                "accuracy" to if (location.hasAccuracy()) {
                                    location.accuracy.toDouble()
                                } else {
                                    0.0
                                },
                                "recordedAt" to location.time,
                            ),
                        )
                    }
                }

                "pending" -> {
                    val employeeId = activeEmployeeId()
                    if (employeeId.isNullOrBlank()) {
                        result.success("[]")
                    } else {
                        result.success(
                            TrackingStore(this).pending(
                                employeeId = employeeId,
                                limit = call.argument<Int>("limit") ?: 100,
                            ),
                        )
                    }
                }

                "todayRoute" -> {
                    val employeeId = activeEmployeeId()
                    if (employeeId.isNullOrBlank()) {
                        result.success("[]")
                    } else {
                        val workDate = trackingPrefs().getString(
                            FieldTrackingService.PREF_WORK_DATE,
                            null,
                        ) ?: localDateKey()

                        result.success(
                            TrackingStore(this).todayRoute(
                                employeeId = employeeId,
                                workDate = workDate,
                            ),
                        )
                    }
                }

                "acknowledge" -> {
                    val raw = call.argument<List<Any>>("ids").orEmpty()
                    TrackingStore(this).acknowledge(
                        raw.map { it.toString() },
                    )
                    result.success(true)
                }

                "prune" -> {
                    TrackingStore(this).clearOldSynced()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun trackingPrefs() =
        getSharedPreferences(FieldTrackingService.PREFS, MODE_PRIVATE)

    private fun activeEmployeeId(): String? =
        trackingPrefs().getString(FieldTrackingService.PREF_EMPLOYEE, null)

    private fun localDateKey(): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    private fun hasFineLocation(): Boolean =
        ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED

    private fun requestTrackingPermission(result: MethodChannel.Result) {
        val permissions = mutableListOf<String>()

        if (!hasFineLocation()) {
            permissions += Manifest.permission.ACCESS_FINE_LOCATION
            permissions += Manifest.permission.ACCESS_COARSE_LOCATION
        }

        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACTIVITY_RECOGNITION,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            permissions += Manifest.permission.ACTIVITY_RECOGNITION
        }

        if (
            Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            permissions += Manifest.permission.POST_NOTIFICATIONS
        }

        if (permissions.isEmpty()) {
            result.success(true)
            return
        }

        permissionResult = result
        requestPermissions(
            permissions.toTypedArray(),
            PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == PERMISSION_REQUEST) {
            permissionResult?.success(hasFineLocation())
            permissionResult = null
        }
    }
}
