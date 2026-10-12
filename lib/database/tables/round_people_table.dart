import 'package:drift/drift.dart';

import 'people_table.dart';
import 'rounds_table.dart';

/// Round-People junction table — which people participate in a round.
@DataClassName('RoundPersonEntry')
class RoundPeople extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get roundId => integer().references(Rounds, #id)();
  IntColumn get personId => integer().references(People, #id)();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {roundId, personId},
      ];
}
