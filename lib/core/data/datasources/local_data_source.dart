import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scoreease/core/data/datasources/firebase_collections.dart';
import 'package:scoreease/core/data/models/scoreboard_model.dart';
import 'package:scoreease/main.dart';

class LocalDataSource {
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

    QuerySnapshot<ScoreboardModel> querySnapshotServer = await query
        .withConverter(
          fromFirestore: ScoreboardModel.fromFirestore,
          toFirestore: (ScoreboardModel data, _) => data.toMap(),
        )
        .get(const GetOptions(source: Source.cache));

    List<ScoreboardModel> resultList = [];

    if (querySnapshotServer.docs.isNotEmpty) {
      for (QueryDocumentSnapshot docSnapshot in querySnapshotServer.docs) {
        resultList.add(docSnapshot.data() as ScoreboardModel);
      }
    }

    MyApp.debugPrint("Cached items ${resultList.toString()}");

    return resultList.isNotEmpty ? resultList.first : null;
  }
}
