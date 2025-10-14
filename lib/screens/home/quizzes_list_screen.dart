import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../state/quiz_state.dart';
import 'package:hive/hive.dart';
import '../../models/quiz.dart';

class QuizzesListScreen extends StatelessWidget {
  static const String route = '/quizzes';
  const QuizzesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final quizState = context.watch<QuizState>();
    final selectedCategory = quizState.selectedCategory;
    final selectedDifficulty = quizState.selectedDifficulty;
    final selectedQuizType = quizState.selectedQuizType;

    // For Quick 10, directly fetch and show questions
    if (selectedQuizType == 'quick10') {
      return Scaffold(
        appBar: AppBar(title: const Text('Quick 10')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('quizzes')
              .where('quizType', isEqualTo: 'quick10')
              .limit(1) // Get one random quiz
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('No Quick 10 quizzes available'));
            }

            // Navigate directly to quiz play
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed(
                '/quiz_play',
                arguments: {'quizId': docs.first.id},
              );
            });

            return const Center(child: CircularProgressIndicator());
          },
        ),
      );
    }

    // Existing code for other quiz types
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('quizzes');
    String titleText;

    if (selectedQuizType != null) {
      query = query.where('quizType', isEqualTo: selectedQuizType);
      titleText = selectedQuizType == 'quick10'
          ? 'Quick 10'
          : selectedQuizType == 'timed'
              ? 'Timed Challenge'
              : 'Quizzes';
    } else {
      query = query
          .where('category', isEqualTo: selectedCategory.name)
          .where('difficulty', isEqualTo: selectedDifficulty.name);
      titleText =
          '${_capitalize(selectedCategory.name)} • ${_capitalize(selectedDifficulty.name)}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || (snapshot.data?.docs.isEmpty ?? true)) {
            // Try to load offline quizzes from Hive
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadOfflineQuizList(),
              builder: (context, offlineSnapshot) {
                if (offlineSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final offlineQuizzes = offlineSnapshot.data ?? [];
                if (offlineQuizzes.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No quizzes available offline.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: offlineQuizzes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final quiz = offlineQuizzes[index];
                    final quizId = quiz['id'] ?? '';
                    final title = (quiz['title'] ?? '') as String;
                    final description = (quiz['description'] ?? '') as String;
                    final createdBy = (quiz['createdBy'] ?? '') as String;

                    return Card(
                      child: ListTile(
                        title: Text(title),
                        subtitle: Text(description.isEmpty
                            ? 'by ${createdBy.isEmpty ? 'Unknown' : createdBy}'
                            : description),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            '/quiz_play',
                            arguments: {'quizId': quizId},
                          );
                        },
                      ),
                    );
                  },
                );
              },
            );
          }

          final docs = snapshot.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          // Sort client-side by 'level' field instead of 'createdAt'
          final sortedDocs = [...docs]..sort((a, b) {
              final aLevel = a.data()['level'] ?? 0;
              final bLevel = b.data()['level'] ?? 0;
              return aLevel.compareTo(bLevel);
            });
          if (docs.isEmpty) {
            return const Center(
              child: Text('No quizzes found in this category yet.'),
            );
          }

          return FutureBuilder<Set<String>>(
            future: _getCompletedQuizIds(),
            builder: (context, completedSnapshot) {
              final completedIds = completedSnapshot.data ?? {};
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: sortedDocs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final data = sortedDocs[index].data();
                  final quizId = sortedDocs[index].id;
                  final title = (data['title'] ?? '') as String;
                  final description = (data['description'] ?? '') as String;
                  final createdBy = (data['createdBy'] ?? '') as String;
            
                  // Lock logic: Only first quiz unlocked, next unlocked if previous completed
                  bool isCompleted = completedIds.contains(quizId);
                  bool isUnlocked = index == 0 || completedIds.contains(sortedDocs[index - 1].id);
            
                  return Card(
                    child: ListTile(
                      title: Text(title),
                      subtitle: Text(description.isEmpty
                          ? 'by ${createdBy.isEmpty ? 'Unknown' : createdBy}'
                          : description),
                      trailing: isCompleted
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : isUnlocked
                              ? const Icon(Icons.lock_open, color: Colors.blue)
                              : const Icon(Icons.lock, color: Colors.grey),
                      enabled: isUnlocked,
                      onTap: isUnlocked
                          ? () {
                              Navigator.of(context).pushNamed(
                                '/quiz_play',
                                arguments: {'quizId': quizId},
                              );
                            }
                          : null,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  void _saveQuizOffline(Map<String, dynamic> quizData, String quizId) async {
    var box = await Hive.openBox('quick10_questions');
    final questions =
        (quizData['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    await box.put(quizId, questions);
  }

  Future<List<Map<String, dynamic>>> _loadOfflineQuiz(String quizId) async {
    var box = await Hive.openBox('quick10_questions');
    return box.get(quizId, defaultValue: [])?.cast<Map<String, dynamic>>() ??
        [];
  }

  Future<List<Map<String, dynamic>>> _loadOfflineQuizList() async {
    var box = await Hive.openBox('quick10_questions');
    // Each value in the box is a list of questions, but we want quiz metadata
    List<Map<String, dynamic>> quizzes = [];
    for (var key in box.keys) {
      // You may want to store quiz metadata separately for offline use
      // For now, just use the key as quizId and get the first question's metadata if available
      final questions =
          box.get(key, defaultValue: [])?.cast<Map<String, dynamic>>() ?? [];
      if (questions.isNotEmpty) {
        quizzes.add({
          'id': key,
          'title': questions.first['quizTitle'] ?? 'Offline Quiz',
          'description': questions.first['quizDescription'] ?? '',
          'createdBy': questions.first['createdBy'] ?? '',
        });
      }
    }
    return quizzes;
  }

  // Example usage after fetching from Firestore:
  // _saveQuizOffline(data, quizId);

  // Example usage for offline:
  // final questions = await _loadOfflineQuiz(quizId);
  // Remove these lines:
  // final box = await Hive.openBox<Quiz>('quizzes');
  // final quizzes = box.values.toList();
  // Use quizzes in your UI
}

Future<Set<String>> _getCompletedQuizIds() async {
  var box = await Hive.openBox('completed_quizzes');
  return Set<String>.from(box.get('ids', defaultValue: <String>[]));
}

Future<void> _markQuizCompleted(String quizId) async {
  var box = await Hive.openBox('completed_quizzes');
  final ids = Set<String>.from(box.get('ids', defaultValue: <String>[]));
  ids.add(quizId);
  await box.put('ids', ids.toList());
}
