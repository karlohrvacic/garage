package cc.hrva.garage

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

/**
 * A home-screen button that opens the app straight onto a new fill-up.
 *
 * It is a shortcut, not a display. A widget runs inside the launcher's
 * process, where there is no Flutter engine, no signed-in session and no
 * household — so it can show a label and an icon and nothing else. Anything
 * with a number on it would need the app to keep a copy of that number
 * somewhere this process can read, refreshed on a schedule, and would show a
 * stale figure or a blank tile whenever that failed. See decision 58.
 *
 * The URL is the one resource the app-icon shortcut also spends, so the two
 * entry points cannot drift onto different routes.
 */
class LogFuelWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_log_fuel)
        views.setOnClickPendingIntent(R.id.widget_log_fuel_root, openFillUp(context))
        appWidgetManager.updateAppWidget(appWidgetIds, views)
    }

    private fun openFillUp(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse(context.getString(R.string.deep_link_log_fuel))
            // NEW_TASK because a widget tap comes from the launcher's process
            // and has no task of its own; CLEAR_TOP so an app already open
            // receives this as a new intent rather than stacking a second
            // copy of the activity behind the one on screen.
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            // Mutability has been mandatory since API 31, and immutable is the
            // right half: nothing may rewrite where this tap goes.
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
