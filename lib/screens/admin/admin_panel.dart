import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../state/auth_state.dart';
import '../../state/quiz_state.dart';
import '../auth/login_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  static const String route = '/admin';
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

enum QuizType { quick10, timed, category }

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<_QuestionField> _questions = [
    _QuestionField(),
  ];
  bool _isSaving = false;
  late final Stream<int> _totalUsersStream;
  late final Stream<int> _totalAttemptsStream;
  late final Stream<List<_UserStat>> _topUsersStream;
  QuizCategory _selectedCategory = QuizCategory.general;
  QuizDifficulty _selectedDifficulty = QuizDifficulty.easy;
  QuizType _selectedQuizType = QuizType.category;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _totalUsersStream = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .map((s) => s.size);
    _totalAttemptsStream = FirebaseFirestore.instance
        .collection('quizAttempts')
        .snapshots()
        .map((s) => s.size);
    _topUsersStream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('quizzesPlayedCount', descending: true)
        .limit(10)
        .snapshots()
        .map((s) => s.docs
            .map((d) => _UserStat(
                  displayName: (d.data()['displayName'] ?? '') as String,
                  quizzesPlayedCount:
                      (d.data()['quizzesPlayedCount'] ?? 0) as int,
                ))
            .toList());
  }

  Future<void> _saveQuiz() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      String quizTypeString = _selectedQuizType.name; // Add this

      final quizDoc = <String, dynamic>{
        'title': _titleController.text,
        'description': _descriptionController.text,
        'type': quizTypeString, // Save the type
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': context.read<AuthState>().userName ?? 'Unknown',
        'questions': _questions.map((q) => q.toMap()).toList(),
      };

      // Only add category/difficulty/level for category type
      if (_selectedQuizType == QuizType.category) {
        final categoryName = _selectedCategory.name;
        final difficultyName = _selectedDifficulty.name;
        final nextLevel = await _getNextLevel(categoryName, difficultyName);
        quizDoc['category'] = categoryName;
        quizDoc['difficulty'] = difficultyName;
        quizDoc['level'] = nextLevel;
      }

      final docRef =
          await FirebaseFirestore.instance.collection('quizzes').add(quizDoc);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quiz saved successfully! (ID: ${docRef.id})'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      String errorMessage = 'Failed to save quiz';

      if (e.toString().contains('permission-denied') ||
          e.toString().contains('PERMISSION_DENIED')) {
        errorMessage =
            'Permission denied. Please check your Firestore security rules.';
      } else if (e.toString().contains('unavailable') ||
          e.toString().contains('UNAVAILABLE')) {
        errorMessage =
            'Firestore is currently unavailable. Please try again later.';
      } else if (e.toString().contains('network') ||
          e.toString().contains('NETWORK')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else {
        errorMessage = 'Failed to save quiz: ${e.toString()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );

      // Log the full error for debugging
      print('Quiz save error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthState>().isAdmin;
    if (!isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Access denied')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthState>().logout();
              Navigator.of(context)
                  .pushNamedAndRemoveUntil(LoginScreen.route, (route) => false);
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stats cards
              _AdminStatsRow(
                totalUsersStream: _totalUsersStream,
                totalAttemptsStream: _totalAttemptsStream,
              ),
              const SizedBox(height: 16),
              _TopUsersCard(stream: _topUsersStream),
              const SizedBox(height: 24),

              // 1. Select Quiz Type First
              DropdownButtonFormField<QuizType>(
                value: _selectedQuizType,
                items: QuizType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(_quizTypeLabel(t)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedQuizType = value);
                },
                decoration: const InputDecoration(labelText: 'Quiz Type'),
              ),
              const SizedBox(height: 12),

              // 2. Conditionally show fields for 'Category' type
              if (_selectedQuizType == QuizType.category) ...[
                DropdownButtonFormField<QuizCategory>(
                  value: _selectedCategory,
                  items: QuizCategory.values
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(_categoryLabel(c)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null)
                      setState(() => _selectedCategory = value);
                  },
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<QuizDifficulty>(
                  value: _selectedDifficulty,
                  items: QuizDifficulty.values
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(
                                d.name[0].toUpperCase() + d.name.substring(1)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null)
                      setState(() => _selectedDifficulty = value);
                  },
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                ),
                const SizedBox(height: 12),
              ],

              // 3. Conditionally show Title and Description
              if (_selectedQuizType == QuizType.category ||
                  _selectedQuizType == QuizType.timed) ...[
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Quiz title'),
                  validator: (v) =>
                      v != null && v.trim().isNotEmpty ? null : 'Enter a title',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration:
                      const InputDecoration(labelText: 'Quiz description'),
                  validator: (v) => v != null && v.trim().isNotEmpty
                      ? null
                      : 'Enter a description',
                ),
                const SizedBox(height: 16),
              ],
              Text('Questions',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._questions
                  .asMap()
                  .entries
                  .map((entry) => _buildQuestionCard(entry.key, entry.value))
                  .toList(),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _questions.add(_QuestionField())),
                icon: const Icon(Icons.add),
                label: const Text('Add question'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveQuiz,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save quiz'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, _QuestionField question) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Q${index + 1}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _questions.removeAt(index)),
                ),
              ],
            ),
            TextFormField(
              controller: question.promptController,
              decoration: const InputDecoration(labelText: 'Question prompt'),
              validator: (v) =>
                  v != null && v.trim().isNotEmpty ? null : 'Enter a question',
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: question.correctController,
              decoration: const InputDecoration(labelText: 'Correct answer'),
              validator: (v) => v != null && v.trim().isNotEmpty
                  ? null
                  : 'Enter the correct answer',
            ),
            const SizedBox(height: 8),
            ...List.generate(3, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextFormField(
                  controller: question.incorrectControllers[i],
                  decoration:
                      InputDecoration(labelText: 'Incorrect answer ${i + 1}'),
                  validator: (v) => v != null && v.trim().isNotEmpty
                      ? null
                      : 'Enter an option',
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(QuizCategory c) {
    final name = c.name;
    return name[0].toUpperCase() + name.substring(1);
  }

  String _quizTypeLabel(QuizType t) {
    switch (t) {
      case QuizType.quick10:
        return 'Quick 10';
      case QuizType.timed:
        return 'Timed Challenge';
      case QuizType.category:
        return 'Category';
    }
  }
}

class _QuestionField {
  final TextEditingController promptController = TextEditingController();
  final TextEditingController correctController = TextEditingController();
  final List<TextEditingController> incorrectControllers =
      List.generate(3, (_) => TextEditingController());

  bool isValid() {
    return promptController.text.trim().isNotEmpty &&
        correctController.text.trim().isNotEmpty &&
        incorrectControllers.every((c) => c.text.trim().isNotEmpty);
  }

  Map<String, dynamic> toMap() {
    return {
      'prompt': promptController.text.trim(),
      'correct': correctController.text.trim(),
      'incorrect': incorrectControllers.map((c) => c.text.trim()).toList(),
    };
  }

  void dispose() {
    promptController.dispose();
    correctController.dispose();
    for (final c in incorrectControllers) {
      c.dispose();
    }
  }
}

class _AdminStatsRow extends StatelessWidget {
  final Stream<int> totalUsersStream;
  final Stream<int> totalAttemptsStream;
  const _AdminStatsRow({
    required this.totalUsersStream,
    required this.totalAttemptsStream,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Total Users',
            stream: totalUsersStream,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Total Quizzes Played',
            stream: totalAttemptsStream,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final Stream<int> stream;
  const _StatCard({required this.title, required this.stream});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<int>(
          stream: stream,
          builder: (context, snapshot) {
            final value = snapshot.data ?? 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: Colors.black54)),
                const SizedBox(height: 8),
                Text('$value',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopUsersCard extends StatelessWidget {
  final Stream<List<_UserStat>> stream;
  const _TopUsersCard({required this.stream});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Top Users',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StreamBuilder<List<_UserStat>>(
              stream: stream,
              builder: (context, snapshot) {
                final users = snapshot.data ?? const <_UserStat>[];
                if (users.isEmpty) {
                  return const Text('No data yet');
                }
                return Column(
                  children: [
                    for (final u in users)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.person_outline),
                        title: Text(
                            u.displayName.isEmpty ? 'Unknown' : u.displayName),
                        trailing: Text('${u.quizzesPlayedCount} played'),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _UserStat {
  final String displayName;
  final int quizzesPlayedCount;
  _UserStat({required this.displayName, required this.quizzesPlayedCount});
}

Future<int> _getNextLevel(String category, String difficulty) async {
  final querySnapshot = await FirebaseFirestore.instance
      .collection('quizzes')
      .where('category', isEqualTo: category)
      .where('difficulty', isEqualTo: difficulty)
      .get();

  int maxLevel = 0;
  for (var doc in querySnapshot.docs) {
    final levelRaw = doc.data()['level'];
    int level;
    if (levelRaw is int) {
      level = levelRaw;
    } else if (levelRaw is double) {
      level = levelRaw.toInt();
    } else if (levelRaw is String) {
      level = int.tryParse(levelRaw) ?? 0;
    } else {
      level = 0;
    }
    if (level > maxLevel) maxLevel = level;
  }
  return maxLevel + 1;
}
