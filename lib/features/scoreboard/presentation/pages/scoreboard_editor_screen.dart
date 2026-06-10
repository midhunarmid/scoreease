import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:progress_dialog_null_safe/progress_dialog_null_safe.dart';
import 'package:scoreease/core/utils/constants.dart';

import 'package:scoreease/core/utils/theme.dart';
import 'package:scoreease/core/utils/widget_helper.dart';
import 'package:scoreease/core/widgets/web_optimised_widget.dart';
import 'package:scoreease/features/scoreboard/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/features/scoreboard/domain/entities/team_entity.dart';
import 'package:scoreease/features/scoreboard/domain/entities/access_entity.dart';
import 'package:scoreease/features/scoreboard/presentation/blocs/score_board_setup/score_board_setup_bloc.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/scoreboard_update_screen.dart';
import 'package:scoreease/core/utils/security_helper.dart';
import 'package:scoreease/core/widgets/password_prompt_widget.dart';
import 'package:scoreease/core/utils/global.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ScoreboardEditorScreen extends StatefulWidget {
  final String id;
  final ScoreboardEntity? scoreboardEntity;
  const ScoreboardEditorScreen(this.id, this.scoreboardEntity, {Key? key}) : super(key: key);
  static const routeName = 'edit';

  @override
  State<ScoreboardEditorScreen> createState() => _ScoreboardEditorScreenState();
}

class _ScoreboardEditorScreenState extends State<ScoreboardEditorScreen> {
  final ScoreboardSetupBloc _bloc = ScoreboardSetupBloc();
  ProgressDialog? _pr;
  
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _authorController;
  
  late TextEditingController _readAccessController;
  late TextEditingController _writeAccessController;
  late TextEditingController _ownerAccessController;

  bool _removeReadAccess = false;
  bool _removeWriteAccess = false;
  bool _removeOwnerAccess = false;
  
  final Map<String, int> _playersMap = {};
  final Map<String, TeamEntity> _teamsMap = {};
  final TextEditingController _teamTextController = TextEditingController();
  final Map<String, TextEditingController> _playerControllers = {};
  final Map<String, FocusNode> _playerFocusNodes = {};

  ScoreboardEntity? _scoreboardEntity;
  bool _isOwnerUnlocked = false;
  bool _isLoadingAccess = true;

  @override
  void initState() {
    super.initState();
    _scoreboardEntity = widget.scoreboardEntity;
    
    _checkSavedAccess();

    if (_scoreboardEntity != null) {
      _initControllers();
    } else {
      _bloc.add(ScoreboardGetEvent(widget.id));
    }
  }

  Future<void> _checkSavedAccess() async {
    final hasOwnerAccess = await GlobalValues.hasScoreboardAccess(scoreboardId: widget.id, type: 'owner');
    if (mounted) {
      setState(() {
        _isOwnerUnlocked = hasOwnerAccess;
        _isLoadingAccess = false;
      });
    }
  }

  void _initControllers() {
    _titleController = TextEditingController(text: _scoreboardEntity!.title);
    _descriptionController = TextEditingController(text: _scoreboardEntity!.description);
    _authorController = TextEditingController(text: _scoreboardEntity!.author);
    
    _readAccessController = TextEditingController();
    _writeAccessController = TextEditingController();
    _ownerAccessController = TextEditingController();

    if (_scoreboardEntity!.teams != null) {
      _teamsMap.addAll(_scoreboardEntity!.teams!);
    }
    if (_scoreboardEntity!.players != null) {
      _playersMap.addAll(_scoreboardEntity!.players!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _authorController.dispose();
    _readAccessController.dispose();
    _writeAccessController.dispose();
    _ownerAccessController.dispose();
    _teamTextController.dispose();
    for (var controller in _playerControllers.values) {
      controller.dispose();
    }
    for (var node in _playerFocusNodes.values) {
      node.dispose();
    }
    _bloc.close();
    super.dispose();
  }

  void _saveChanges() {
    if (_titleController.text.trim().isEmpty) {
      showSingleButtonAlertDialog(
        context: context,
        title: "Error",
        message: "Scoreboard Title cannot be empty.",
      );
      return;
    }

    final oldAccess = _scoreboardEntity!.access;
    final String? newRead = _removeReadAccess ? "" : (_readAccessController.text.isNotEmpty ? SecurityHelper.hashPassword(_readAccessController.text) : oldAccess?.read);
    final String? newWrite = _removeWriteAccess ? "" : (_writeAccessController.text.isNotEmpty ? SecurityHelper.hashPassword(_writeAccessController.text) : oldAccess?.write);
    final String? newOwner = _removeOwnerAccess ? "" : (_ownerAccessController.text.isNotEmpty ? SecurityHelper.hashPassword(_ownerAccessController.text) : oldAccess?.owner);

    final updatedAccess = AccessEntity(
       read: newRead,
       write: newWrite,
       owner: newOwner,
    );

    final updatedEntity = _scoreboardEntity!.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      author: _authorController.text.trim(),
      players: _playersMap,
      teams: _scoreboardEntity!.isTeamGame == true ? _teamsMap : _scoreboardEntity!.teams,
      access: updatedAccess,
    );

    _bloc.add(ScoreboardUpdateDetailsEvent(updatedEntity));
  }

  void _addPlayer() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Add Player", style: Theme.of(ctx).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: "Player Name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: appColors.pleasantButtonBg),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty && !_playersMap.containsKey(name)) {
                setState(() {
                  _playersMap[name] = 0;
                });
                Navigator.pop(ctx);
              } else if (_playersMap.containsKey(name)) {
                showSingleButtonAlertDialog(context: context, title: "Error", message: "Player already exists.");
              }
            },
            child: Text("Add", style: TextStyle(color: appColors.buttonTextColor)),
          ),
        ],
      ),
    );
  }

  void _addTeam() {
    final newTeam = _teamTextController.text.trim();
    if (newTeam.isNotEmpty) {
      if (_teamsMap.containsKey(newTeam)) {
        showSingleButtonAlertDialog(context: context, title: "Error", message: "Team already exists.");
      } else {
        setState(() {
          _teamsMap[newTeam] = TeamEntity(name: newTeam, players: const {});
        });
        _teamTextController.clear();
      }
    }
  }

  void _removeTeam(String team) {
    showTwoButtonAlertDialog(
      context: context,
      title: "Delete Team",
      message: "Are you sure you want to delete $team and all its players?",
      positiveButton: "Delete",
      negativeButton: "Cancel",
      positiveAction: () {
        setState(() {
          final teamData = _teamsMap[team];
          if (teamData != null && teamData.players.isNotEmpty) {
             for (var player in teamData.players.keys) {
               _playersMap.remove(player);
             }
          }
          _teamsMap.remove(team);
        });
      },
    );
  }

  void _addPlayerToTeam(String teamName) {
    if (!_playerControllers.containsKey(teamName)) return;
    final controller = _playerControllers[teamName]!;
    final newPlayer = controller.text.trim();
    if (newPlayer.isNotEmpty) {
      bool playerExists = _playersMap.containsKey(newPlayer);
      if (playerExists) {
        showSingleButtonAlertDialog(context: context, title: "Error", message: "Player already exists.");
      } else {
        setState(() {
          _playersMap[newPlayer] = 0;
          final team = _teamsMap[teamName]!;
          final updatedPlayers = Map<String, bool>.from(team.players)..putIfAbsent(newPlayer, () => true);
          _teamsMap[teamName] = team.copyWith(players: updatedPlayers);
        });
        controller.clear();
      }
    }
  }

  void _removePlayerFromTeam(String teamName, String player) {
    showTwoButtonAlertDialog(
      context: context,
      title: "Delete Player",
      message: "Are you sure you want to delete $player?",
      positiveButton: "Delete",
      negativeButton: "Cancel",
      positiveAction: () {
        setState(() {
          _playersMap.remove(player);
          final team = _teamsMap[teamName]!;
          final updatedPlayers = Map<String, bool>.from(team.players)..remove(player);
          _teamsMap[teamName] = team.copyWith(players: updatedPlayers);
        });
      },
    );
  }

  void _editPlayerInTeam(String teamName, String oldPlayer) {
    final controller = TextEditingController(text: oldPlayer);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit Player Name", style: Theme.of(ctx).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: "New Player Name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: appColors.pleasantButtonBg),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != oldPlayer) {
                if (_playersMap.containsKey(newName)) {
                  showSingleButtonAlertDialog(context: context, title: "Error", message: "Player already exists.");
                  return;
                }
                setState(() {
                  final score = _playersMap[oldPlayer] ?? 0;
                  _playersMap.remove(oldPlayer);
                  _playersMap[newName] = score;

                  final team = _teamsMap[teamName]!;
                  final updatedPlayers = Map<String, bool>.from(team.players);
                  updatedPlayers.remove(oldPlayer);
                  updatedPlayers[newName] = true;
                  _teamsMap[teamName] = team.copyWith(players: updatedPlayers);
                });
                Navigator.pop(ctx);
              } else {
                Navigator.pop(ctx);
              }
            },
            child: Text("Save", style: TextStyle(color: appColors.buttonTextColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required String label, 
    required TextEditingController controller, 
    required bool removeFlag, 
    required Function(bool?) onChanged
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        getTextInputWidget(
          context: context,
          label: label,
          hint: removeFlag ? "Password removed" : "Leave empty to keep existing",
          controller: controller,
          prefixIcon: const Icon(Icons.lock_outline),
          enabled: !removeFlag,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text("Remove $label Access", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: removeFlag ? Colors.red : null)),
              Checkbox(
                value: removeFlag,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionContainer({required String title, required List<Widget> children, IconData? icon, Widget? action}) {
    return Container(
      margin: EdgeInsets.only(bottom: 24.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: appColors.primaryColor.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: appColors.primaryColor, size: 20.sp),
                  SizedBox(width: 8.w),
                ],
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: appColors.primaryColor)),
                const Spacer(),
                if (action != null) action,
              ],
            ),
          ),
          Divider(height: 1, color: appColors.primaryColor.withValues(alpha: 0.1)),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(String teamName, Map<String, bool> players) {
    if (!_playerControllers.containsKey(teamName)) {
      _playerControllers[teamName] = TextEditingController();
      _playerFocusNodes[teamName] = FocusNode();
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: appColors.primaryColor.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: appColors.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield, color: appColors.primaryColor, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(
                      teamName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeTeam(teamName),
                  tooltip: "Remove Team",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              children: [
                getTextInputWidget(
                  context: context,
                  label: 'Add Player to $teamName',
                  hint: 'Player Name',
                  controller: _playerControllers[teamName]!,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.go,
                  prefixIcon: const Icon(Icons.person_add_alt_1_outlined),
                  icon: Icons.add,
                  focusNode: _playerFocusNodes[teamName],
                  onPressed: () => _addPlayerToTeam(teamName),
                ),
                SizedBox(height: 12.h),
                if (players.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "No players in this team yet.",
                      style: TextStyle(
                        color: appColors.textColor.withValues(alpha: 0.5),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: players.keys.map((player) {
                      return InputChip(
                        label: Text(player),
                        onPressed: () => _editPlayerInTeam(teamName, player),
                        deleteIcon: const Icon(Icons.cancel, size: 18),
                        onDeleted: () => _removePlayerFromTeam(teamName, player),
                        backgroundColor: appColors.screenBg,
                        side: BorderSide(color: appColors.disableBgColor),
                      ).animate().scale(duration: 200.ms, curve: Curves.easeOut);
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.1);
  }

  void _editPlayer(String oldName) {
    final controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit Player Name", style: Theme.of(ctx).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: "New Player Name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: appColors.pleasantButtonBg),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != oldName && !_playersMap.containsKey(newName)) {
                setState(() {
                  int score = _playersMap[oldName] ?? 0;
                  _playersMap.remove(oldName);
                  _playersMap[newName] = score;
                });
                Navigator.pop(ctx);
              } else if (_playersMap.containsKey(newName) && newName != oldName) {
                showSingleButtonAlertDialog(context: context, title: "Error", message: "Player already exists.");
              } else {
                Navigator.pop(ctx); // Same name, do nothing
              }
            },
            child: Text("Save", style: TextStyle(color: appColors.buttonTextColor)),
          ),
        ],
      ),
    );
  }

  void _deletePlayer(String name) {
    showTwoButtonAlertDialog(
      context: context,
      title: "Delete Player",
      message: "Are you sure you want to delete $name and their score?",
      positiveButton: "Delete",
      negativeButton: "Cancel",
      positiveAction: () {
        setState(() {
          _playersMap.remove(name);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScoreboardSetupBloc, ScoreboardSetupState>(
      bloc: _bloc,
      listener: (context, state) {
        if (_pr?.isShowing() ?? false) _pr?.hide();

        if (state is LoadingState) {
          _pr = ProgressDialog(
            context,
            type: ProgressDialogType.normal,
            isDismissible: false,
          );
          _pr?.style(
            backgroundColor: appColors.screenBg,
            message: state.loadingInfo.message,
            progressWidget: Padding(
              padding: const EdgeInsets.all(8.0),
              child: LoadingIndicator(
                indicatorType: Indicator.lineScalePulseOutRapid,
                colors: appColors.rainbowColors,
                strokeWidth: 2,
              ),
            ),
          );
          _pr?.show();
        } else if (state is ScoreboardSetupErrorState) {
          showSingleButtonAlertDialog(context: context, title: state.title, message: state.message).then((_) {
            if (_scoreboardEntity == null && context.canPop()) context.pop();
          });
        } else if (state is ScoreboardScoreUpdateSuccessState) {
          context.go('/${ScoreboardScoreUpdateScreen.routeName}?id=${widget.id}');
        } else if (state is ScoreboardReceivedSuccessState) {
          setState(() {
            _scoreboardEntity = state.scoreboardEntity;
          });
          _initControllers();
        }
      },
      child: Builder(
        builder: (context) {
          if (_scoreboardEntity == null || _isLoadingAccess) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          final ownerPass = _scoreboardEntity!.access?.owner;
          if (ownerPass != null && ownerPass.isNotEmpty && !_isOwnerUnlocked) {
            return PasswordPromptWidget(
              expectedPassword: ownerPass,
              title: "Edit Protected Scoreboard",
              message: "Enter the owner password to edit scoreboard details and players.",
              onSuccess: () {
                GlobalValues.unlockScoreboardAccess(scoreboardId: widget.id, type: 'owner');
                setState(() {
                  _isOwnerUnlocked = true;
                });
              },
              onCancel: () {
                context.go('/${ScoreboardScoreUpdateScreen.routeName}?id=${widget.id}');
              },
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: Text("Scoreboard Editor", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: appColors.textColor)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: appColors.textColor),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  context.go('/${ScoreboardScoreUpdateScreen.routeName}?id=${widget.id}');
                },
              ),
              actions: [
                Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: appColors.pleasantButtonBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text("Save"),
                    onPressed: _saveChanges,
                  ),
                ),
              ],
            ),
            body: Center(
              child: Container(
                width: maxScreenWidth,
                padding: WebOptimisedWidget.getWebOptimisedHorizonatalPadding().copyWith(left: 16, right: 16, top: 16),
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                  _buildSectionContainer(
                    title: "Basic Details",
                    icon: Icons.info_outline,
                    children: [
                      getTextInputWidget(
                        context: context,
                        label: "Title",
                        hint: "E.g. Sunday League",
                        controller: _titleController,
                        prefixIcon: const Icon(Icons.title),
                      ),
                      SizedBox(height: 12.h),
                      getTextInputWidget(
                        context: context,
                        label: "Description",
                        hint: "Optional description",
                        controller: _descriptionController,
                        prefixIcon: const Icon(Icons.description_outlined),
                      ),
                      SizedBox(height: 12.h),
                      getTextInputWidget(
                        context: context,
                        label: "Author",
                        hint: "Your name",
                        controller: _authorController,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ],
                  ).animate().fade(duration: 400.ms, delay: 0.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),

                  _buildSectionContainer(
                    title: "Security / Access",
                    icon: Icons.shield_outlined,
                    children: [
                      _buildPasswordField(
                        label: "Read",
                        controller: _readAccessController,
                        removeFlag: _removeReadAccess,
                        onChanged: (val) {
                          setState(() => _removeReadAccess = val ?? false);
                          if (_removeReadAccess) _readAccessController.clear();
                        },
                      ),
                      SizedBox(height: 16.h),
                      _buildPasswordField(
                        label: "Write",
                        controller: _writeAccessController,
                        removeFlag: _removeWriteAccess,
                        onChanged: (val) {
                          setState(() => _removeWriteAccess = val ?? false);
                          if (_removeWriteAccess) _writeAccessController.clear();
                        },
                      ),
                      SizedBox(height: 16.h),
                      _buildPasswordField(
                        label: "Owner",
                        controller: _ownerAccessController,
                        removeFlag: _removeOwnerAccess,
                        onChanged: (val) {
                          setState(() => _removeOwnerAccess = val ?? false);
                          if (_removeOwnerAccess) _ownerAccessController.clear();
                        },
                      ),
                    ],
                  ).animate().fade(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),

                  if (_scoreboardEntity!.isTeamGame == true)
                    _buildSectionContainer(
                      title: "Team Roster",
                      icon: Icons.group_work_outlined,
                      children: [
                        getTextInputWidget(
                          context: context,
                          label: 'Add Team',
                          hint: 'e.g. Red Team',
                          controller: _teamTextController,
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.go,
                          prefixIcon: const Icon(Icons.group_add_outlined),
                          icon: Icons.add,
                          onPressed: _addTeam,
                        ),
                        SizedBox(height: 16.h),
                        if (_teamsMap.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.h),
                            child: Center(
                              child: Text(
                                "No teams added yet.",
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                              ),
                            ),
                          )
                        else
                          ..._teamsMap.entries.map((entry) => _buildTeamCard(entry.key, entry.value.players)).toList(),
                      ],
                    ).animate().fade(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic)
                  else
                    _buildSectionContainer(
                      title: "Player Roster",
                      icon: Icons.people_outline,
                      action: TextButton.icon(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        label: const Text("Add Player"),
                        onPressed: _addPlayer,
                        style: TextButton.styleFrom(foregroundColor: appColors.pleasantButtonBg),
                      ),
                      children: [
                        if (_playersMap.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.h),
                            child: Center(
                              child: Text(
                                "No players added yet.",
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _playersMap.length,
                            separatorBuilder: (context, index) => SizedBox(height: 8.h),
                            itemBuilder: (context, index) {
                              final player = _playersMap.keys.elementAt(index);
                              return Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(color: appColors.primaryColor.withValues(alpha: 0.05)),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: appColors.primaryColor.withValues(alpha: 0.1),
                                    child: Text(player.isNotEmpty ? player[0].toUpperCase() : "?", style: TextStyle(color: appColors.primaryColor, fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(player, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                  subtitle: Text("Score: ${_playersMap[player]}", style: Theme.of(context).textTheme.bodySmall),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                        onPressed: () => _editPlayer(player),
                                        tooltip: "Edit name",
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _deletePlayer(player),
                                        tooltip: "Remove player",
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ).animate().fade(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),
                  
                  SizedBox(height: 32.h),
                ],
              ),
            ),
          ),
        );
        },
      ),
    );
  }
}
