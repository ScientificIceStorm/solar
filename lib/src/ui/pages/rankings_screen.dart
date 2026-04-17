import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_session_controller.dart';
import '../../app/solar_app_scope.dart';
import '../../core/solar_competition_scope.dart';
import '../../models/robot_events_models.dart';
import '../../models/world_skills_models.dart';
import '../models/solar_ml_ranking.dart';
import '../services/solar_ml_ranking_service.dart';
import '../services/solar_disk_cache_store.dart';
import '../widgets/solar_navigation.dart';
import '../widgets/solar_screen_background.dart';
import '../widgets/solar_team_link.dart';
import 'onboarding_screen.dart';

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
  ];

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  static const _solarMlService = SolarMlRankingService();
  static final _diskCacheStore = SolarDiskCacheStore.instance;

  AppSessionController? _sessionController;
  bool _searchVisible = false;
  bool _isBootstrapping = true;
  bool _isLoadingRankings = false;
  bool _isLoadingSolarize = false;
  int _loadGeneration = 0;
  List<SeasonSummary> _availableSeasons = const <SeasonSummary>[];
  List<WorldSkillsEntry> _activeRankings = const <WorldSkillsEntry>[];
  List<SolarMlRankingEntry> _solarMlEntries = const <SolarMlRankingEntry>[];
  int? _selectedSeasonId;
  String? _selectedGradeLevel;
  String _selectedRegion = _allRegionsLabel;
  _RankingsMode _mode = _RankingsMode.skill;
  String? _loadedSolarizeCacheKey;
  bool _showPinnedHeroBar = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScrollOffset);
  }

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
    _scrollController.removeListener(_handleScrollOffset);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleScrollOffset() {
    if (!_scrollController.hasClients) {
      return;
    }

    final shouldShow = _scrollController.offset > 110;
    if (shouldShow == _showPinnedHeroBar || !mounted) {
      return;
    }

    setState(() {
      _showPinnedHeroBar = shouldShow;
    });
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
      programFilter: solarPrimaryProgramFilter,
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
        _solarMlEntries = const <SolarMlRankingEntry>[];
        _isLoadingRankings = false;
        _isLoadingSolarize = false;
        _loadedSolarizeCacheKey = null;
      });
      return;
    }

    setState(() {
      _isLoadingRankings = true;
      _isLoadingSolarize = false;
      _activeRankings = const <WorldSkillsEntry>[];
      _solarMlEntries = const <SolarMlRankingEntry>[];
      _loadedSolarizeCacheKey = null;
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
      if (!regions.contains(_selectedRegion)) {
        _selectedRegion = _allRegionsLabel;
      }
    });

    unawaited(
      _warmSolarizeRankings(
        controller,
        generation: generation,
        seasonId: seasonId,
        gradeLevel: gradeLevel,
        entries: entries,
        force: force,
      ),
    );
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
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Skill uses the official World Skills list from REC Foundation.',
                ),
                SizedBox(height: 12),
                Text(
                  'Solarize uses match history only. Recent form, opponent strength, elimination rounds, and event strength matter more than old qualifier-only results.',
                ),
                SizedBox(height: 12),
                Text(
                  'Recent results count more than old ones, and one-off disaster matches are damped so a disconnect or broken robot does not nuke a team unfairly.',
                ),
                SizedBox(height: 12),
                Text(
                  'Official skills are not part of this ranking, and the list only shows rank, team, and rating.',
                ),
              ],
            ),
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

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchController.clear();
      }
    });
  }

  Future<void> _warmSolarizeRankings(
    AppSessionController controller, {
    required int generation,
    required int seasonId,
    required String gradeLevel,
    required List<WorldSkillsEntry> entries,
    required bool force,
  }) async {
    final cacheKey = '$seasonId|${gradeLevel.trim().toLowerCase()}';
    final cachedEntries = await _diskCacheStore.readList<SolarMlRankingEntry>(
      namespace: 'solar_ml_screen_rankings_v2',
      key: cacheKey,
      fromJson: SolarMlRankingEntry.fromJson,
    );
    final usableCachedEntries =
        cachedEntries != null && _isUsableSolarMlEntries(cachedEntries)
        ? cachedEntries
        : null;
    if (cachedEntries != null && usableCachedEntries == null) {
      await _diskCacheStore.clear('solar_ml_screen_rankings_v2', cacheKey);
    }
    if (usableCachedEntries != null &&
        usableCachedEntries.isNotEmpty &&
        _isCurrentLoad(controller, generation)) {
      setState(() {
        _solarMlEntries = usableCachedEntries;
        _isLoadingSolarize = false;
        _loadedSolarizeCacheKey = cacheKey;
      });
      if (!force) {
        return;
      }
    }
    if (!force &&
        _loadedSolarizeCacheKey == cacheKey &&
        _solarMlEntries.isNotEmpty) {
      return;
    }

    if (!_isCurrentLoad(controller, generation)) {
      return;
    }

    setState(() {
      _isLoadingSolarize = true;
    });

    final openSkillEntries = await controller.fetchOpenSkillRankings(
      seasonId: seasonId,
      gradeLevel: gradeLevel,
      force: force,
    );

    if (!_isCurrentLoad(controller, generation)) {
      return;
    }

    if (openSkillEntries.isEmpty &&
        usableCachedEntries != null &&
        usableCachedEntries.isNotEmpty) {
      setState(() {
        _solarMlEntries = usableCachedEntries;
        _isLoadingSolarize = false;
        _loadedSolarizeCacheKey = cacheKey;
      });
      return;
    }

    final solarMlEntries = _solarMlService.build(
      worldSkills: entries,
      openSkillEntries: openSkillEntries,
    );

    if (!_isCurrentLoad(controller, generation)) {
      return;
    }

    setState(() {
      _solarMlEntries = solarMlEntries;
      _isLoadingSolarize = false;
      _loadedSolarizeCacheKey = cacheKey;
    });
    if (solarMlEntries.isNotEmpty) {
      await _diskCacheStore.writeList<SolarMlRankingEntry>(
        namespace: 'solar_ml_screen_rankings_v2',
        key: cacheKey,
        items: solarMlEntries,
        toJson: (item) => item.toJson(),
        ttl: _dailyCacheTtl(),
      );
    }
  }

  Duration _dailyCacheTtl() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
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

        final filteredEntries = _mode == _RankingsMode.skill
            ? _filterEntries(
                entries: _filterEntriesByRegion(
                  entries: _activeRankings,
                  selectedRegion: _selectedRegion,
                ),
                query: _searchController.text,
              )
            : const <WorldSkillsEntry>[];
        final solarRegionTeamNumbers =
            _mode == _RankingsMode.solarMl &&
                _selectedRegion != _allRegionsLabel
            ? <String>{
                for (final ranking in _activeRankings)
                  if (_regionLabel(ranking) == _selectedRegion)
                    ranking.teamNumber.trim().toUpperCase(),
              }
            : null;
        final filteredMlEntries = _mode == _RankingsMode.solarMl
            ? _filterSolarMlEntries(
                entries: solarRegionTeamNumbers == null
                    ? _solarMlEntries
                    : _solarMlEntries
                          .where((entry) {
                            return solarRegionTeamNumbers.contains(
                              entry.teamNumber.trim().toUpperCase(),
                            );
                          })
                          .toList(growable: false),
                query: _searchController.text,
              )
            : const <SolarMlRankingEntry>[];
        final activeRowCount = _mode == _RankingsMode.skill
            ? filteredEntries.length
            : filteredMlEntries.length;
        final topInset = MediaQuery.paddingOf(context).top;
        final showStatusCard =
            _isBootstrapping ||
            _isLoadingRankings ||
            (_mode == _RankingsMode.solarMl && _isLoadingSolarize) ||
            activeRowCount == 0;
        final listItemCount = showStatusCard ? 3 : activeRowCount + 2;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            extendBody: true,
            backgroundColor: Colors.black,
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
                    color: Colors.black,
                    onRefresh: () async {
                      await controller.refreshTeamStats();
                      await _bootstrapFilters(controller, forceSeasons: true);
                    },
                    child: StretchingOverscrollIndicator(
                      axisDirection: AxisDirection.down,
                      child: ListView.builder(
                        controller: _scrollController,
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
                              onInfoTap: _showRankingSystemDialog,
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
                                final seasonId = _selectedSeasonId;
                                if (seasonId != null &&
                                    _activeRankings.isNotEmpty) {
                                  unawaited(
                                    _warmSolarizeRankings(
                                      controller,
                                      generation: _loadGeneration,
                                      seasonId: seasonId,
                                      gradeLevel:
                                          _selectedGradeLevel ??
                                          controller
                                              .defaultWorldSkillsGradeLevel,
                                      entries: _activeRankings,
                                      force: false,
                                    ),
                                  );
                                }
                              },
                            );
                          }

                          if (index == 1) {
                            return const SizedBox(height: 24);
                          }

                          if (showStatusCard) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 22),
                              child:
                                  _isBootstrapping ||
                                      _isLoadingRankings ||
                                      (_mode == _RankingsMode.solarMl &&
                                          _isLoadingSolarize)
                                  ? const _RankingsStatusCard.loading()
                                  : _RankingsStatusCard.message(
                                      _searchController.text.trim().isEmpty
                                          ? _mode == _RankingsMode.skill
                                                ? 'World skills rankings will appear here after the API data finishes loading.'
                                                : 'Solarize rankings are still being prepared from match history and season form.'
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
                                showDivider:
                                    index - 2 != filteredEntries.length - 1,
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
                              showDivider:
                                  index - 2 != filteredMlEntries.length - 1,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  IgnorePointer(
                    ignoring: !_showPinnedHeroBar,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      opacity: _showPinnedHeroBar ? 1 : 0,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(18, topInset + 8, 18, 0),
                        child: _RankingsPinnedHeroBar(
                          mode: _mode,
                          onFilterTap: () => _showFilterSheet(controller),
                          onSearchTap: _toggleSearch,
                        ),
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
    required this.filterLabel,
    required this.seasonLabel,
    required this.searchVisible,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchTap,
    required this.onInfoTap,
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
  final VoidCallback onInfoTap;
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
              _HeaderIconButton(icon: Icons.help_outline_rounded, onTap: onInfoTap),
              const SizedBox(width: 8),
              _HeaderIconButton(
                icon: Icons.more_vert_rounded,
                onTap: onMoreTap,
              ),
            ],
          ),
          if (searchVisible)
            Padding(
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
                        solarizeLabel.toUpperCase(),
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

class _RankingsPinnedHeroBar extends StatelessWidget {
  const _RankingsPinnedHeroBar({
    required this.mode,
    required this.onFilterTap,
    required this.onSearchTap,
  });

  final _RankingsMode mode;
  final VoidCallback onFilterTap;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: <Widget>[
          const Text(
            'Rankings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              mode == _RankingsMode.skill ? 'SKILL' : solarizeLabel.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const Spacer(),
          _HeaderIconButton(icon: Icons.search_rounded, onTap: onSearchTap),
          const SizedBox(width: 8),
          _HeaderIconButton(icon: Icons.tune_rounded, onTap: onFilterTap),
        ],
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
    final subtitle = _teamSubtitle(entry.teamName, entry.organization);

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    entry.solarRating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Color(0xFF64677A),
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -0.9,
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
  if (name.isEmpty) {
    return '${season.programName} ${season.id}';
  }
  return name;
}

String _seasonDisplayNameFromId(List<SeasonSummary> seasons, int seasonId) {
  for (final season in seasons) {
    if (season.id == seasonId) {
      return _seasonDisplayName(season);
    }
  }
  return 'Season $seasonId';
}

String _teamSubtitle(String primary, String secondary) {
  final normalizedPrimary = primary.trim();
  if (normalizedPrimary.isNotEmpty) {
    return normalizedPrimary;
  }
  final normalizedSecondary = secondary.trim();
  return normalizedSecondary;
}

bool _isUsableSolarMlEntries(List<SolarMlRankingEntry> entries) {
  if (entries.isEmpty) {
    return true;
  }

  final sample = entries.take(16).toList(growable: false);
  final validCount = sample.where((entry) {
    return entry.rank > 0 &&
        entry.teamId > 0 &&
        entry.teamNumber.trim().isNotEmpty &&
        (entry.teamName.trim().isNotEmpty || entry.organization.trim().isNotEmpty);
  }).length;
  final distinctRatings = sample
      .map((entry) => entry.solarRating.toStringAsFixed(2))
      .toSet()
      .length;

  if (validCount < (sample.length / 2).ceil()) {
    return false;
  }
  if (sample.length >= 8 && distinctRatings < 4) {
    return false;
  }
  return true;
}
