import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scoreease/core/domain/entities/access_entity.dart';
import 'package:scoreease/core/domain/entities/scoreboard_entity.dart';
import 'package:scoreease/core/presentation/blocs/score_board_setup/score_board_setup_bloc.dart';
import 'package:scoreease/core/presentation/utils/constants.dart';
import 'package:scoreease/core/presentation/utils/input_case_text_formatter.dart';
import 'package:scoreease/core/presentation/utils/message_generator.dart';
import 'package:scoreease/core/presentation/utils/theme.dart';
import 'package:scoreease/core/presentation/utils/widget_helper.dart';
import 'package:scoreease/core/presentation/widgets/animated_container.dart';
import 'package:scoreease/core/presentation/widgets/web_optimised_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:progress_dialog_null_safe/progress_dialog_null_safe.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

class ScoreboardSetupScreen extends StatefulWidget {
  const ScoreboardSetupScreen({Key? key}) : super(key: key);

  @override
  State<ScoreboardSetupScreen> createState() => _ScoreboardSetupScreenState();
}

class _ScoreboardSetupScreenState extends State<ScoreboardSetupScreen> {
  final TextEditingController _scoreCardIdTextController = TextEditingController();
  final TextEditingController _scoreCardTitleTextController = TextEditingController();
  final TextEditingController _scoreCardDescriptionTextController = TextEditingController();
  final TextEditingController _scoreCardAuthorTextController = TextEditingController();
  final TextEditingController _scoreCardPlayerTextController = TextEditingController();

  final ScoreboardSetupBloc _bloc = ScoreboardSetupBloc();
  ProgressDialog? _pr;
  ScoreboardSetupStage _currentStage = ScoreboardSetupStage.basic;
  ScoreboardEntity _scoreboardEntity = const ScoreboardEntity();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scoreCardIdTextController.dispose();
    _scoreCardTitleTextController.dispose();
    _scoreCardDescriptionTextController.dispose();
    _scoreCardAuthorTextController.dispose();
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
            positiveAction: () => context.go("/home"),
          );
        } else if (state is ScoreboardSetupBasicSuccessState) {
          _currentStage = ScoreboardSetupStage.players;
          _scoreboardEntity = state.scoreboardEntity;
        }
      },
      child: BlocBuilder<ScoreboardSetupBloc, ScoreboardSetupState>(
          bloc: _bloc,
          builder: (ctx, state) {
            return Scaffold(
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
                          MessageGenerator.getMessage("scoreboard-welcome"),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue),
                        ),
                        SizedBox(height: 32.h),
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: appColors.screenBg,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 1.0,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            MessageGenerator.getMessage("scoreboard-setup-basic-title"),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (_currentStage == ScoreboardSetupStage.basic) scoreboardSetupBasicArea(context),
                        SizedBox(height: 8.h),
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: (_currentStage == ScoreboardSetupStage.players ||
                                    _currentStage == ScoreboardSetupStage.access)
                                ? appColors.screenBg
                                : appColors.screenBg.withValues(alpha: 0.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 1.0,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            MessageGenerator.getMessage("scoreboard-setup-players-title"),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (_currentStage == ScoreboardSetupStage.players) scoreboardSetupPlayersArea(context),
                        SizedBox(height: 8.h),
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: (_currentStage == ScoreboardSetupStage.access)
                                ? appColors.screenBg
                                : appColors.screenBg.withValues(alpha: 0.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 1.0,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            MessageGenerator.getMessage("scoreboard-setup-access-title"),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (_currentStage == ScoreboardSetupStage.access) scoreboardSetupPlayersArea(context),
                        SizedBox(height: 16.h),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(),
                            children: <TextSpan>[
                              TextSpan(
                                  text: MessageGenerator.getLabel('Use Existing Scoreboard'),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.red),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      context.go("/home");
                                    }),
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
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(),
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

  Widget scoreboardSetupBasicArea(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 8.h),
        getTextInputWidget(
          context: context,
          label: MessageGenerator.getLabel('type in scoreboard name'),
          hint: MessageGenerator.getLabel('messironaldo'),
          controller: _scoreCardIdTextController,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(Icons.key),
          maxLength: 10,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            LengthLimitingTextInputFormatter(10),
            LowerCaseTextFormatter(),
          ],
        ),
        SizedBox(height: 8.h),
        getTextInputWidget(
          context: context,
          label: MessageGenerator.getLabel('type in title'),
          hint: MessageGenerator.getLabel('Messi vs Ronaldo'),
          controller: _scoreCardTitleTextController,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(Icons.title),
          maxLength: 20,
          inputFormatters: [
            LengthLimitingTextInputFormatter(20),
          ],
        ),
        SizedBox(height: 8.h),
        getTextInputWidget(
          context: context,
          label: MessageGenerator.getLabel('type in description'),
          hint: MessageGenerator.getLabel(
              'Track the eternal rivalry between Lionel Messi and Cristiano Ronaldo with this simple, real-time scoreboard. Update scores, log moments, and settle debates — who\'s leading in your books?'),
          controller: _scoreCardDescriptionTextController,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          minLines: 5,
          maxLines: 5,
          prefixIcon: const Icon(Icons.description),
          maxLength: 100,
          inputFormatters: [
            LengthLimitingTextInputFormatter(100),
          ],
        ),
        SizedBox(height: 8.h),
        getTextInputWidget(
          context: context,
          label: MessageGenerator.getLabel('type in author'),
          hint: MessageGenerator.getLabel('Midhun Mohanan'),
          controller: _scoreCardAuthorTextController,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(Icons.person_2_outlined),
          maxLength: 20,
          inputFormatters: [
            LengthLimitingTextInputFormatter(20),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: AnimatedClickableTextContainer(
                  title: MessageGenerator.getLabel('Previous'),
                  iconSrc: '',
                  isActive: false,
                  bgColor: appColors.sideMenuBg,
                  bgColorHover: appColors.sideMenuHighlight,
                  press: () {
                    setState(() {
                      _currentStage = ScoreboardSetupStage.basic;
                    });
                  },
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: AnimatedClickableTextContainer(
                  title: MessageGenerator.getLabel('Next'),
                  iconSrc: '',
                  isActive: false,
                  bgColor: appColors.pleasantButtonBg,
                  bgColorHover: appColors.pleasantButtonBgHover,
                  press: () {
                    onScoreboardBasicNextButtonPressed();
                  },
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
      ],
    );
  }

  Widget scoreboardSetupPlayersArea(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 8.h),
        getTextInputWidget(
          context: context,
          label: MessageGenerator.getLabel('player name'),
          hint: MessageGenerator.getLabel('Messi'),
          controller: _scoreCardPlayerTextController,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.go,
          prefixIcon: const Icon(Icons.key),
          inputFormatters: [
            LengthLimitingTextInputFormatter(20),
          ],
          icon: Icons.add,
          onPressed: () {
            _scoreboardEntity.players?[_scoreCardPlayerTextController.text] = 0;
          },
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: AnimatedClickableTextContainer(
                  title: MessageGenerator.getLabel('Previous'),
                  iconSrc: '',
                  isActive: false,
                  bgColor: appColors.sideMenuBg,
                  bgColorHover: appColors.sideMenuHighlight,
                  press: () {
                    setState(() {
                      _currentStage = ScoreboardSetupStage.basic;
                    });
                  },
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: AnimatedClickableTextContainer(
                  title: MessageGenerator.getLabel('Next'),
                  iconSrc: '',
                  isActive: false,
                  bgColor: appColors.pleasantButtonBg,
                  bgColorHover: appColors.pleasantButtonBgHover,
                  press: () {
                    onScoreboardBasicNextButtonPressed();
                  },
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
      ],
    );
  }

  void onScoreboardBasicNextButtonPressed() {
    ScoreboardEntity scoreboard = ScoreboardEntity(
      id: _scoreCardIdTextController.text,
      title: _scoreCardTitleTextController.text,
      description: _scoreCardDescriptionTextController.text,
      author: _scoreCardAuthorTextController.text,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
      players: const {},
      access: const AccessEntity(
        read: "",
        write: "",
      ),
    );
    _bloc.add(ScoreboardSetupBasicSubmitEvent(scoreboard));
  }
}

enum ScoreboardSetupStage {
  basic,
  players,
  access,
}
