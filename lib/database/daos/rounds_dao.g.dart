// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rounds_dao.dart';

// ignore_for_file: type=lint
mixin _$RoundsDaoMixin on DatabaseAccessor<AppDatabase> {
  $RoundsTable get rounds => attachedDatabase.rounds;
  $PeopleTable get people => attachedDatabase.people;
  $RoundPeopleTable get roundPeople => attachedDatabase.roundPeople;
  $SongsTable get songs => attachedDatabase.songs;
  $RoundSongsTable get roundSongs => attachedDatabase.roundSongs;
  RoundsDaoManager get managers => RoundsDaoManager(this);
}

class RoundsDaoManager {
  final _$RoundsDaoMixin _db;
  RoundsDaoManager(this._db);
  $$RoundsTableTableManager get rounds =>
      $$RoundsTableTableManager(_db.attachedDatabase, _db.rounds);
  $$PeopleTableTableManager get people =>
      $$PeopleTableTableManager(_db.attachedDatabase, _db.people);
  $$RoundPeopleTableTableManager get roundPeople =>
      $$RoundPeopleTableTableManager(_db.attachedDatabase, _db.roundPeople);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db.attachedDatabase, _db.songs);
  $$RoundSongsTableTableManager get roundSongs =>
      $$RoundSongsTableTableManager(_db.attachedDatabase, _db.roundSongs);
}
