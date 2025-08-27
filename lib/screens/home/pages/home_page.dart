import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../state/quiz_state.dart';
import '../widgets/quiz_card.dart';
import '../quizzes_list_screen.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuizCard(
            title: 'Quick 10',
            subtitle: '10 random questions',
            onStart: () {
              context.read<QuizState>().setQuizType('quick10');
              Navigator.of(context).pushNamed(QuizzesListScreen.route);
            },
          ),
          const SizedBox(height: 10),
          QuizCard(
            title: 'Timed Challenge',
            subtitle: 'Beat the clock',
            onStart: () {
              context.read<QuizState>().setQuizType('timed');
              Navigator.of(context).pushNamed(QuizzesListScreen.route);
            },
          ),
        ],
      ),
    );
  }
}
