import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_session_controller.dart';
import '../../app/solar_app_scope.dart';
import '../../models/open_skill_models.dart';
import '../../models/robot_events_models.dart';
import '../../models/world_skills_models.dart';
import '../models/solar_ml_ranking.dart';
import '../services/solar_ml_ranking_service.dart';
import '../widgets/solar_navigation.dart';
import '../widgets/solar_screen_background.dart';
import '../widgets/solar_team_link.dart';
import 'sign_in_screen.dart';

enum _RankingsMode { skill, solarMl }

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  static const routeName = '/rankings';

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  static const _allRegionsLabel = 'All Regions';
  static const _gradeOptions = <String>[
    'High School',
    'Middle School',
    'College',
  ];

  final TextEditingController _searchController = TextEditingController();
  static const _solarMlService = SolarMlRankingService();

  AppSessionController? _sessionController;
  bool _searchVisible = false;
  bool _isBootstrapping = true;
  bool _isLoadingRankings = false;
  int _loadGeneration = 0;
  List<SeasonSummary> _availableSeasons = const <SeasonSummary>[];
  List<WorldSkillsEntry> _activeRankings = const <WorldSkillsEntry>[];
  List<OpenSkillCacheEntry> _openSkillEntries = const <OpenSkillCacheEntry>[];
  int? _selectedSeasonId;
  String? _selectedGradeLevel;
  String _selectedRegion = _allRegionsLabel;
  _RankingsMode _mode = _RankingsMode.skill;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = SolarAppScope.of(context);
    if (!identical(_sessionController, controller)) {
      _sessionController = controller;
      unawaited(_bootstrapFilters(controller, forceSeasons: false));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapFilters(
    AppSessionController controller, {
    required bool forceSeasons,
  }) async {
    final generation = ++_loadGeneration;

    setState(() {
      _isBootstrapping = true;
    });

    final seasons = await controller.fetchWorldSkillsSeasons(
      programFilter: 'V5RC',
      force: forceSeasons,
    );
    final defaultSeasonId = await controller
        .resolveDefaultWorldSkillsSeasonId();
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
    });

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
    });

    final results = await Future.wait<Object>(<Future<Object>>[
      controller
          .fetchWorldSkillsRankings(
            seasonId: seasonId,
            gradeLevel: gradeLevel,
            force: force,
          )
          .then<Object>((value) => value),
      controller
          .fetchOpenSkillRankings(
            seasonId: seasonId,
            gradeLevel: gradeLevel,
            force: force,
          )
          .then<Object>((value) => value),
    ]);

    if (!_isCurrentLoad(controller, generation)) {
      return;
    }

    final entries = results[0] as List<WorldSkillsEntry>;
    final openSkillEntries = results[1] as List<OpenSkillCacheEntry>;
    final regions = _regionOptions(entries);
    setState(() {
      _activeRankings = entries;
      _openSkillEntries = openSkillEntries;
      _isLoadingRankings = false;
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
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _availableSeasons
                              .take(8)
                              .map((season) {
                                return _FilterChip(
                                  label: _seasonDisplayName(season),
                                  selected: tempSeasonId == season.id,
                                  onTap: () {
                                    setModalState(() {
                                      tempSeasonId = season.id;
                                    });
                                  },
                                );
                              })
                              .toList(growable: false),
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
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: regionOptions
                              .map((region) {
                                return _FilterChip(
                                  label: region,
                                  selected: tempRegion == region,
                                  onTap: () {
                                    setModalState(() {
                                      tempRegion = region;
                                    });
                                  },
                                );
                              })
                              .toList(growable: false),
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

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchController.clear();
      }
    });
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

        final regionFilteredEntries = _selectedRegion == _allRegionsLabel
            ? _activeRankings
            : _activeRankings
                  .where((entry) {
                    return _regionLabel(entry) == _selectedRegion;
                  })
                  .toList(growable: false);
        final filteredEntries = _filterEntries(
          entries: regionFilteredEntries,
          query: _searchController.text,
        );
        final mlEntries = _solarMlService.build(
          worldSkills: regionFilteredEntries,
          openSkillEntries: _openSkillEntries,
        );
        final filteredMlEntries = _filterSolarMlEntries(
          entries: mlEntries,
          query: _searchController.text,
        );
        final activeRowCount = _mode == _RankingsMode.skill
            ? filteredEntries.length
            : filteredMlEntries.length;
        final topInset = MediaQuery.paddingOf(context).top;
        final showStatusCard =
            _isBootstrapping || _isLoadingRankings || activeRowCount == 0;
        final listItemCount = showStatusCard ? 3 : activeRowCount + 2;

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
                  SignInScreen.routeName,
                  (route) => false,
                );
              },
            ),
            body: SolarScreenBackground(
              padding: EdgeInsets.zero,
              respectSafeArea: false,
              child: RefreshIndicator(
                color: Colors.black,
                onRefresh: () async {
                  await controller.refreshTeamStats();
                  await _bootstrapFilters(controller, forceSeasons: true);
                },
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 164),
                  itemCount: listItemCount,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _RankingsHeader(
                        topInset: topInset,
                        filterLabel: _filterLabel(
                          entries: _activeRankings,
                          fallbackGrade:
                              _selectedGradeLevel ??
                              controller.defaultWorldSkillsGradeLevel,
                          selectedRegion: _selectedRegion,
                        ),
                        seasonLabel: _selectedSeasonId == null
                            ? 'Season loading'
                            : _seasonDisplayNameFromId(
                                _availableSeasons,
                                _selectedSeasonId!,
                              ),
                        searchVisible: _searchVisible,
                        searchController: _searchController,
                        onSearchChanged: (_) => setState(() {}),
                        onSearchTap: _toggleSearch,
                        onFilterTap: () => _showFilterSheet(controller),
                        onMoreTap: () => _showFilterSheet(controller),
                        mode: _mode,
                        onSkillTap: () {
                          setState(() {
                            _mode = _RankingsMode.skill;
                          });
                        },
                        onSolarMlTap: () {
                          setState(() {
                            _mode = _RankingsMode.solarMl;
                          });
                        },
                      );
                    }

                    if (index == 1) {
                      return const SizedBox(height: 24);
                    }

                    if (showStatusCard) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: _isBootstrapping || _isLoadingRankings
                            ? const _RankingsStatusCard.loading()
                            : _RankingsStatusCard.message(
                                _searchController.text.trim().isEmpty
                                    ? 'World skills rankings will appear here after the API data finishes loading.'
                                    : 'No ranked teams matched "${_searchController.text.trim()}".',
                              ),
                      );
                    }

                    if (_mode == _RankingsMode.skill) {
                      final entry = filteredEntries[index - 2];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: _RankingRow(
                          entry: entry,
                          highlighted:
                              entry.teamNumber.trim().toUpperCase() ==
                              account.team.number.trim().toUpperCase(),
                          showDivider: index - 2 != filteredEntries.length - 1,
                        ),
                      );
                    }

                    final entry = filteredMlEntries[index - 2];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: _SolarMlRankingRow(
                        entry: entry,
                        highlighted:
                            entry.teamNumber.trim().toUpperCase() ==
                            account.team.number.trim().toUpperCase(),
                        showDivider: index - 2 != filteredMlEntries.length - 1,
                      ),
                    );
                  },
                ),
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
    required this.filterLabel,
    required this.seasonLabel,
    required this.searchVisible,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchTap,
    required this.onFilterTap,
    required this.onMoreTap,
    required this.mode,
    required this.onSkillTap,
    required this.onSolarMlTap,
  });

  final double topInset;
  final String filterLabel;
  final String seasonLabel;
  final bool searchVisible;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchTap;
  final VoidCallback onFilterTap;
  final VoidCallback onMoreTap;
  final _RankingsMode mode;
  final VoidCallback onSkillTap;
  final VoidCallback onSolarMlTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, topInset + 16, 24, 26),
      decoration: const BoxDecoration(
        color: Colors.black,
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
              _HeaderIconButton(icon: Icons.search_rounded, onTap: onSearchTap),
              const SizedBox(width: 8),
              _HeaderIconButton(
                icon: Icons.more_vert_rounded,
                onTap: onMoreTap,
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: searchVisible
                ? Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: TextField(
                        key: const ValueKey<String>('rankings-search-field'),
                        controller: searchController,
                        onChanged: onSearchChanged,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
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
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: onFilterTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        filterLabel,
                        style: const TextStyle(
                          color: Color(0xFF16182C),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        seasonLabel,
                        style: const TextStyle(
                          color: Color(0xFF71758B),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: InkWell(
                    onTap: onSkillTap,
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: mode == _RankingsMode.skill
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'SKILL',
                        style: TextStyle(
                          color: mode == _RankingsMode.skill
                              ? const Color(0xFF16182C)
                              : Colors.white.withValues(alpha: 0.42),
                          fontSize: 16,
                          fontWeight: mode == _RankingsMode.skill
                              ? FontWeight.w600
                              : FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: onSolarMlTap,
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: mode == _RankingsMode.solarMl
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'SOLAR ML',
                        style: TextStyle(
                          color: mode == _RankingsMode.solarMl
                              ? const Color(0xFF16182C)
                              : Colors.white.withValues(alpha: 0.42),
                          fontSize: 16,
                          fontWeight: mode == _RankingsMode.solarMl
                              ? FontWeight.w600
                              : FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
  const _RankingsStatusCard.loading() : message = null, loading = true;

  const _RankingsStatusCard.message(this.message) : loading = false;

  final String? message;
  final bool loading;

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
          : Text(
              message!,
              style: const TextStyle(
                color: Color(0xFF6F748B),
                fontSize: 15,
                height: 1.45,
              ),
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
                child: SolarTeamLinkText(
                  teamNumber: entry.teamNumber,
                  teamId: entry.teamId,
                  teamName: entry.teamName,
                  organization: entry.organization,
                  maxLines: 1,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 24,
                    fontWeight: highlighted ? FontWeight.w500 : FontWeight.w300,
                    letterSpacing: -1.2,
                  ),
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
                      label: 'A',
                      value: entry.maxProgrammingScore,
                      icon: Icons.memory_rounded,
                    ),
                    const SizedBox(height: 4),
                    _MiniScoreLine(
                      label: 'D',
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

class _SolarMlRankingRow extends StatelessWidget {
  const _SolarMlRankingRow({
    required this.entry,
    required this.highlighted,
    required this.showDivider,
  });

  final SolarMlRankingEntry entry;
  final bool highlighted;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final labelColor = highlighted
        ? const Color(0xFF2930FF)
        : const Color(0xFF16182C);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
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
                      fontSize: 32,
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
                        fontSize: 26,
                        fontWeight: highlighted
                            ? FontWeight.w500
                            : FontWeight.w300,
                        letterSpacing: -1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ceiling ${entry.ceilingScore.toStringAsFixed(0)}  •  Win ${entry.projectedWinShare.toStringAsFixed(0)}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF707487),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    entry.mlRating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Color(0xFF64677A),
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -0.9,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Stab ${entry.stability.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF707487),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (showDivider) ...<Widget>[
            const SizedBox(height: 14),
            Container(height: 1, color: const Color(0xFFDADAE3)),
          ],
        ],
      ),
    );
  }
}

class _MiniScoreLine extends StatelessWidget {
  const _MiniScoreLine({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Text(
          '$label$value',
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

List<SolarMlRankingEntry> _filterSolarMlEntries({
  required List<SolarMlRankingEntry> entries,
  required String query,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return entries;
  }

  return entries
      .where((entry) {
        final haystack = <String>[
          entry.teamNumber,
          entry.teamName,
          entry.organization,
          entry.city,
          entry.region,
          entry.country,
        ].join(' ').toLowerCase();
        return haystack.contains(normalizedQuery);
      })
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
  final program = entries.isNotEmpty ? entries.first.program : 'V5RC';
  if (selectedRegion == _RankingsScreenState._allRegionsLabel) {
    return '$program | $fallbackGrade';
  }
  return '$program | $fallbackGrade | $selectedRegion';
}

String _seasonDisplayName(SeasonSummary season) {
  final name = season.name.trim();
  if (name.isEmpty) {
    return '${season.programName} ${season.id}';
  }
  return name.length > 26 ? '${name.substring(0, 26)}…' : name;
}

String _seasonDisplayNameFromId(List<SeasonSummary> seasons, int seasonId) {
  for (final season in seasons) {
    if (season.id == seasonId) {
      return _seasonDisplayName(season);
    }
  }
  return 'Season $seasonId';
}
