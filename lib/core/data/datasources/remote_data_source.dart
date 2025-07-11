import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scoreease/core/data/datasources/firebase_collections.dart';
import 'package:scoreease/core/data/models/score_board_model.dart';
import 'package:scoreease/core/presentation/utils/global.dart';
import 'package:scoreease/core/presentation/utils/message_generator.dart';
import 'package:scoreease/core/presentation/utils/my_app_exception.dart';
import 'package:scoreease/main.dart';

class RemoteDataSource {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<ScoreBoardModel> test(String id) async {
    // Simulated API call or data retrieval logic
    // Replace this with your actual API integration logic

    // Simulating a response from a remote API
    await Future.delayed(
        const Duration(seconds: 2)); // Simulating delay for API call

    // Mock response data (replace with your actual API response parsing)
    final Map<String, dynamic> scoreBoardJson = {
      "id": "Mohanlal vs Mammootti",
      "title": "Mohanlal vs Mammootti",
      "description": "Mohanlal vs Mammootti",
      "createdAt": "2025-07-08T16:30:00Z",
      "playerCount": 2,
      "access": {"readPassword": "123", "writePassword": "12345"}
    };

    // throw auth exception randomly for testing purpose
    if (Random().nextBool()) {
      throw MyAppException(
          title: MessageGenerator.getMessage("Auth Error"),
          message: MessageGenerator.getMessage("Invalid credentials"));
    }

    // Convert JSON data to UserModel instance
    return ScoreBoardModel.fromMap(scoreBoardJson);
  }

  Future<ScoreBoardModel?> getScoreBoard({required String id}) async {
    if (id.isEmpty) {
      MyApp.debugPrint("ID is empty, returning null");
      return null;
    }

    String collection = FireStoreCollection.scoreboards.name;

    Query query = _db.collection(collection);
    query.orderBy("id");
    query = query.where("id", isEqualTo: id);

    int lastUpdated =
        await GlobalValues.getLastUpdatedTime(collection: collection);
    MyApp.debugPrint("getLastUpdatedTime $lastUpdated");

    QuerySnapshot<ScoreBoardModel> querySnapshotServer = await query
        .withConverter(
          fromFirestore: ScoreBoardModel.fromFirestore,
          toFirestore: (ScoreBoardModel data, _) => data.toMap(),
        )
        .where("lastUpdated", isGreaterThan: lastUpdated)
        .get(const GetOptions(source: Source.server));

    List<ScoreBoardModel> resultList = [];

    if (querySnapshotServer.docs.isNotEmpty) {
      for (QueryDocumentSnapshot docSnapshot in querySnapshotServer.docs) {
        resultList.add(docSnapshot.data() as ScoreBoardModel);
      }

      await GlobalValues.setLastUpdatedTime(
          collection: collection,
          lastUpdateTime: DateTime.now().millisecondsSinceEpoch);
    }

    MyApp.debugPrint("Server items ${resultList.toString()}");

    return resultList.isNotEmpty ? resultList.first : null;
  }
}
