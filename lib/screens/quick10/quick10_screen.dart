import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  void initState() {
    super.initState();
    _questionsFuture = _loadQuestions();
  }

  Future<List<Map<String, dynamic>>> _loadQuestions() async {
    final doc = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(widget.quizId)
        .get();

    if (!doc.exists) throw Exception('Quiz not found');

    final data = doc.data()!;
    final questions =
        (data['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return questions;
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
                child: ListView.builder(
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
                              style: Theme.of(context).textTheme.titleMedium,
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
                                          _selectedAnswers[index] = value!;
                                        });
                                      },
                                title: Text(question['options'][optionIndex]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _submitted
                      ? () => Navigator.pop(context)
                      : () {
                          setState(() => _submitted = true);
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
}
