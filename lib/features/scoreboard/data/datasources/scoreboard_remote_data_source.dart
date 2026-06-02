import 'package:firebase_database/firebase_database.dart';
import 'package:scoreease/core/utils/firebase_collections.dart';
import 'package:scoreease/features/scoreboard/data/models/scoreboard_model.dart';
import 'package:scoreease/core/utils/my_app_exception.dart';
import 'package:scoreease/main.dart';

class ScoreboardRemoteDataSource {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  Future<ScoreboardModel?> getScoreboard({required String id}) async {
    if (id.isEmpty) {
      MyApp.debugPrint("ID is empty, returning null");
      return null;
    }

    String collection = FireStoreCollection.scoreboards.name;
    DataSnapshot snapshot = await _db.ref(collection).child(id).get();

    if (snapshot.value != null) {
      ScoreboardModel model = ScoreboardModel.fromMap(Map<String, dynamic>.from(snapshot.value as Map));
      MyApp.debugPrint("Server items [$model]");
      return model;
    }

    MyApp.debugPrint("Server items []");
    return null;
  }

  Future<String?> saveScoreboard({required ScoreboardModel scoreboardModel}) async {
    String id = scoreboardModel.id ?? "";
    if (id.isEmpty) {
      MyApp.debugPrint("ID is empty, returning null");
      return null;
    }

    String collection = FireStoreCollection.scoreboards.name;
    await _db.ref(collection).child(id).set(scoreboardModel.toMap());

    MyApp.debugPrint("Scoreboard saved with id $id");
    return id;
  }

  Stream<ScoreboardModel> listenToScoreboard(String id) {
    String collection = FireStoreCollection.scoreboards.name;
    if (id.isEmpty) {
      MyApp.debugPrint("ID is empty, returning null");
      throw const MyAppException(
        title: "Scoreboard ID is empty",
        message: "Scoreboard ID cannot be empty. Please provide a valid ID to listen to the scoreboard.",
      );
    }

    return _db.ref(collection).child(id).onValue.map((event) {
      if (event.snapshot.value == null) {
        throw const MyAppException(
          title: "Scoreboard Not Found",
          message: "The scoreboard data is empty or has been deleted.",
        );
      }
      return ScoreboardModel.fromMap(Map<String, dynamic>.from(event.snapshot.value as Map));
    });
  }
}
