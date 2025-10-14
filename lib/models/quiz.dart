import 'package:hive/hive.dart';

part 'quiz.g.dart';

@HiveType(typeId: 0)
class Quiz extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String title;
  @HiveField(2)
  List<Question> questions;

  Quiz({required this.id, required this.title, required this.questions});
}

@HiveType(typeId: 1)
class Question extends HiveObject {
  @HiveField(0)
  String prompt;
  @HiveField(1)
  List<String> options;
  @HiveField(2)
  int correctIndex;

  Question({required this.prompt, required this.options, required this.correctIndex});
}