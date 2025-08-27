import 'package:flutter/foundation.dart';

enum QuizCategory { general, science, technology, history, sports, movies }

enum QuizDifficulty { easy, medium, hard }

class QuizState extends ChangeNotifier {
  QuizCategory selectedCategory = QuizCategory.general;
  QuizDifficulty selectedDifficulty = QuizDifficulty.easy;
  String? selectedQuizType;

  void setCategory(QuizCategory category) {
    selectedCategory = category;
    selectedQuizType = null;
    notifyListeners();
  }

  void setDifficulty(QuizDifficulty difficulty) {
    selectedDifficulty = difficulty;
    notifyListeners();
  }

  void setQuizType(String? quizType) {
    selectedQuizType = quizType;
    notifyListeners();
  }
}
