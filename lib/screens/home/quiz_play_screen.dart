import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../state/quiz_state.dart';
import 'package:hive/hive.dart';

class QuizPlayScreen extends StatefulWidget {
  static const String route = '/quiz_play';
  const QuizPlayScreen({super.key});

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedOptionIndex;
  late Future<_QuizData> _quizFuture;
  Timer? _timer;
  int _timeLeft = 10; // 10 seconds per question
  int _questionsAttempted = 0;
  bool _isTimedQuiz = false;

  // Add this map to store selected answers for each question
  final Map<int, int?> _selectedAnswers = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['quizId'] is String) {
      final quizId = args['quizId'] as String;
      _quizFuture = _loadQuiz(quizId);

      // Check if this is a timed quiz
      final quizState = Provider.of<QuizState>(context, listen: false);
      _isTimedQuiz = quizState.selectedQuizType == 'timed';
    } else {
      _quizFuture = Future.error('Missing quizId');
    }
  }

  Future<_QuizData> _loadQuiz(String quizId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(quizId)
          .get();
      if (!snap.exists) {
        throw Exception('Quiz not found');
      }
      final data = snap.data() as Map<String, dynamic>;
      final title = (data['title'] ?? '') as String;
      final rawQuestions = (data['questions'] ?? []) as List<dynamic>;
      final questions = <_Question>[];
      for (final q in rawQuestions) {
        if (q is Map<String, dynamic>) {
          final prompt = (q['prompt'] ?? '') as String;
          final correct = (q['correct'] ?? '') as String;
          final incorrect = (q['incorrect'] ?? []) as List<dynamic>;
          final allOptions = <String>[correct, ...incorrect.cast<String>()];
          allOptions.shuffle();
          final correctIndex = allOptions.indexOf(correct);
          questions.add(_Question(
              prompt: prompt, options: allOptions, correctIndex: correctIndex));
        }
      }
      if (questions.isEmpty) {
        throw Exception('This quiz has no questions yet');
      }
      return _QuizData(title: title, questions: questions);
    } catch (e) {
      // If offline or error, try to load from local storage
      var box = await Hive.openBox('quick10_questions');
      final rawQuestions =
          box.get(quizId, defaultValue: [])?.cast<Map<String, dynamic>>() ?? [];
      final questions = <_Question>[];
      for (final q in rawQuestions) {
        final prompt = (q['prompt'] ?? '') as String;
        final options = (q['options'] ?? []) as List<dynamic>;
        final correctIndex = (q['correctIndex'] ?? 0) as int;
        questions.add(_Question(
            prompt: prompt,
            options: options.cast<String>(),
            correctIndex: correctIndex));
      }
      return _QuizData(title: 'Offline Quiz', questions: questions);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(_QuizData quiz) {
    // Only start timer for timed quizzes
    if (!_isTimedQuiz) return;

    _timer?.cancel();
    _timeLeft = 10;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        // Time's up - move to next question
        _questionsAttempted++;
        if (_selectedOptionIndex != null) {
          _submitAnswer(quiz);
        } else {
          // No answer selected, move to next
          if (_currentIndex < quiz.questions.length - 1) {
            setState(() {
              _currentIndex++;
              _selectedOptionIndex = null;
              _timeLeft = 10;
            });
          } else {
            _timer?.cancel();
            _showResult(quiz);
          }
        }
      }
    });
  }

  void _submitAnswer(_QuizData quiz) {
    final question = quiz.questions[_currentIndex];
    if (_selectedOptionIndex != null &&
        _selectedOptionIndex == question.correctIndex) {
      _score += 1;
    }
    _questionsAttempted++;

    // Store the selected answer for this question
    _selectedAnswers[_currentIndex] = _selectedOptionIndex;

    if (_currentIndex < quiz.questions.length - 1) {
      setState(() {
        _currentIndex += 1;
        // Restore selected answer for next question if exists
        _selectedOptionIndex = _selectedAnswers[_currentIndex];
        _timeLeft = 10; // Reset timer for next question
      });
    } else {
      _timer?.cancel();
      _showResult(quiz);
    }
  }

  Future<void> _markQuizCompleted(String quizId) async {
    var box = await Hive.openBox('completed_quizzes');
    final ids = Set<String>.from(box.get('ids', defaultValue: <String>[]));
    ids.add(quizId);
    await box.put('ids', ids.toList());
  }

  void _showResult(_QuizData quiz) async {
    final total = quiz.questions.length;
    final notAttempted = total - _questionsAttempted;
    final args = ModalRoute.of(context)?.settings.arguments;
    final quizId = (args is Map && args['quizId'] is String)
        ? args['quizId'] as String
        : null;

    // Only mark as completed if user passes (>= 6 correct answers)
    if (quizId != null && _score >= 6) {
      await _markQuizCompleted(quizId);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Quiz Completed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Final Score: $_score / $total'),
              const SizedBox(height: 8),
              Text('Questions Attempted: $_questionsAttempted'),
              Text('Questions Not Attempted: $notAttempted'),
              if (_score >= 6)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Congratulations! You passed and unlocked the next quiz.',
                    style: TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'You need at least 6 correct answers to unlock the next quiz.',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_QuizData>(
      future: _quizFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Quiz')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load quiz: ${snapshot.error}'),
              ),
            ),
          );
        }

        final quiz = snapshot.data!;
        final question = quiz.questions[_currentIndex];
        final progress = '${_currentIndex + 1} / ${quiz.questions.length}';

        // Start timer when quiz loads
        if (_currentIndex == 0 && _timer == null) {
          _startTimer(quiz);
        }

        return Scaffold(
          appBar: AppBar(title: Text(quiz.title)),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(progress,
                        style: Theme.of(context).textTheme.labelLarge),
                    // Timer display - only show for timed quizzes
                    if (_isTimedQuiz)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _timeLeft < 4 ? Colors.red : Colors.blue,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '$_timeLeft s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  question.prompt,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ...List.generate(question.options.length, (i) {
                  return Card(
                    child: RadioListTile<int>(
                      value: i,
                      groupValue: _selectedOptionIndex,
                      onChanged: (v) =>
                          setState(() => _selectedOptionIndex = v),
                      title: Text(question.options[i]),
                    ),
                  );
                }),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _currentIndex == 0
                            ? null
                            : () {
                                setState(() {
                                  _currentIndex -= 1;
                                  // Restore selected answer for previous question if exists
                                  _selectedOptionIndex =
                                      _selectedAnswers[_currentIndex];
                                  if (_isTimedQuiz) {
                                    _timeLeft = 10;
                                    _timer?.cancel();
                                    _startTimer(quiz);
                                  }
                                });
                              },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Previous'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedOptionIndex == null
                            ? null
                            : () => _submitAnswer(quiz),
                        icon: Icon(_currentIndex < quiz.questions.length - 1
                            ? Icons.navigate_next
                            : Icons.check),
                        label: Text(_currentIndex < quiz.questions.length - 1
                            ? 'Next'
                            : 'Finish'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuizData {
  final String title;
  final List<_Question> questions;
  _QuizData({required this.title, required this.questions});
}

class _Question {
  final String prompt;
  final List<String> options;
  final int correctIndex;
  _Question(
      {required this.prompt,
      required this.options,
      required this.correctIndex});
}
