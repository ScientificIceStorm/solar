import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_session_controller.dart';
import '../../app/solar_app_scope.dart';
import '../../core/solar_competition_scope.dart';
import '../../models/robot_events_models.dart';
import '../../models/world_skills_models.dart';
import '../theme/solar_chrome_palette.dart';
import '../widgets/solar_navigation.dart';
import '../widgets/solar_screen_background.dart';
import '../widgets/solar_team_link.dart';
import 'onboarding_screen.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  static const routeName = '/rankings';

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen>
    with WidgetsBindingObserver {
  static const _allRegionsLabel = 'All Regions';
  static const _gradeOptions = <String>['High School', 'Middle School'];

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  AppSessionController? _sessionController;
  bool _isBootstrapping = true;
  bool _isLoadingRankings = false;
  int _loadGeneration = 0;
  List<SeasonSummary> _availableSeasons = const <SeasonSummary>[];
  List<WorldSkillsEntry> _activeRankings = const <WorldSkillsEntry>[];
  int? _selectedSeasonId;
  String? _selectedGradeLevel;
  String _selectedRegion = _allRegionsLabel;
  String? _loadError;
  Timer? _retryTimer;
  bool _didAutoRetry = false;
  int _seenDataRevision = -1;
  String? _displayedRankingsKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = SolarAppScope.of(context);
    if (!identical(_sessionController, controller) ||
        (_seenDataRevision != controller.dataRevision && !_isLoadingRankings)) {
      _sessionController = controller;
      _seenDataRevision = controller.dataRevision;
      unawaited(_bootstrapFilters(controller, forceSeasons: false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _sessionController;
    if (state == AppLifecycleState.resumed &&
        controller != null &&
        _loadError != null &&
        !_isBootstrapping &&
        !_isLoadingRankings) {
      unawaited(_bootstrapFilters(controller, forceSeasons: true));
    }
  }

  Future<void> _bootstrapFilters(
    AppSessionController controller, {
    required bool forceSeasons,
  }) async {
    final generation = ++_loadGeneration;
    _retryTimer?.cancel();

    setState(() {
      _isBootstrapping = true;
      _loadError = null;
    });

    final seasons = await controller.fetchWorldSkillsSeasons(
      programFilter: solarPrimaryProgramFilter,
      force: forceSeasons,
    );
    final defaultSeasonId =
        controller.preferredSeasonId ??
        (seasons.isEmpty ? null : seasons.first.id);
    if (!_isCurrentLoad(controller, generation)) {
      return;
    }

    final resolvedSeasonId = _resolveSeasonSelection(
      requested: _selectedSeasonId ?? defaultSeasonId,
      seasons: seasons,
    );
    final resolvedGradeLevel =
        _selectedGradeLevel ?? controller.defaultWorldSkillsGradeLevel;

    setState(() {
      _availableSeasons = seasons;
      _selectedSeasonId = resolvedSeasonId;
      _selectedGradeLevel = resolvedGradeLevel;
      _isBootstrapping = false;
      _loadError = seasons.isEmpty
          ? controller.seasonLoadError ??
                'No seasons are available. Tap Retry to check again.'
          : null;
    });

    if (seasons.isEmpty &&
        !_didAutoRetry &&
        controller.seasonRetryAfter != null) {
      _didAutoRetry = true;
      _retryTimer = Timer(
        controller.seasonRetryAfter! + const Duration(seconds: 1),
        () {
          if (mounted) {
            unawaited(_bootstrapFilters(controller, forceSeasons: true));
          }
        },
      );
    }

    await _loadRankings(
      controller,
      generation: generation,
      force: forceSeasons,
    );
  }

  Future<void> _loadRankings(
    AppSessionController controller, {
    required int generation,
    required bool force,
  }) async {
    final seasonId = _selectedSeasonId;
    final gradeLevel = _selectedGradeLevel;
    if (seasonId == null || gradeLevel == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _activeRankings = const <WorldSkillsEntry>[];
        _isLoadingRankings = false;
      });
      return;
    }

    setState(() {
      _isLoadingRankings = true;
      final key = '$seasonId|$gradeLevel';
      if (_displayedRankingsKey != key) _activeRankings = [];
      _displayedRankingsKey = key;
    });

    final entries = await controller.fetchWorldSkillsRankings(
      seasonId: seasonId,
      gradeLevel: gradeLevel,
      force: force,
    );

    if (!_isCurrentLoad(controller, generation)) {
      return;
    }

    final regions = _regionOptions(entries);
    setState(() {
      _activeRankings = entries;
      _isLoadingRankings = false;
      _loadError = controller.rankingsLoadError;
      if (!regions.contains(_selectedRegion)) {
        _selectedRegion = _allRegionsLabel;
      }
    });
  }

  bool _isCurrentLoad(AppSessionController controller, int generation) {
    return mounted &&
        identical(_sessionController, controller) &&
        _loadGeneration == generation;
  }

  int? _resolveSeasonSelection({
    required int? requested,
    required List<SeasonSummary> seasons,
  }) {
    if (requested != null && seasons.any((season) => season.id == requested)) {
      return requested;
    }
    if (seasons.isNotEmpty) {
      return seasons.first.id;
    }
    return requested;
  }

  Future<void> _showFilterSheet(AppSessionController controller) async {
    final selected = await showModalBottomSheet<_RankingsFilterSelection>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        var tempSeasonId = _selectedSeasonId;
        var tempGradeLevel =
            _selectedGradeLevel ?? controller.defaultWorldSkillsGradeLevel;
        var tempRegion = _selectedRegion;
        final regionOptions = _regionOptions(_activeRankings);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF7F5F8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Center(
                          child: Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD5D4DD),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: <Widget>[
                            const Expanded(
                              child: Text(
                                'Ranking Filters',
                                style: TextStyle(
                                  color: Color(0xFF24243A),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(88, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop(
                                  _RankingsFilterSelection(
                                    seasonId: tempSeasonId,
                                    gradeLevel: tempGradeLevel,
                                    region: tempRegion,
                                  ),
                                );
                              },
                              child: const Text('Apply'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const _FilterSectionTitle('Season'),
                        const SizedBox(height: 10),
                        _SeasonDropdownField(
                          seasons: _availableSeasons,
                          selectedSeasonId: tempSeasonId,
                          onChanged: (seasonId) {
                            setModalState(() {
                              tempSeasonId = seasonId;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        const _FilterSectionTitle('Grade'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _gradeOptions
                              .map((grade) {
                                return _FilterChip(
                                  label: grade,
                                  selected: tempGradeLevel == grade,
                                  onTap: () {
                                    setModalState(() {
                                      tempGradeLevel = grade;
                                    });
                                  },
                                );
                              })
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 20),
                        const _FilterSectionTitle('Region'),
                        const SizedBox(height: 10),
                        _StringDropdownField(
                          values: regionOptions,
                          selectedValue: tempRegion,
                          hint: 'Select region',
                          onChanged: (region) {
                            if (region == null) {
                              return;
                            }
                            setModalState(() {
                              tempRegion = region;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selected == null) {
      return;
    }

    final seasonChanged = selected.seasonId != _selectedSeasonId;
    final gradeChanged = selected.gradeLevel != _selectedGradeLevel;
    final regionChanged = selected.region != _selectedRegion;
    if (!seasonChanged && !gradeChanged && !regionChanged) {
      return;
    }

    setState(() {
      _selectedSeasonId = selected.seasonId;
      _selectedGradeLevel = selected.gradeLevel;
      _selectedRegion = selected.region;
    });

    if (seasonChanged || gradeChanged) {
      final controller = _sessionController;
      if (controller != null) {
        final generation = ++_loadGeneration;
        await _loadRankings(controller, generation: generation, force: false);
      }
    }
  }

  Future<void> _showRankingSystemDialog() {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('How Rankings Work'),
          content: const Text(
            'Official World Skills scores from VEX Events, filtered by season, grade, and region. Saved scores open immediately; pull down to refresh.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final account = controller.currentAccount;
        if (account == null) {
          return const Scaffold(body: SizedBox.shrink());
        }

        final filteredEntries = _filterEntries(
          entries: _filterEntriesByRegion(
            entries: _activeRankings,
            selectedRegion: _selectedRegion,
          ),
          query: _searchController.text,
        );
        final activeRowCount = filteredEntries.length;
        final topInset = MediaQuery.paddingOf(context).top;
        final showStatusCard = activeRowCount == 0;
        final listItemCount = showStatusCard ? 3 : activeRowCount + 2;
        final chromeColor = solarChromeAccentColor(
          controller.chromeAccentPreference,
          customAccentValue: controller.customChromeAccentValue,
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            extendBody: true,
            backgroundColor: Colors.transparent,
            drawerEnableOpenDragGesture: true,
            drawerEdgeDragWidth: 36,
            drawer: SolarAppDrawer(
              account: account,
              onActionSelected: (action) {
                Navigator.of(context).pop();
                openSolarDrawerAction(context, action);
              },
              onSignOut: () async {
                await controller.signOut();
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pushNamedAndRemoveUntil(
                  OnboardingScreen.routeName,
                  (route) => false,
                );
              },
            ),
            body: SolarScreenBackground(
              padding: EdgeInsets.zero,
              respectSafeArea: false,
              child: Stack(
                children: <Widget>[
                  RefreshIndicator(
                    color: Colors.white,
                    onRefresh: () async {
                      await _bootstrapFilters(controller, forceSeasons: true);
                    },
                    child: StretchingOverscrollIndicator(
                      axisDirection: AxisDirection.down,
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: ClampingScrollPhysics(),
                        ),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(bottom: 164),
                        itemCount: listItemCount,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _RankingsHeader(
                              topInset: topInset,
                              chromeColor: chromeColor,
                              filterLabel: _filterLabel(
                                entries: _activeRankings,
                                fallbackGrade:
                                    _selectedGradeLevel ??
                                    controller.defaultWorldSkillsGradeLevel,
                                selectedRegion: _selectedRegion,
                              ),
                              seasonLabel: _selectedSeasonId == null
                                  ? (_isBootstrapping
                                        ? 'Season loading'
                                        : 'Season unavailable')
                                  : _seasonDisplayNameFromId(
                                      _availableSeasons,
                                      _selectedSeasonId!,
                                    ),
                              searchController: _searchController,
                              onSearchChanged: (_) => setState(() {}),
                              onInfoTap: _showRankingSystemDialog,
                              onFilterTap: () => _showFilterSheet(controller),
                              onMoreTap: () => _showFilterSheet(controller),
                            );
                          }

                          if (index == 1) {
                            return const SizedBox(height: 24);
                          }

                          if (showStatusCard) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                              ),
                              child: _isBootstrapping || _isLoadingRankings
                                  ? const _RankingsStatusCard.loading()
                                  : _RankingsStatusCard.message(
                                      _loadError ??
                                          (_searchController.text.trim().isEmpty
                                              ? 'No world skills scores have been posted for this season and grade.'
                                              : 'No ranked teams matched "${_searchController.text.trim()}".'),
                                      onRetry: () => _bootstrapFilters(
                                        controller,
                                        forceSeasons: true,
                                      ),
                                    ),
                            );
                          }

                          {
                            final entry = filteredEntries[index - 2];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                              ),
                              child: _RankingRow(
                                entry: entry,
                                highlighted:
                                    entry.teamNumber.trim().toUpperCase() ==
                                    account.team.number.trim().toUpperCase(),
                                showDivider:
                                    index - 2 != filteredEntries.length - 1,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: SolarBottomNavBar(
              current: SolarNavDestination.rankings,
              onSelected: (destination) {
                navigateToSolarDestination(context, destination);
              },
            ),
          ),
        );
      },
    );
  }
}

class _RankingsHeader extends StatelessWidget {
  const _RankingsHeader({
    required this.topInset,
    required this.chromeColor,
    required this.filterLabel,
    required this.seasonLabel,
    required this.searchController,
    required this.onSearchChanged,
    required this.onInfoTap,
    required this.onFilterTap,
    required this.onMoreTap,
  });

  final double topInset;
  final Color chromeColor;
  final String filterLabel;
  final String seasonLabel;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onInfoTap;
  final VoidCallback onFilterTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, topInset + 16, 24, 26),
      decoration: BoxDecoration(
        color: chromeColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(52),
          bottomRight: Radius.circular(52),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Builder(
                builder: (context) {
                  return InkWell(
                    key: const ValueKey<String>('page-menu-button'),
                    onTap: () => Scaffold.of(context).openDrawer(),
                    borderRadius: BorderRadius.circular(18),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: SolarMenuGlyph(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Rankings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -1.2,
                  ),
                ),
              ),
              _HeaderIconButton(
                icon: Icons.help_outline_rounded,
                onTap: onInfoTap,
              ),
              const SizedBox(width: 8),
              _HeaderIconButton(
                icon: Icons.more_vert_rounded,
                onTap: onMoreTap,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                key: const ValueKey<String>('rankings-search-field'),
                controller: searchController,
                onChanged: onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search teams',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                  suffixIcon: searchController.text.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                          ),
                        ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: onFilterTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: chromeColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          filterLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF16182C),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          seasonLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF71758B),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'SKILL',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 42,
        height: 42,
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

class _RankingsStatusCard extends StatelessWidget {
  const _RankingsStatusCard.loading()
    : message = null,
      loading = true,
      onRetry = null;

  const _RankingsStatusCard.message(this.message, {this.onRetry})
    : loading = false;

  final String? message;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(32),
      ),
      child: loading
          ? const SizedBox(
              height: 172,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Color(0xFF16182C),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message!,
                  style: const TextStyle(
                    color: Color(0xFF6F748B),
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                if (onRetry != null)
                  TextButton.icon(
                    key: const ValueKey('rankings-retry'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
              ],
            ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.entry,
    required this.highlighted,
    required this.showDivider,
  });

  final WorldSkillsEntry entry;
  final bool highlighted;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final labelColor = highlighted
        ? const Color(0xFF2930FF)
        : const Color(0xFF16182C);
    final subtitle = _teamSubtitle(entry.teamName, entry.organization);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 54,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${entry.rank}',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SolarTeamLinkText(
                      teamNumber: entry.teamNumber,
                      teamId: entry.teamId,
                      teamName: entry.teamName,
                      organization: entry.organization,
                      maxLines: 1,
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 24,
                        fontWeight: highlighted
                            ? FontWeight.w500
                            : FontWeight.w300,
                        letterSpacing: -1.2,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8E92A7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 74, maxWidth: 96),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${entry.combinedScore}',
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFF64677A),
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 68,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    _MiniScoreLine(
                      value: entry.maxProgrammingScore,
                      icon: Icons.memory_rounded,
                    ),
                    const SizedBox(height: 4),
                    _MiniScoreLine(
                      value: entry.maxDriverScore,
                      icon: Icons.sports_esports_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showDivider) ...<Widget>[
            const SizedBox(height: 10),
            Container(height: 1, color: const Color(0xFFDADAE3)),
          ],
        ],
      ),
    );
  }
}

class _MiniScoreLine extends StatelessWidget {
  const _MiniScoreLine({required this.value, required this.icon});

  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Text(
          '$value',
          style: const TextStyle(
            color: Color(0xFF707487),
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 4),
        Icon(icon, size: 15, color: const Color(0xFF707487)),
      ],
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF24243A),
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF24243A),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SeasonDropdownField extends StatelessWidget {
  const _SeasonDropdownField({
    required this.seasons,
    required this.selectedSeasonId,
    required this.onChanged,
  });

  final List<SeasonSummary> seasons;
  final int? selectedSeasonId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          dropdownColor: Colors.white,
          value: seasons.any((season) => season.id == selectedSeasonId)
              ? selectedSeasonId
              : (seasons.isEmpty ? null : seasons.first.id),
          hint: const Text('Select season'),
          items: seasons
              .map(
                (season) => DropdownMenuItem<int>(
                  value: season.id,
                  child: Text(
                    _seasonDisplayName(season),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF24243A),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _StringDropdownField extends StatelessWidget {
  const _StringDropdownField({
    required this.values,
    required this.selectedValue,
    required this.hint,
    required this.onChanged,
  });

  final List<String> values;
  final String? selectedValue;
  final String hint;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = values.contains(selectedValue) ? selectedValue : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          dropdownColor: Colors.white,
          value: value,
          hint: Text(hint),
          items: values
              .map(
                (entry) => DropdownMenuItem<String>(
                  value: entry,
                  child: Text(
                    entry,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF24243A),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _RankingsFilterSelection {
  const _RankingsFilterSelection({
    required this.seasonId,
    required this.gradeLevel,
    required this.region,
  });

  final int? seasonId;
  final String gradeLevel;
  final String region;
}

List<WorldSkillsEntry> _filterEntries({
  required List<WorldSkillsEntry> entries,
  required String query,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return entries;
  }

  final filtered = entries
      .where((entry) {
        final haystack = <String>[
          entry.teamNumber,
          entry.teamName,
          entry.organization,
          entry.city,
          entry.region,
          entry.country,
          entry.eventRegion,
        ].join(' ').toLowerCase();
        return haystack.contains(normalizedQuery);
      })
      .toList(growable: false);

  return filtered;
}

List<WorldSkillsEntry> _filterEntriesByRegion({
  required List<WorldSkillsEntry> entries,
  required String selectedRegion,
}) {
  if (selectedRegion == _RankingsScreenState._allRegionsLabel) {
    return entries;
  }

  return entries
      .where((entry) => _regionLabel(entry) == selectedRegion)
      .toList(growable: false);
}

List<String> _regionOptions(List<WorldSkillsEntry> entries) {
  final regions =
      <String>{
        _RankingsScreenState._allRegionsLabel,
        ...entries
            .map(_regionLabel)
            .where((region) => region.trim().isNotEmpty),
      }.toList(growable: false)..sort((a, b) {
        if (a == _RankingsScreenState._allRegionsLabel) {
          return -1;
        }
        if (b == _RankingsScreenState._allRegionsLabel) {
          return 1;
        }
        return a.compareTo(b);
      });
  return regions;
}

String _regionLabel(WorldSkillsEntry entry) {
  final value = entry.eventRegion.trim();
  if (value.isNotEmpty) {
    return value;
  }
  return <String>[
    entry.region.trim(),
    entry.country.trim(),
  ].where((value) => value.isNotEmpty).join(', ');
}

String _filterLabel({
  required List<WorldSkillsEntry> entries,
  required String fallbackGrade,
  required String selectedRegion,
}) {
  final program = entries.isNotEmpty
      ? entries.first.program
      : solarPrimaryProgramFilter;
  if (selectedRegion == _RankingsScreenState._allRegionsLabel) {
    return '$program | $fallbackGrade';
  }
  return '$program | $fallbackGrade | $selectedRegion';
}

String _seasonDisplayName(SeasonSummary season) {
  final name = season.name.trim();
  if (name.isNotEmpty) {
    return name;
  }
  final programName = season.programName.trim();
  if (programName.isNotEmpty) {
    return '$programName season';
  }
  return 'Season unavailable';
}

String _seasonDisplayNameFromId(List<SeasonSummary> seasons, int seasonId) {
  for (final season in seasons) {
    if (season.id == seasonId) {
      return _seasonDisplayName(season);
    }
  }
  return 'Season unavailable';
}

String _teamSubtitle(String primary, String secondary) {
  final normalizedPrimary = primary.trim();
  if (normalizedPrimary.isNotEmpty) {
    return normalizedPrimary;
  }
  final normalizedSecondary = secondary.trim();
  return normalizedSecondary;
}
