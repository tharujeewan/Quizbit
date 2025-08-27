import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['quizId'] is String) {
      final quizId = args['quizId'] as String;
      _quizFuture = _loadQuiz(quizId);
    } else {
      _quizFuture = Future.error('Missing quizId');
    }
  }

  Future<_QuizData> _loadQuiz(String quizId) async {
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
  }

  void _submitAnswer(_QuizData quiz) {
    final question = quiz.questions[_currentIndex];
    if (_selectedOptionIndex != null &&
        _selectedOptionIndex == question.correctIndex) {
      _score += 1;
    }
    if (_currentIndex < quiz.questions.length - 1) {
      setState(() {
        _currentIndex += 1;
        _selectedOptionIndex = null;
      });
    } else {
      _showResult(quiz);
    }
  }

  void _showResult(_QuizData quiz) {
    final total = quiz.questions.length;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Quiz Completed'),
          content: Text('Score: $_score / $total'),
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

        return Scaffold(
          appBar: AppBar(title: Text(quiz.title)),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(progress, style: Theme.of(context).textTheme.labelLarge),
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
                ElevatedButton.icon(
                  onPressed: _selectedOptionIndex == null
                      ? null
                      : () => _submitAnswer(quiz),
                  icon: Icon(_currentIndex < quiz.questions.length - 1
                      ? Icons.navigate_next
                      : Icons.check),
                  label: Text(_currentIndex < quiz.questions.length - 1
                      ? 'Next'
                      : 'Finish'),
                )
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
