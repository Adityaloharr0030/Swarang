// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person_songs_dao.dart';

// ignore_for_file: type=lint
mixin _$PersonSongsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PeopleTable get people => attachedDatabase.people;
  $SongsTable get songs => attachedDatabase.songs;
  $PersonSongsTable get personSongs => attachedDatabase.personSongs;
  PersonSongsDaoManager get managers => PersonSongsDaoManager(this);
}

class PersonSongsDaoManager {
  final _$PersonSongsDaoMixin _db;
  PersonSongsDaoManager(this._db);
  $$PeopleTableTableManager get people =>
      $$PeopleTableTableManager(_db.attachedDatabase, _db.people);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db.attachedDatabase, _db.songs);
  $$PersonSongsTableTableManager get personSongs =>
      $$PersonSongsTableTableManager(_db.attachedDatabase, _db.personSongs);
}
