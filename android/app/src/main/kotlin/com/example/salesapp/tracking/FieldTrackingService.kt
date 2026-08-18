package com.brixta.salesapp.tracking

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.abs
import kotlin.math.max

class FieldTrackingService :
    Service(),
    LocationListener {

    companion object {

        @Volatile
        var isRunning:
            Boolean = false

        private const val TAG =
            "SalesappTravelMeter"

        const val ACTION_START =
            "com.brixta.salesapp.tracking.START"

        const val ACTION_STOP =
            "com.brixta.salesapp.tracking.STOP"

        const val ACTION_LOCATE_NOW =
            "com.brixta.salesapp.tracking.LOCATE_NOW"

        const val EXTRA_EMPLOYEE_ID =
            "employeeId"

        const val PREFS =
            "salesapp_tracking_state"

        const val PREF_ACTIVE =
            "active"

        const val PREF_EMPLOYEE =
            "employee"

        const val PREF_WORK_DATE =
            "workDate"

        const val PREF_DISTANCE =
            "distance"

        const val PREF_MODE =
            "mode"

        const val PREF_SPEED =
            "speed"

        const val PREF_LAST_FIX_AT =
            "lastFixAt"

        const val PREF_LAST_ACCURACY =
            "lastAccuracy"

        const val CHANNEL_ID =
            "field_tracking"

        const val NOTIFICATION_ID =
            4107

        const val MODE_MOVING =
            "moving"

        const val MODE_IDLE =
            "idle"
    }

    private lateinit var locationManager:
        LocationManager

    private lateinit var store:
        TrackingStore

    private lateinit var motionGate:
        MotionGate

    private val handler =
        Handler(
            Looper.getMainLooper(),
        )

    private var lastAccepted:
        Location? = null

    private var lastAcceptedSpeedMps =
        0.0

    private var totalDistanceM =
        0.0

    private var currentMode =
        MODE_MOVING

    private var started =
        false

    private var currentEmployeeId =
        ""

    private var currentWorkDate =
        ""

    private val modeCheck =
        object : Runnable {

            override fun run() {
                evaluateMode()

                handler.postDelayed(
                    this,
                    60_000L,
                )
            }
        }

    override fun onCreate() {
        super.onCreate()

        locationManager =
            getSystemService(
                Context.LOCATION_SERVICE,
            ) as LocationManager

        store =
            TrackingStore(this)

        motionGate =
            MotionGate(this) {

                if (
                    started &&
                    currentMode != MODE_MOVING
                ) {
                    Log.d(
                        TAG,
                        "Motion detected -> MOVING mode",
                    )

                    setSamplingMode(
                        MODE_MOVING,
                    )
                }
            }

        createNotificationChannel()
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {

        /*
         * START_STICKY process recreation.
         */
        if (intent == null) {

            val prefs =
                getSharedPreferences(
                    PREFS,
                    MODE_PRIVATE,
                )

            val desiredActive =
                prefs.getBoolean(
                    PREF_ACTIVE,
                    false,
                )

            val employeeId =
                prefs.getString(
                    PREF_EMPLOYEE,
                    null,
                )

            if (
                desiredActive &&
                !employeeId.isNullOrBlank()
            ) {
                startMeter(
                    employeeId,
                )
            }

            return START_STICKY
        }

        when (intent.action) {

            ACTION_STOP -> {
                stopMeter()

                return START_NOT_STICKY
            }

            ACTION_START -> {
                val employeeId =
                    intent
                        .getStringExtra(
                            EXTRA_EMPLOYEE_ID,
                        )
                        .orEmpty()

                if (
                    employeeId.isNotBlank()
                ) {
                    startMeter(
                        employeeId,
                    )
                }
            }

            ACTION_LOCATE_NOW -> {
                /*
                 * Locate-now also acts as a repair path.
                 *
                 * If Android destroyed the meter process,
                 * recover the desired employee and restart
                 * the foreground meter before requesting
                 * the immediate fix.
                 */
                if (!started) {

                    val suppliedEmployee =
                        intent.getStringExtra(
                            EXTRA_EMPLOYEE_ID,
                        )

                    val storedEmployee =
                        getSharedPreferences(
                            PREFS,
                            MODE_PRIVATE,
                        ).getString(
                            PREF_EMPLOYEE,
                            null,
                        )

                    val employeeId =
                        suppliedEmployee
                            ?.takeIf {
                                it.isNotBlank()
                            }
                            ?: storedEmployee

                    if (
                        !employeeId.isNullOrBlank()
                    ) {
                        startMeter(
                            employeeId,
                        )
                    }
                }

                if (started) {
                    requestImmediateFix()
                }
            }
        }

        return START_STICKY
    }

    private fun startMeter(
        employeeId: String,
    ) {
        if (!hasFineLocation()) {

            Log.w(
                TAG,
                "Cannot start: fine location not granted",
            )

            isRunning =
                false

            stopSelf()

            return
        }

        val today =
            dayKey(
                System.currentTimeMillis(),
            )

        val prefs =
            getSharedPreferences(
                PREFS,
                MODE_PRIVATE,
            )

        val sameEmployee =
            prefs.getString(
                PREF_EMPLOYEE,
                null,
            ) == employeeId

        val sameDay =
            prefs.getString(
                PREF_WORK_DATE,
                null,
            ) == today

        currentEmployeeId =
            employeeId

        currentWorkDate =
            today

        totalDistanceM =
            if (
                sameEmployee &&
                sameDay
            ) {
                max(
                    store.latestDistanceM(
                        employeeId,
                        today,
                    ),

                    prefs.getFloat(
                        PREF_DISTANCE,
                        0f,
                    ).toDouble(),
                )
            } else {
                store.latestDistanceM(
                    employeeId,
                    today,
                )
            }

        if (
            !sameEmployee ||
            !sameDay
        ) {
            lastAccepted =
                null

            lastAcceptedSpeedMps =
                0.0
        }

        if (!started) {

            /*
             * Android requires startForeground()
             * promptly after startForegroundService().
             */
            startForeground(
                NOTIFICATION_ID,
                buildNotification(
                    totalDistanceM,
                ),
            )

            started =
                true

            isRunning =
                true

            motionGate.start()

            handler.removeCallbacks(
                modeCheck,
            )

            handler.post(
                modeCheck,
            )
        } else {
            /*
             * Service already exists.
             *
             * ACTION_START is idempotent.
             */
            isRunning =
                true
        }

        prefs
            .edit()
            .putBoolean(
                PREF_ACTIVE,
                true,
            )
            .putString(
                PREF_EMPLOYEE,
                employeeId,
            )
            .putString(
                PREF_WORK_DATE,
                today,
            )
            .putFloat(
                PREF_DISTANCE,
                totalDistanceM.toFloat(),
            )
            .apply()

        /*
         * Always begin/resume in responsive mode.
         *
         * MotionGate can later reduce sampling.
         */
        setSamplingMode(
            MODE_MOVING,
        )

        Log.d(
            TAG,
            "Travel meter started " +
                "employee=$employeeId " +
                "day=$today " +
                "distance=$totalDistanceM",
        )
    }

    private fun setSamplingMode(
        mode: String,
    ) {
        if (!started) {
            return
        }

        currentMode =
            mode

        getSharedPreferences(
            PREFS,
            MODE_PRIVATE,
        )
            .edit()
            .putString(
                PREF_MODE,
                currentMode,
            )
            .apply()

        try {

            locationManager.removeUpdates(
                this,
            )

            if (
                mode ==
                MODE_MOVING
            ) {

                /*
                 * Responsive movement mode.
                 */
                if (
                    locationManager.isProviderEnabled(
                        LocationManager.GPS_PROVIDER,
                    )
                ) {
                    locationManager.requestLocationUpdates(
                        LocationManager.GPS_PROVIDER,
                        5_000L,
                        5f,
                        this,
                    )
                }

                if (
                    locationManager.isProviderEnabled(
                        LocationManager.NETWORK_PROVIDER,
                    )
                ) {
                    locationManager.requestLocationUpdates(
                        LocationManager.NETWORK_PROVIDER,
                        10_000L,
                        10f,
                        this,
                    )
                }

            } else {

                /*
                 * Low-power stationary mode.
                 */
                if (
                    locationManager.isProviderEnabled(
                        LocationManager.NETWORK_PROVIDER,
                    )
                ) {
                    locationManager.requestLocationUpdates(
                        LocationManager.NETWORK_PROVIDER,
                        90_000L,
                        60f,
                        this,
                    )
                }

                try {
                    locationManager.requestLocationUpdates(
                        LocationManager.PASSIVE_PROVIDER,
                        90_000L,
                        50f,
                        this,
                    )

                } catch (_: Exception) {
                }
            }

            Log.d(
                TAG,
                "Sampling mode=$mode",
            )

        } catch (
            error: SecurityException
        ) {

            Log.e(
                TAG,
                "Location permission disappeared",
                error,
            )

            stopMeter()
        }
    }

    private fun evaluateMode() {
        if (!started) {
            return
        }

        val recentlyMoving =
            motionGate.movingRecently() ||
                lastAcceptedSpeedMps >=
                1.2

        if (recentlyMoving) {

            if (
                currentMode !=
                MODE_MOVING
            ) {
                setSamplingMode(
                    MODE_MOVING,
                )
            }

        } else {

            if (
                currentMode !=
                MODE_IDLE
            ) {
                Log.d(
                    TAG,
                    "No recent movement -> IDLE mode",
                )

                setSamplingMode(
                    MODE_IDLE,
                )
            }
        }
    }

    override fun onLocationChanged(
        location: Location,
    ) {
        if (!started) {
            return
        }

        if (
            currentEmployeeId.isBlank()
        ) {
            return
        }

        /*
         * Simulated/injected positions sometimes do
         * not provide an accuracy value.
         *
         * Unknown accuracy is not automatically bad.
         */
        if (
            location.hasAccuracy() &&
            location.accuracy > 80f
        ) {
            Log.d(
                TAG,
                "Rejected poor accuracy=${location.accuracy}",
            )

            return
        }

        Log.d(
            TAG,
            "FIX " +
                "provider=${location.provider} " +
                "lat=${location.latitude} " +
                "lng=${location.longitude} " +
                "accuracy=${
                    if (location.hasAccuracy()) {
                        location.accuracy
                    } else {
                        "unknown"
                    }
                } " +
                "speed=${
                    if (location.hasSpeed()) {
                        location.speed
                    } else {
                        "unknown"
                    }
                }",
        )

        val locationDay =
            dayKey(
                location.time,
            )

        /*
         * Midnight reset.
         */
        if (
            locationDay !=
            currentWorkDate
        ) {
            currentWorkDate =
                locationDay

            totalDistanceM =
                store.latestDistanceM(
                    currentEmployeeId,
                    currentWorkDate,
                )

            lastAccepted =
                null

            lastAcceptedSpeedMps =
                0.0

            getSharedPreferences(
                PREFS,
                MODE_PRIVATE,
            )
                .edit()
                .putString(
                    PREF_WORK_DATE,
                    currentWorkDate,
                )
                .putFloat(
                    PREF_DISTANCE,
                    totalDistanceM.toFloat(),
                )
                .apply()
        }

        val previous =
            lastAccepted

        var segmentDistanceM =
            0.0

        if (
            previous != null
        ) {

            val elapsedSeconds =
                (
                    location.elapsedRealtimeNanos -
                        previous.elapsedRealtimeNanos
                    ) /
                    1_000_000_000.0

            val wallSeconds =
                (
                    location.time -
                        previous.time
                    ) /
                    1000.0

            val seconds =
                if (
                    elapsedSeconds > 0
                ) {
                    elapsedSeconds
                } else {
                    wallSeconds
                }

            if (
                seconds <= 0
            ) {
                Log.d(
                    TAG,
                    "Rejected non-positive elapsed time",
                )

                return
            }

            /*
             * Primary physical route segment.
             */
            val pathDistanceM =
                previous
                    .distanceTo(
                        location,
                    )
                    .toDouble()

            /*
             * Native phone speed if provided.
             *
             * Otherwise derive from distance/time.
             */
            val currentSpeedMps =
                if (
                    location.hasSpeed() &&
                    location.speed >= 0f
                ) {
                    location
                        .speed
                        .toDouble()
                } else {
                    pathDistanceM /
                        seconds
                }

            val previousSpeedMps =
                if (
                    previous.hasSpeed() &&
                    previous.speed >= 0f
                ) {
                    previous
                        .speed
                        .toDouble()
                } else {
                    lastAcceptedSpeedMps
                }

            /*
             * speed × time cross-check.
             *
             * Trapezoidal integration:
             *
             * ((v1 + v2) / 2) × dt
             */
            val speedIntegratedDistanceM =
                (
                    previousSpeedMps +
                        currentSpeedMps
                    ) /
                    2.0 *
                    seconds

            val impliedPathSpeedMps =
                pathDistanceM /
                    seconds

            /*
             * Reject impossible GPS jumps.
             *
             * 70 m/s ≈ 252 km/h.
             */
            if (
                impliedPathSpeedMps >
                70.0
            ) {
                Log.d(
                    TAG,
                    "Rejected GPS jump " +
                        "path=$pathDistanceM " +
                        "seconds=$seconds",
                )

                return
            }

            /*
             * Ignore tiny positioning jitter.
             *
             * Still use the new fix as the next
             * reference point.
             */
            if (
                pathDistanceM < 4.0 &&
                speedIntegratedDistanceM <
                4.0
            ) {
                lastAcceptedSpeedMps =
                    currentSpeedMps

                lastAccepted =
                    location

                return
            }

            /*
             * Position movement itself is a valid
             * motion signal.
             *
             * This is especially important for the
             * Android emulator route simulator.
             */
            if (
                pathDistanceM >= 4.0 ||
                currentSpeedMps >= 0.8
            ) {
                motionGate.markMotion()
            }

            val agreementToleranceM =
                max(
                    18.0,
                    pathDistanceM *
                        0.55,
                )

            /*
             * GPS path stays primary.
             *
             * speed × time stabilises it only when
             * both measurements broadly agree.
             */
            segmentDistanceM =
                if (
                    speedIntegratedDistanceM >
                    0.0 &&
                    abs(
                        speedIntegratedDistanceM -
                            pathDistanceM,
                    ) <=
                    agreementToleranceM
                ) {

                    (
                        pathDistanceM *
                            0.70
                        ) +
                        (
                            speedIntegratedDistanceM *
                                0.30
                            )

                } else {
                    pathDistanceM
                }

            lastAcceptedSpeedMps =
                currentSpeedMps

            Log.d(
                TAG,
                "ACCEPTED " +
                    "segment=${segmentDistanceM}m " +
                    "path=${pathDistanceM}m " +
                    "speedDistance=${speedIntegratedDistanceM}m " +
                    "speed=${currentSpeedMps * 3.6}km/h",
            )

        } else {

            /*
             * First fix establishes the starting point.
             *
             * It correctly adds zero distance.
             */
            lastAcceptedSpeedMps =
                if (
                    location.hasSpeed()
                ) {
                    max(
                        0.0,
                        location.speed.toDouble(),
                    )
                } else {
                    0.0
                }

            Log.d(
                TAG,
                "First fix established",
            )
        }

        totalDistanceM +=
            segmentDistanceM

        lastAccepted =
            location

        val storedAccuracy =
            if (
                location.hasAccuracy()
            ) {
                location.accuracy
            } else {
                0f
            }

        /*
         * OFFLINE FIRST:
         *
         * persistent native SQLite comes before
         * any backend/network operation.
         */
        store.insertPoint(
            employeeId =
                currentEmployeeId,

            workDate =
                currentWorkDate,

            latitude =
                location.latitude,

            longitude =
                location.longitude,

            accuracy =
                storedAccuracy,

            speed =
                lastAcceptedSpeedMps.toFloat(),

            recordedAt =
                location.time,

            segmentDistanceM =
                segmentDistanceM,

            totalDistanceM =
                totalDistanceM,
        )

        getSharedPreferences(
            PREFS,
            MODE_PRIVATE,
        )
            .edit()
            .putFloat(
                PREF_DISTANCE,
                totalDistanceM.toFloat(),
            )
            .putFloat(
                PREF_SPEED,
                lastAcceptedSpeedMps.toFloat(),
            )
            .putLong(
                PREF_LAST_FIX_AT,
                location.time,
            )
            .putFloat(
                PREF_LAST_ACCURACY,
                storedAccuracy,
            )
            .putString(
                PREF_MODE,
                currentMode,
            )
            .putString(
                PREF_WORK_DATE,
                currentWorkDate,
            )
            .apply()

        val manager =
            getSystemService(
                Context.NOTIFICATION_SERVICE,
            ) as NotificationManager

        manager.notify(
            NOTIFICATION_ID,
            buildNotification(
                totalDistanceM,
            ),
        )

        Log.d(
            TAG,
            "TOTAL=${totalDistanceM / 1000.0} km",
        )
    }

    private fun requestImmediateFix() {
        if (!hasFineLocation()) {
            return
        }

        try {

            val provider =
                when {

                    locationManager.isProviderEnabled(
                        LocationManager.GPS_PROVIDER,
                    ) -> {
                        LocationManager.GPS_PROVIDER
                    }

                    locationManager.isProviderEnabled(
                        LocationManager.NETWORK_PROVIDER,
                    ) -> {
                        LocationManager.NETWORK_PROVIDER
                    }

                    else -> {
                        return
                    }
                }

            Log.d(
                TAG,
                "Immediate location fix requested",
            )

            locationManager.requestSingleUpdate(
                provider,
                this,
                Looper.getMainLooper(),
            )

        } catch (
            error: SecurityException
        ) {
            Log.e(
                TAG,
                "Immediate location request failed",
                error,
            )
        }
    }

    private fun stopMeter() {
        started =
            false

        isRunning =
            false

        try {
            locationManager.removeUpdates(
                this,
            )
        } catch (_: Exception) {
        }

        motionGate.stop()

        handler.removeCallbacks(
            modeCheck,
        )

        getSharedPreferences(
            PREFS,
            MODE_PRIVATE,
        )
            .edit()
            .putBoolean(
                PREF_ACTIVE,
                false,
            )
            .putFloat(
                PREF_DISTANCE,
                totalDistanceM.toFloat(),
            )
            .putString(
                PREF_MODE,
                MODE_IDLE,
            )
            .apply()

        stopForeground(
            STOP_FOREGROUND_REMOVE,
        )

        stopSelf()
    }

    private fun hasFineLocation():
        Boolean =
        ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) ==
            PackageManager.PERMISSION_GRANTED

    private fun dayKey(
        timestampMs: Long,
    ): String =
        SimpleDateFormat(
            "yyyy-MM-dd",
            Locale.US,
        ).format(
            Date(
                timestampMs,
            ),
        )

    private fun createNotificationChannel() {
        if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.O
        ) {
            val manager =
                getSystemService(
                    Context.NOTIFICATION_SERVICE,
                ) as NotificationManager

            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Travel meter",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description =
                        "Keeps automatic work travel capture reliable."
                },
            )
        }
    }

    private fun buildNotification(
        distanceM: Double,
    ) =
        NotificationCompat
            .Builder(
                this,
                CHANNEL_ID,
            )
            .setSmallIcon(
                android.R.drawable.ic_menu_compass,
            )
            .setContentTitle(
                "Travel meter active",
            )
            .setContentText(
                String.format(
                    Locale.US,
                    "%.1f km captured",
                    distanceM /
                        1000.0,
                ),
            )
            .setOngoing(
                true,
            )
            .setOnlyAlertOnce(
                true,
            )
            .setPriority(
                NotificationCompat.PRIORITY_LOW,
            )
            .build()

    override fun onProviderEnabled(
        provider: String,
    ) = Unit

    override fun onProviderDisabled(
        provider: String,
    ) = Unit

    override fun onBind(
        intent: Intent?,
    ): IBinder? =
        null

    override fun onDestroy() {
        started =
            false

        isRunning =
            false

        try {
            locationManager.removeUpdates(
                this,
            )
        } catch (_: Exception) {
        }

        try {
            motionGate.stop()
        } catch (_: Exception) {
        }

        handler.removeCallbacks(
            modeCheck,
        )

        Log.d(
            TAG,
            "Travel meter destroyed",
        )

        super.onDestroy()
    }
}