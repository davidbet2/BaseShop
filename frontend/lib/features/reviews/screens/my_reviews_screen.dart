import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/reviews/bloc/reviews_bloc.dart';
import 'package:baseshop/features/reviews/bloc/reviews_event.dart';
import 'package:baseshop/features/reviews/bloc/reviews_state.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});
  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ReviewsBloc>().add(const LoadMyReviews());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Mis Reseñas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocBuilder<ReviewsBloc, ReviewsState>(
        builder: (context, state) {
          if (state is ReviewsLoading) {
            return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
          }
          if (state is ReviewsError) {
            return _buildError(state.message);
          }
          if (state is ReviewsLoaded) {
            if (state.reviews.isEmpty) return _buildEmpty();
            return _buildList(state.reviews);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> reviews) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<ReviewsBloc>().add(const LoadMyReviews());
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: reviews.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final r = reviews[i];
          final title = (r['title'] ?? '').toString();
          final comment = (r['comment'] ?? '').toString();
          final rating = (r['rating'] as num?)?.toInt() ?? 0;
          final productName = (r['product_name'] ?? r['productName'] ?? '').toString();
          final createdAt = r['created_at'] ?? r['createdAt'] ?? '';
          String dateStr = '';
          if (createdAt.toString().isNotEmpty) {
            try {
              final date = DateTime.parse(createdAt.toString());
              dateStr = DateFormat('dd MMM yyyy', 'es').format(date);
            } catch (_) {}
          }

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (productName.isNotEmpty)
                  Text(productName, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                if (productName.isNotEmpty) const SizedBox(height: 6),
                Row(
                  children: [
                    ...List.generate(5, (si) => Icon(
                      si < rating ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 18, color: si < rating ? const Color(0xFFFBBF24) : Colors.grey.shade300,
                    )),
                    const Spacer(),
                    if (dateStr.isNotEmpty)
                      Text(dateStr, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
                if (title.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                ],
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(comment, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.rate_review_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Sin reseñas aún', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text('Tus reseñas de productos aparecerán aquí', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.read<ReviewsBloc>().add(const LoadMyReviews()),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
