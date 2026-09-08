// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'songs_dao.dart';

// ignore_for_file: type=lint
mixin _$SongsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SongsTable get songs => attachedDatabase.songs;
  SongsDaoManager get managers => SongsDaoManager(this);
}

class SongsDaoManager {
  final _$SongsDaoMixin _db;
  SongsDaoManager(this._db);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db.attachedDatabase, _db.songs);
}
