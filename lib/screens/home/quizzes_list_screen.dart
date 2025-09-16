import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../state/quiz_state.dart';

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
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Failed to load quizzes: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          // Sort client-side to avoid requiring a composite index
          final sortedDocs = [...docs]..sort((a, b) {
              final aTs = a.data()['createdAt'];
              final bTs = b.data()['createdAt'];
              final aMillis =
                  (aTs is Timestamp) ? aTs.millisecondsSinceEpoch : 0;
              final bMillis =
                  (bTs is Timestamp) ? bTs.millisecondsSinceEpoch : 0;
              return bMillis.compareTo(aMillis);
            });
          if (docs.isEmpty) {
            return const Center(
              child: Text('No quizzes found in this category yet.'),
            );
          }

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
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
