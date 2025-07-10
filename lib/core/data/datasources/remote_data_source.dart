import 'dart:math';

import 'package:scoreease/core/data/models/score_board_model.dart';
import 'package:scoreease/core/presentation/utils/message_generator.dart';
import 'package:scoreease/core/presentation/utils/my_app_exception.dart';

class RemoteDataSource {
  Future<ScoreBoardModel> getScoreBoard(String id) async {
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
}
