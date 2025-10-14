import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuizCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? category;
  final VoidCallback? onStart;
  final bool isUnlocked;
  final bool isCompleted;
  final IconData icon; // <-- Add this

  const QuizCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.category,
    this.onStart,
    required this.isUnlocked,
    required this.isCompleted,
    required this.icon, // <-- Add this
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: InkWell(
        onTap: isUnlocked ? onStart : null,
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
                  Icon(icon, color: const Color(0xFF00C2FF)), // <-- Use passed icon
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: isUnlocked ? onStart : null,
                    icon: isCompleted
                        ? const Icon(Icons.check, size: 18)
                        : const Icon(Icons.play_arrow, size: 18),
                    label: Text(isCompleted ? 'Completed' : 'Start'),
                    style: FilledButton.styleFrom(
                      backgroundColor: isUnlocked
                          ? const Color(0xFF00C2FF)
                          : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
