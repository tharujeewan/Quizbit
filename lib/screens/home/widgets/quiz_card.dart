import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuizCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? category; // optional category key
  final VoidCallback? onStart;
  const QuizCard(
      {super.key,
      required this.title,
      required this.subtitle,
      this.category,
      this.onStart});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF161B33), Color(0xFF1E2752)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.quiz, color: Color(0xFF00C2FF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () async {
                    // Record a new attempt document and increment user's counter.
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      final now = FieldValue.serverTimestamp();
                      await FirebaseFirestore.instance
                          .collection('quizAttempts')
                          .add({
                        'title': title,
                        'subtitle': subtitle,
                        'category': category,
                        'userId': user?.uid,
                        'createdAt': now,
                      });
                      if (user != null) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .set({
                          'quizzesPlayedCount': FieldValue.increment(1),
                          'lastPlayedAt': now,
                        }, SetOptions(merge: true));
                      }
                    } catch (_) {}
                    if (onStart != null) onStart!();
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
