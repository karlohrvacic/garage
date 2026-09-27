package cc.hrva.garage

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

/**
 * A home-screen button that opens the app straight onto a new expense — the
 * parking or toll paid on the way, logged before it is forgotten.
 *
 * A shortcut, not a display, for every reason [LogFuelWidget] gives; see
 * decision 58.
 */
class LogCostWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_log_cost)
        views.setOnClickPendingIntent(R.id.widget_log_cost_root, openExpense(context))
        appWidgetManager.updateAppWidget(appWidgetIds, views)
    }

    private fun openExpense(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse(context.getString(R.string.deep_link_log_cost))
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        return PendingIntent.getActivity(
            context,
            // Not 0: the fill-up widget's intent differs only in its data, and
            // a request code of its own keeps the two PendingIntents apart
            // however the system decides to match them.
            1,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
