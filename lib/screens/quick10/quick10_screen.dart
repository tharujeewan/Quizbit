import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:hive/hive.dart';

class Quick10Screen extends StatefulWidget {
  static const String route = '/quick10';
  final String quizId;

  const Quick10Screen({super.key, required this.quizId});

  @override
  State<Quick10Screen> createState() => _Quick10ScreenState();
}

class _Quick10ScreenState extends State<Quick10Screen> {
  final Map<int, int> _selectedAnswers = {};
  bool _submitted = false;
  int _score = 0;
  late Future<List<Map<String, dynamic>>> _questionsFuture;
  int _reviewIndex = 0; // <-- Add this for review navigation

  @override
  void initState() {
    super.initState();
    _questionsFuture = _loadQuestions();
  }

  Future<List<Map<String, dynamic>>> _loadQuestions() async {
    List<Map<String, dynamic>> questions;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId)
          .get();

      if (!doc.exists) throw Exception('Quiz not found');

      final data = doc.data()!;
      questions =
          (data['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      // Save questions locally for offline use
      var box = await Hive.openBox('quick10_questions');
      await box.put(widget.quizId, questions);
    } catch (e) {
      // If offline or error, try to load from local storage
      var box = await Hive.openBox('quick10_questions');
      questions = box.get(widget.quizId,
              defaultValue: [])?.cast<Map<String, dynamic>>() ??
          [];
      if (questions.isEmpty) throw Exception('No offline questions available');
    }

    // Shuffle questions based on today's date so it's different every day
    final today = DateTime.now();
    final seed = int.parse('${today.year}${today.month}${today.day}');
    questions.shuffle(Random(seed));

    // Pick the first 10 questions (or less if not enough)
    return questions.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick 10')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final questions = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: !_submitted
                    ? ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: questions.length,
                        itemBuilder: (context, index) {
                          final question = questions[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Q${index + 1}. ${question['prompt']}',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  ...List.generate(
                                    (question['options'] as List).length,
                                    (optionIndex) => RadioListTile<int>(
                                      value: optionIndex,
                                      groupValue: _selectedAnswers[index],
                                      onChanged: _submitted
                                          ? null
                                          : (value) {
                                              setState(() {
                                                _selectedAnswers[index] =
                                                    value!;
                                              });
                                            },
                                      title: Text(
                                          question['options'][optionIndex]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildReviewCard(questions),
                      ),
              ),
              if (_submitted)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: _reviewIndex > 0
                            ? () => setState(() => _reviewIndex--)
                            : null,
                        child: const Text('Previous'),
                      ),
                      ElevatedButton(
                        onPressed: _reviewIndex < questions.length - 1
                            ? () => setState(() => _reviewIndex++)
                            : null,
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _submitted
                      ? () async {
                          final shouldLeave = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Leave Review?'),
                              content: const Text('Are you sure you want to exit the review?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Yes'),
                                ),
                              ],
                            ),
                          );
                          if (shouldLeave == true) {
                            Navigator.pop(context);
                          }
                        }
                      : () {
                          setState(() {
                            _submitted = true;
                            _reviewIndex = 0;
                          });
                        },
                  child: Text(_submitted ? 'Close' : 'Submit Answers'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReviewCard(List<Map<String, dynamic>> questions) {
    final question = questions[_reviewIndex];
    int correctIndex;
    if (question.containsKey('correctIndex')) {
      correctIndex = question['correctIndex'] ?? 0;
    } else if (question.containsKey('correct')) {
      final correctAnswer = question['correct'];
      final options = question['options'] as List;
      correctIndex = options.indexOf(correctAnswer);
    } else {
      correctIndex = 0;
    }
    final userAnswer = _selectedAnswers[_reviewIndex];
    final isCorrect = userAnswer == correctIndex;
    return Card(
      color: isCorrect ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q${_reviewIndex + 1}. ${question['prompt']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...List.generate(
              (question['options'] as List).length,
              (optionIndex) {
                final isSelected = userAnswer == optionIndex;
                final isCorrectOption = correctIndex == optionIndex;
                return ListTile(
                  leading: Icon(
                    isSelected
                        ? (isCorrectOption ? Icons.check_circle : Icons.cancel)
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? (isCorrectOption ? Colors.green : Colors.red)
                        : Colors.grey,
                  ),
                  title: Text(
                    question['options'][optionIndex],
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isCorrectOption ? Colors.green : null,
                    ),
                  ),
                  subtitle: isSelected
                      ? Text(isCorrectOption ? 'Correct' : 'Incorrect',
                          style: TextStyle(
                              color:
                                  isCorrectOption ? Colors.green : Colors.red))
                      : null,
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Correct answer: ${question['options'][correctIndex]}',
              style: const TextStyle(
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
