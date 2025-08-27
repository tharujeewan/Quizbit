import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../state/quiz_state.dart';
import '../widgets/quiz_card.dart';
import '../quizzes_list_screen.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      childAspectRatio: 1.1,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        QuizCard(
          title: 'General',
          subtitle: 'All-around knowledge',
          category: QuizCategory.general.name,
          onStart: () {
            context.read<QuizState>().setCategory(QuizCategory.general);
            _showDifficultySheetAndNavigate(context);
          },
        ),
        QuizCard(
          title: 'Science',
          subtitle: 'Biology, Physics, Chemistry',
          category: QuizCategory.science.name,
          onStart: () {
            context.read<QuizState>().setCategory(QuizCategory.science);
            _showDifficultySheetAndNavigate(context);
          },
        ),
        QuizCard(
          title: 'Technology',
          subtitle: 'Computers & Gadgets',
          category: QuizCategory.technology.name,
          onStart: () {
            context.read<QuizState>().setCategory(QuizCategory.technology);
            _showDifficultySheetAndNavigate(context);
          },
        ),
        QuizCard(
          title: 'History',
          subtitle: 'Past events',
          category: QuizCategory.history.name,
          onStart: () {
            context.read<QuizState>().setCategory(QuizCategory.history);
            _showDifficultySheetAndNavigate(context);
          },
        ),
        QuizCard(
          title: 'Sports',
          subtitle: 'Games & records',
          category: QuizCategory.sports.name,
          onStart: () {
            context.read<QuizState>().setCategory(QuizCategory.sports);
            _showDifficultySheetAndNavigate(context);
          },
        ),
        QuizCard(
          title: 'Movies',
          subtitle: 'Cinema trivia',
          category: QuizCategory.movies.name,
          onStart: () {
            context.read<QuizState>().setCategory(QuizCategory.movies);
            _showDifficultySheetAndNavigate(context);
          },
        ),
      ],
    );
  }
}

void _showDifficultySheetAndNavigate(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select difficulty',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: QuizDifficulty.values.map((d) {
                return ChoiceChip(
                  label: Text(d.name[0].toUpperCase() + d.name.substring(1)),
                  selected: false,
                  onSelected: (_) {
                    context.read<QuizState>().setDifficulty(d);
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushNamed(QuizzesListScreen.route);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      );
    },
  );
}
