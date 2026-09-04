import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/lazy_month_list.dart';
import 'package:garage/domain/format/month_grouping.dart';

void main() {
  testWidgets('builds only the rows in view, not the whole history', (
    tester,
  ) async {
    // Every log used to be a ListView(children: [...]) that built every row of
    // years of history on the first frame. A builder-backed list must not.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 600);
    addTearDown(tester.view.reset);

    final dates = [
      for (var i = 0; i < 400; i++)
        DateTime.utc(2026, 8, 1).subtract(Duration(days: i)),
    ];
    var built = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LazyMonthList<DateTime>(
            groups: MonthGrouping.of(dates, (d) => d),
            header: (_, group) =>
                SizedBox(height: 40, child: Text('month ${group.month.month}')),
            row: (_, date) {
              built++;
              return SizedBox(height: 40, child: Text('day ${date.day}'));
            },
          ),
        ),
      ),
    );

    expect(built, lessThan(60));
    expect(find.text('month 8'), findsOneWidget);
  });

  testWidgets('leading and trailing widgets bracket the months', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LazyMonthList<int>(
            leading: const [Text('summary')],
            trailing: const [Text('footer')],
            groups: MonthGrouping.of([1, 2], (_) => DateTime.utc(2026, 1)),
            header: (_, _) => const Text('January'),
            row: (_, n) => Text('row $n'),
          ),
        ),
      ),
    );

    expect(find.text('summary'), findsOneWidget);
    expect(find.text('January'), findsOneWidget);
    expect(find.text('row 2'), findsOneWidget);
    expect(find.text('footer'), findsOneWidget);
  });
}
