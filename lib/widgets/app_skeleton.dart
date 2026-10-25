import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.mutedSurface(context),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class ExploreGridSkeleton extends StatelessWidget {
  const ExploreGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading categories',
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 170,
        ),
        itemCount: 6,
        itemBuilder:
            (_, __) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.elevatedSurface(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SkeletonBox(width: 48, height: 48, radius: 24),
                  SizedBox(height: 14),
                  SkeletonBox(width: 112, height: 12),
                  SizedBox(height: 8),
                  SkeletonBox(width: 88, height: 10),
                ],
              ),
            ),
      ),
    );
  }
}

class ListRowsSkeleton extends StatelessWidget {
  final int count;
  final double rowHeight;

  const ListRowsSkeleton({super.key, this.count = 6, this.rowHeight = 74});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading list',
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder:
            (_, __) => SizedBox(
              height: rowHeight,
              child: Row(
                children: [
                  const SkeletonBox(width: 52, height: 52, radius: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(width: 150, height: 12),
                        SizedBox(height: 8),
                        SkeletonBox(width: 220, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

class RequestCardsSkeleton extends StatelessWidget {
  const RequestCardsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading requests',
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder:
            (_, __) => Container(
              height: 250,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.elevatedSurface(context),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 180, height: 12),
                  SizedBox(height: 12),
                  SkeletonBox(width: 220, height: 24),
                  SizedBox(height: 20),
                  SkeletonBox(width: double.infinity, height: 1),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      SkeletonBox(width: 40, height: 40, radius: 20),
                      SizedBox(width: 12),
                      SkeletonBox(width: 140, height: 12),
                    ],
                  ),
                  Spacer(),
                  Row(
                    children: [
                      Expanded(child: SkeletonBox(height: 44, radius: 22)),
                      SizedBox(width: 12),
                      Expanded(child: SkeletonBox(height: 44, radius: 22)),
                    ],
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading profile',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Container(
            height: 180,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.elevatedSurface(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonBox(width: 80, height: 80, radius: 40),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 150, height: 18),
                        SizedBox(height: 10),
                        SkeletonBox(width: 100, height: 11),
                      ],
                    ),
                  ],
                ),
                Spacer(),
                SkeletonBox(width: double.infinity, height: 1),
                SizedBox(height: 12),
                SkeletonBox(width: 230, height: 11),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SkeletonBox(height: 56, radius: 24),
          const SizedBox(height: 24),
          const SkeletonBox(width: 90, height: 14),
          const SizedBox(height: 12),
          const SkeletonBox(height: 42, radius: 21),
          const SizedBox(height: 24),
          const SkeletonBox(height: 220, radius: 24),
        ],
      ),
    );
  }
}
