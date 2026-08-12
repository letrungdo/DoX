import 'package:do_x/constants/dimens.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/movie_model.dart';
import 'package:do_x/screen/movie/movie_poster_card.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:do_x/widgets/neu/neu_chip.dart';
import 'package:flutter/material.dart';

/// Everything under the pinned player: chips, server/episode picker,
/// description, credits and the related-movies rail.
class MovieDetailBody extends StatelessWidget {
  const MovieDetailBody({
    super.key,
    required this.detail,
    required this.selectedServer,
    required this.selectedEpisode,
    required this.onRefresh,
    required this.onServerSelected,
    required this.onEpisodeSelected,
    required this.onRelatedTap,
  });

  final MovieDetail? detail;
  final MovieEpisodeServer? selectedServer;
  final MovieEpisode? selectedEpisode;
  final Future<void> Function() onRefresh;
  final ValueChanged<MovieEpisodeServer> onServerSelected;
  final ValueChanged<MovieEpisode> onEpisodeSelected;
  final ValueChanged<Movie> onRelatedTap;

  @override
  Widget build(BuildContext context) => _buildScrollableBody(context);

  /// True when the language chip already reads as "Vietsub" / "Phụ đề".
  bool get _languageImpliesVietsub {
    final language = detail?.language?.toLowerCase();
    if (language == null || language.isEmpty) return false;
    return language.contains('sub') || language.contains('phụ đề');
  }

  /// One labelled line of the info card, e.g. `Đạo diễn  •  A, B`.
  /// Renders nothing when [values] is empty.
  Widget _metadataRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required List<String> values,
  }) {
    if (values.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              values.join(', '),
              style: const TextStyle(fontSize: 12.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metadataChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color ?? colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  /// Everything under the pinned player: chips, servers, description, related.
  Widget _buildScrollableBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((detail?.views?.isNotEmpty ?? false) ||
                      (detail?.likes?.isNotEmpty ?? false) ||
                      (detail?.hasVietsub ?? false)) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (detail?.quality?.isNotEmpty ?? false)
                          _metadataChip(
                            context,
                            icon: Icons.high_quality_rounded,
                            label: detail!.quality!,
                            color: Colors.amberAccent,
                          ),
                        if (detail?.language?.isNotEmpty ?? false)
                          _metadataChip(
                            context,
                            icon: Icons.language_rounded,
                            label: detail!.language!,
                            color: Colors.blueAccent,
                          ),
                        if (detail?.time?.isNotEmpty ?? false)
                          _metadataChip(
                            context,
                            icon: Icons.timer_outlined,
                            label: detail!.time!,
                          ),
                        if (detail?.views?.isNotEmpty ?? false)
                          _metadataChip(
                            context,
                            icon: Icons.visibility_rounded,
                            label: detail!.views!,
                          ),
                        if (detail?.likes?.isNotEmpty ?? false)
                          _metadataChip(
                            context,
                            icon: Icons.favorite_rounded,
                            label: detail!.likes!,
                            color: Colors.pinkAccent,
                          ),
                        // Skipped when `language` already says it (e.g. lang "Vietsub"),
                        // otherwise the same tag shows twice.
                        if ((detail?.hasVietsub ?? false) &&
                            !_languageImpliesVietsub)
                          _metadataChip(
                            context,
                            icon: Icons.subtitles_rounded,
                            label: l10n.vietsub,
                            color: Colors.lightGreenAccent,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Server selector
                  if (detail?.servers.isNotEmpty ?? false) ...[
                    NeuCard(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                l10n.serverLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                // Clips at the viewport so chips never draw over the
                                // label; the padding keeps room for their shadows.
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    spacing: 8,
                                    children: detail!.servers.map((srv) {
                                      final isSelected =
                                          selectedServer?.name == srv.name;
                                      return NeuChip(
                                        label: srv.name,
                                        isSelected: isSelected,
                                        fontSize: 12,
                                        onTap: () {
                                          onServerSelected(srv);
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (selectedServer != null &&
                              selectedServer!.episodes.length > 1) ...[
                            const SizedBox(height: 12),
                            Text(
                              '${l10n.episodeLabel}:',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: selectedServer!.episodes.map((ep) {
                                  final isSelected =
                                      selectedEpisode?.slug == ep.slug;
                                  return NeuChip(
                                    label: ep.name,
                                    isSelected: isSelected,
                                    fontSize: 11,
                                    onTap: () {
                                      onEpisodeSelected(ep);
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Description
                  if (detail?.description.isNotEmpty ?? false)
                    NeuCard(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        detail!.description
                            .replaceAll(RegExp(r'<[^>]*>'), '')
                            .trim(),
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),

                  // Tags and Metadata
                  if ((detail?.tags.isNotEmpty ?? false) ||
                      (detail?.countries.isNotEmpty ?? false) ||
                      (detail?.actors.isNotEmpty ?? false) ||
                      (detail?.directors.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 12),
                    NeuCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _metadataRow(
                            context,
                            icon: Icons.movie_creation_rounded,
                            label: l10n.directorLabel,
                            values: detail!.directors,
                          ),
                          _metadataRow(
                            context,
                            icon: Icons.people_alt_rounded,
                            label: l10n.actorsLabel,
                            values: detail!.actors,
                          ),
                          _metadataRow(
                            context,
                            icon: Icons.public_rounded,
                            label: l10n.countryLabel,
                            values: detail!.countries,
                          ),
                          _metadataRow(
                            context,
                            icon: Icons.local_offer_rounded,
                            label: l10n.genreLabel,
                            values: detail!.tags,
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Related movies
                  if (detail?.relatedMovies.isNotEmpty ?? false) ...[
                    const SizedBox(height: 20),
                    Text(
                      l10n.relatedMovies,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: detail!.relatedMovies.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final rel = detail!.relatedMovies[index];
                          return SizedBox(
                            width: 130,
                            child: MoviePosterCard(
                              movie: rel,
                              showOverlays: false,
                              titleMaxLines: 2,
                              titleFontSize: 11,
                              onTap: (_) => onRelatedTap(rel),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Add spacing at bottom to prevent shadow clipping and respect safe area
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }

  /// [fillParent] lets the caller (the overlay) dictate the size instead of the
  /// aspect ratio; [compact] drops every overlay and gesture so the collapsed
  /// mini player shows just the picture and taps reach the host.
}
