package com.example.salesapp.tracking

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.TriggerEvent
import android.hardware.TriggerEventListener
import android.os.SystemClock

class MotionGate(
    context: Context,
    private val onMotionDetected: () -> Unit,
) : SensorEventListener {

    private val sensorManager =
        context.getSystemService(
            Context.SENSOR_SERVICE
        ) as SensorManager

    /*
     * Step counter:
     *
     * Extremely cheap movement signal on phones
     * that expose the hardware sensor.
     *
     * We are NOT using steps to calculate TA/DA
     * distance.
     *
     * It only helps answer:
     *
     * "Does this phone appear to be moving?"
     */
    private val stepCounter =
        sensorManager.getDefaultSensor(
            Sensor.TYPE_STEP_COUNTER
        )

    /*
     * Significant motion:
     *
     * One-shot low-power Android sensor.
     *
     * Useful for waking our tracking engine from
     * its low-power / idle state.
     */
    private val significantMotion =
        sensorManager.getDefaultSensor(
            Sensor.TYPE_SIGNIFICANT_MOTION
        )

    private var lastStepValue:
        Float? = null

    private var lastMotionAtElapsedMs:
        Long = 0L

    private val significantMotionListener =
        object : TriggerEventListener() {

            override fun onTrigger(
                event: TriggerEvent?
            ) {
                markMotion()

                /*
                 * Significant-motion sensors are
                 * one-shot trigger sensors.
                 *
                 * Re-arm after every trigger.
                 */
                armSignificantMotion()
            }
        }

    fun start() {
        /*
         * STEP_COUNTER requires
         * ACTIVITY_RECOGNITION on newer Android.
         *
         * If permission is missing, tracking still
         * works — we simply lose this optional
         * movement hint.
         */
        try {
            if (stepCounter != null) {
                sensorManager.registerListener(
                    this,
                    stepCounter,
                    SensorManager.SENSOR_DELAY_NORMAL,
                )
            }
        } catch (_: SecurityException) {
            // Optional sensor only.
        }

        armSignificantMotion()
    }

    fun stop() {
        sensorManager.unregisterListener(this)

        try {
            if (significantMotion != null) {
                sensorManager.cancelTriggerSensor(
                    significantMotionListener,
                    significantMotion,
                )
            }
        } catch (_: Exception) {
            // Nothing else required.
        }
    }

    /**
     * Returns true if the phone has shown
     * meaningful movement recently.
     *
     * This drives the smart meter's:
     *
     * MOVING
     *     ↕
     * IDLE
     *
     * sampling modes.
     */
    fun movingRecently(
        windowMs: Long = 120_000L,
    ): Boolean {

        if (
            lastMotionAtElapsedMs == 0L
        ) {
            return false
        }

        return (
            SystemClock.elapsedRealtime() -
                lastMotionAtElapsedMs
            ) <= windowMs
    }

    /**
     * Public because FieldTrackingService may also
     * detect movement from native location speed.
     */
    fun markMotion() {
        lastMotionAtElapsedMs =
            SystemClock.elapsedRealtime()

        onMotionDetected()
    }

    private fun armSignificantMotion() {
        try {
            if (significantMotion != null) {
                sensorManager.requestTriggerSensor(
                    significantMotionListener,
                    significantMotion,
                )
            }
        } catch (_: Exception) {
            /*
             * Not all phones expose this sensor.
             *
             * That's fine — the meter still has
             * speed + location + step-counter
             * signals available.
             */
        }
    }

    override fun onSensorChanged(
        event: SensorEvent?
    ) {
        if (
            event == null ||
            event.sensor.type !=
                Sensor.TYPE_STEP_COUNTER ||
            event.values.isEmpty()
        ) {
            return
        }

        val value =
            event.values[0]

        val previous =
            lastStepValue

        /*
         * TYPE_STEP_COUNTER is cumulative since
         * device boot.
         *
         * We don't care about the actual number
         * of steps.
         *
         * Any increase simply tells us:
         *
         *     PHONE MOVED
         */
        if (
            previous != null &&
            value > previous
        ) {
            markMotion()
        }

        lastStepValue =
            value
    }

    override fun onAccuracyChanged(
        sensor: Sensor?,
        accuracy: Int,
    ) = Unit
}