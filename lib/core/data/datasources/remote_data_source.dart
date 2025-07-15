import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scoreease/core/data/datasources/firebase_collections.dart';
import 'package:scoreease/core/data/models/scoreboard_model.dart';
import 'package:scoreease/core/presentation/utils/global.dart';
import 'package:scoreease/core/presentation/utils/my_app_exception.dart';
import 'package:scoreease/main.dart';

class RemoteDataSource {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<ScoreboardModel?> getScoreboard({required String id}) async {
    if (id.isEmpty) {
      MyApp.debugPrint("ID is empty, returning null");
      return null;
    }

    String collection = FireStoreCollection.scoreboards.name;

    Query query = _db.collection(collection);
    query.orderBy("id");
    query = query.where("id", isEqualTo: id);

    int lastUpdated = await GlobalValues.getLastUpdatedTime(collection: collection);
    DateTime lastUpdatedTime = DateTime.fromMillisecondsSinceEpoch(lastUpdated);
    MyApp.debugPrint("getLastUpdatedTime $lastUpdated");

    QuerySnapshot<ScoreboardModel> querySnapshotServer = await query
        .withConverter(
          fromFirestore: ScoreboardModel.fromFirestore,
          toFirestore: (ScoreboardModel data, _) => data.toMap(),
        )
        .where("lastUpdated", isGreaterThan: lastUpdatedTime)
        .get(const GetOptions(source: Source.server));

    List<ScoreboardModel> resultList = [];

    if (querySnapshotServer.docs.isNotEmpty) {
      for (QueryDocumentSnapshot docSnapshot in querySnapshotServer.docs) {
        resultList.add(docSnapshot.data() as ScoreboardModel);
      }

      await GlobalValues.setLastUpdatedTime(
          collection: collection, lastUpdateTime: DateTime.now().millisecondsSinceEpoch);
    }

    MyApp.debugPrint("Server items ${resultList.toString()}");

    return resultList.isNotEmpty ? resultList.first : null;
  }

  Future<String?> saveScoreboard({required ScoreboardModel scoreboardModel}) async {
    String id = scoreboardModel.id ?? "";
    if (id.isEmpty) {
      MyApp.debugPrint("ID is empty, returning null");
      return null;
    }

    String collection = FireStoreCollection.scoreboards.name;
    // DocumentReference doc = await _db.collection(collection).add(scoreboardModel.toMap());
    await _db.collection(collection).doc(id).set(scoreboardModel.toMap());

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

    return _db.collection(collection).doc(id).snapshots().map((snapshot) => ScoreboardModel.fromMap(snapshot.data()!));
  }
}
