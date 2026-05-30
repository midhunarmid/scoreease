import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scoreease/features/scoreboard/domain/entities/access_entity.dart';
import 'package:scoreease/features/scoreboard/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/features/scoreboard/presentation/blocs/score_board_setup/score_board_setup_bloc.dart';
import 'package:scoreease/features/landing/presentation/pages/landing_screen.dart';
import 'package:scoreease/features/settings/presentation/pages/settings_screen.dart';
import 'package:scoreease/core/utils/constants.dart';
import 'package:scoreease/core/utils/input_case_text_formatter.dart';
import 'package:scoreease/core/utils/message_generator.dart';
import 'package:scoreease/core/utils/theme.dart';
import 'package:scoreease/core/utils/widget_helper.dart';
import 'package:scoreease/core/widgets/animated_container.dart';
import 'package:scoreease/core/widgets/web_optimised_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:progress_dialog_null_safe/progress_dialog_null_safe.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/widgets/scoreboard_setup_basic_stage.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/widgets/scoreboard_setup_roster_stage.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/widgets/scoreboard_setup_access_stage.dart';

class ScoreboardSetupScreen extends StatefulWidget {
  const ScoreboardSetupScreen({Key? key}) : super(key: key);
  static const routeName = 'setup';

  @override
  State<ScoreboardSetupScreen> createState() => _ScoreboardSetupScreenState();
}

class _ScoreboardSetupScreenState extends State<ScoreboardSetupScreen> {
  final TextEditingController _scoreboardIdTextController = TextEditingController();
  final TextEditingController _scoreboardTitleTextController = TextEditingController();
  final TextEditingController _scoreboardDescriptionTextController = TextEditingController();
  final TextEditingController _scoreboardAuthorTextController = TextEditingController();
  final TextEditingController _scoreboardAccessReadTextController = TextEditingController();
  final TextEditingController _scoreboardAccessWriteTextController = TextEditingController();

  final ScoreboardSetupBloc _bloc = ScoreboardSetupBloc();
  ProgressDialog? _pr;
  ScoreboardSetupStage _currentStage = ScoreboardSetupStage.basic;
  ScoreboardEntity _scoreboardEntity = const ScoreboardEntity();
  final List<String> _playerNameList = [];

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _scoreboardIdTextController.text = prefs.getString('draft_setup_id') ?? '';
      _scoreboardTitleTextController.text = prefs.getString('draft_setup_title') ?? '';
      _scoreboardDescriptionTextController.text = prefs.getString('draft_setup_description') ?? '';
      _scoreboardAuthorTextController.text = prefs.getString('draft_setup_author') ?? '';
      _scoreboardAccessReadTextController.text = prefs.getString('draft_setup_access_read') ?? '';
      _scoreboardAccessWriteTextController.text = prefs.getString('draft_setup_access_write') ?? '';
      
      final playersJson = prefs.getString('draft_setup_players');
      if (playersJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(playersJson);
          _playerNameList.clear();
          _playerNameList.addAll(decoded.map((e) => e.toString()));
        } catch (e) {
          appLogger.e("Failed to decode draft players", error: e);
        }
      }
    });
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('draft_setup_id', _scoreboardIdTextController.text);
    await prefs.setString('draft_setup_title', _scoreboardTitleTextController.text);
    await prefs.setString('draft_setup_description', _scoreboardDescriptionTextController.text);
    await prefs.setString('draft_setup_author', _scoreboardAuthorTextController.text);
    await prefs.setString('draft_setup_access_read', _scoreboardAccessReadTextController.text);
    await prefs.setString('draft_setup_access_write', _scoreboardAccessWriteTextController.text);
    await prefs.setString('draft_setup_players', jsonEncode(_playerNameList));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Draft saved successfully!"),
          backgroundColor: appColors.primaryColor,
          duration: const Duration(seconds: 2),
        ),
      );
      context.replace("/${LandingScreen.routeName}");
    }
  }

  void _onBackPressed() {
    showTwoButtonAlertDialog(
      context: context,
      title: "Save Draft?",
      message: "Do you want to save your progress as a draft before leaving?",
      positiveButton: "Save Draft",
      negativeButton: "Discard",
      positiveAction: _saveDraft,
      negativeAction: () {
        context.replace("/${LandingScreen.routeName}");
      },
    );
  }

  void _clearDraft() {
    showTwoButtonAlertDialog(
      context: context,
      title: "Clear Form",
      message: "Are you sure you want to clear the entire form and delete your draft?",
      positiveButton: "Clear",
      negativeButton: "Cancel",
      positiveAction: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('draft_setup_id');
        await prefs.remove('draft_setup_title');
        await prefs.remove('draft_setup_description');
        await prefs.remove('draft_setup_author');
        await prefs.remove('draft_setup_access_read');
        await prefs.remove('draft_setup_access_write');
        await prefs.remove('draft_setup_players');
        
        setState(() {
          _scoreboardIdTextController.clear();
          _scoreboardTitleTextController.clear();
          _scoreboardDescriptionTextController.clear();
          _scoreboardAuthorTextController.clear();
          _scoreboardAccessReadTextController.clear();
          _scoreboardAccessWriteTextController.clear();
          _playerNameList.clear();
          _currentStage = ScoreboardSetupStage.basic;
        });
      },
    );
  }

  @override
  void dispose() {
    _scoreboardIdTextController.dispose();
    _scoreboardTitleTextController.dispose();
    _scoreboardDescriptionTextController.dispose();
    _scoreboardAuthorTextController.dispose();
    _scoreboardAccessReadTextController.dispose();
    _scoreboardAccessWriteTextController.dispose();
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener(
      bloc: _bloc,
      listener: (ctx, state) {
        appLogger.i(state);

        if (_pr?.isShowing() ?? false) {
          _pr?.hide();
        }
        if (state is LoadingState) {
          _pr = ProgressDialog(
            context,
            type: ProgressDialogType.normal,
            isDismissible: false,
          );
          _pr?.style(
            backgroundColor: appColors.screenBg,
            padding: WebOptimisedWidget.getWebOptimisedHorizonatalPadding(),
            message: state.loadingInfo.message,
            widgetAboveTheDialog: Text(
              state.loadingInfo.title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            progressWidget: Padding(
              padding: const EdgeInsets.all(8.0),
              child: LoadingIndicator(
                indicatorType: Indicator.lineScalePulseOutRapid,
                colors: appColors.rainbowColors,
                strokeWidth: 2,
                backgroundColor: appColors.screenBg,
                pathBackgroundColor: appColors.screenBg,
              ),
            ),
            progressTextStyle: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w400),
            messageTextStyle: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w400),
          );
          _pr?.show();
        } else if (state is ScoreboardSetupErrorState) {
          showSingleButtonAlertDialog(context: context, title: state.title, message: state.message);
        } else if (state is ScoreboardSetupSuccessState) {
          showSingleButtonAlertDialog(
            context: context,
            dialogType: DialogType.success,
            title: MessageGenerator.getLabel('Success'),
            message: MessageGenerator.getLabel('Scoreboard created successfully!'),
            positiveAction: () => context.go("/${LandingScreen.routeName}"),
          );
        } else if (state is ScoreboardSetupBasicSuccessState) {
          _currentStage = ScoreboardSetupStage.players;
          _scoreboardEntity = state.scoreboardEntity;
        } else if (state is ScoreboardSetupPlayerNamesSuccessState) {
          _currentStage = ScoreboardSetupStage.access;
          _scoreboardEntity = state.scoreboardEntity;
        }
      },
      child: BlocBuilder<ScoreboardSetupBloc, ScoreboardSetupState>(
          bloc: _bloc,
          builder: (ctx, state) {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
                  onPressed: _onBackPressed,
                ),
                actions: [
                  TextButton.icon(
                    onPressed: _saveDraft,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text("Save Draft"),
                    style: TextButton.styleFrom(foregroundColor: appColors.primaryColor),
                  ),
                  IconButton(
                    tooltip: "Clear Form",
                    icon: const Icon(Icons.delete_sweep_outlined),
                    color: Colors.red.shade400,
                    onPressed: _clearDraft,
                  ),
                  IconButton(
                    tooltip: "Settings",
                    icon: const Icon(Icons.settings),
                    color: Theme.of(context).iconTheme.color,
                    onPressed: () {
                      context.go("/${SettingsScreen.routeName}");
                    },
                  ),
                ],
              ),
              body: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  width: maxScreenWidth,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(height: 32.h),
                        Text(
                          "SCOREBOARD SETUP",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: appColors.primaryColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ).animate().fade().scaleXY(begin: 0.9),
                        SizedBox(height: 32.h),
                        _buildProgressIndicator(),
                        SizedBox(height: 32.h),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.05, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: SizedBox(
                            key: ValueKey(_currentStage),
                            child: _buildCurrentStageWidget(context),
                          ),
                        ),
                        SizedBox(height: 24.h),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: Theme.of(context).textTheme.labelSmall,
                            children: <TextSpan>[
                              TextSpan(
                                  text: MessageGenerator.getLabel('Use Existing Scoreboard'),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.red),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = _onBackPressed),
                            ],
                          ),
                        ),
                        SizedBox(height: 32.h),
                        Linkify(
                          onOpen: (link) async {
                            if (!await launchUrl(Uri.parse(link.url))) {}
                          },
                          text: MessageGenerator.getMessage("landing-visit-site-guide"),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall,
                          linkStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: appColors.linkTextColor),
                        ),
                        SizedBox(height: 32.h),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepIcon(ScoreboardSetupStage.basic, Icons.info_outline, "Details"),
        _buildStepLine(ScoreboardSetupStage.players),
        _buildStepIcon(ScoreboardSetupStage.players, Icons.people_outline, "Roster"),
        _buildStepLine(ScoreboardSetupStage.access),
        _buildStepIcon(ScoreboardSetupStage.access, Icons.lock_outline, "Access"),
      ],
    );
  }

  Widget _buildStepLine(ScoreboardSetupStage targetStage) {
    bool isActive = _currentStage.index >= targetStage.index;
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? appColors.primaryColor : appColors.disableBgColor,
      ),
    );
  }

  Widget _buildStepIcon(ScoreboardSetupStage stage, IconData icon, String label) {
    bool isActive = _currentStage.index >= stage.index;
    bool isCurrent = _currentStage == stage;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive ? appColors.primaryColor : appColors.screenBg,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? appColors.primaryColor : appColors.disableBgColor,
              width: 2,
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: appColors.primaryColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : appColors.disableBgColor,
            size: 20.sp,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isActive ? appColors.primaryColor : appColors.disableBgColor,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
        ),
      ],
    );
  }

  Widget _buildCurrentStageWidget(BuildContext context) {
    switch (_currentStage) {
      case ScoreboardSetupStage.basic:
        return ScoreboardSetupBasicStage(
          idController: _scoreboardIdTextController,
          titleController: _scoreboardTitleTextController,
          descriptionController: _scoreboardDescriptionTextController,
          authorController: _scoreboardAuthorTextController,
          onNext: onScoreboardBasicNextButtonPressed,
        );
      case ScoreboardSetupStage.players:
        return ScoreboardSetupRosterStage(
          players: _playerNameList,
          onAddPlayer: (player) {
            setState(() {
              _playerNameList.add(player);
            });
          },
          onRemovePlayer: (player) {
            setState(() {
              _playerNameList.remove(player);
            });
          },
          onNext: onScoreboardPlayerNamesNextButtonPressed,
          onPrevious: () {
            setState(() {
              _currentStage = ScoreboardSetupStage.basic;
            });
          },
        );
      case ScoreboardSetupStage.access:
        return ScoreboardSetupAccessStage(
          readController: _scoreboardAccessReadTextController,
          writeController: _scoreboardAccessWriteTextController,
          onNext: onScoreboardAccessNextButtonPressed,
          onPrevious: () {
            setState(() {
              _currentStage = ScoreboardSetupStage.players;
            });
          },
        );
    }
  }

  void onScoreboardBasicNextButtonPressed() {
    ScoreboardEntity scoreboard = ScoreboardEntity(
      id: _scoreboardIdTextController.text,
      title: _scoreboardTitleTextController.text,
      description: _scoreboardDescriptionTextController.text,
      author: _scoreboardAuthorTextController.text,
      players: const {},
      access: const AccessEntity(
        read: "",
        write: "",
      ),
    );
    _bloc.add(ScoreboardSetupBasicSubmitEvent(scoreboard));
  }

  void onScoreboardPlayerNamesNextButtonPressed() {
    _scoreboardEntity = _scoreboardEntity.copyWith(
      players: _playerNameList.asMap().map((index, player) => MapEntry(player, 0)),
    );
    _bloc.add(ScoreboardSetupPlayerNamesSubmitEvent(_scoreboardEntity));
  }

  void onScoreboardAccessNextButtonPressed() {
    _scoreboardEntity = _scoreboardEntity.copyWith(
      access: AccessEntity(
        read: _scoreboardAccessReadTextController.text,
        write: _scoreboardAccessWriteTextController.text,
      ),
    );
    _bloc.add(ScoreboardSetupFinalSubmitEvent(_scoreboardEntity));
  }
}

enum ScoreboardSetupStage {
  basic,
  players,
  access,
}
