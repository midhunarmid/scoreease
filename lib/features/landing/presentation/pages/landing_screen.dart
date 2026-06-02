import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scoreease/features/landing/presentation/blocs/landing/landing_bloc.dart';
import 'package:scoreease/features/scoreboard/presentation/pages/score_board_setup_screen.dart';

import 'package:scoreease/features/scoreboard/presentation/pages/scoreboard_score_display_screen.dart';
import 'package:scoreease/features/settings/presentation/pages/settings_screen.dart';
import 'package:scoreease/core/utils/constants.dart';
import 'package:scoreease/core/utils/message_generator.dart';
import 'package:scoreease/core/utils/theme.dart';
import 'package:scoreease/core/utils/input_case_text_formatter.dart';
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

class LandingScreen extends StatefulWidget {
  const LandingScreen({Key? key}) : super(key: key);
  static const routeName = 'home';

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final TextEditingController _scoreCardIdTextController =
      TextEditingController();

  final LandingBloc _bloc = LandingBloc();
  ProgressDialog? pr;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scoreCardIdTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener(
      bloc: _bloc,
      listener: (ctx, state) {
        appLogger.i(state);

        if (pr?.isShowing() ?? false) {
          pr?.hide();
        }
        if (state is LoadingState) {
          pr = ProgressDialog(
            context,
            type: ProgressDialogType.normal,
            isDismissible: false,
          );
          pr?.style(
            backgroundColor: appColors.screenBg,
            padding: WebOptimisedWidget.getWebOptimisedHorizonatalPadding(),
            message: state.loadingInfo.message,
            widgetAboveTheDialog: Text(
              state.loadingInfo.title,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
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
            progressTextStyle: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.w400),
            messageTextStyle: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.w400),
          );
          pr?.show();
        } else if (state is LandingErrorState) {
          showTwoButtonAlertDialog(
            context: context,
            title: state.title,
            message: state.message,
            positiveButton: MessageGenerator.getLabel("Create New"),
            positiveAction: onCreateNewScoreboardButtonClick,
            negativeButton: MessageGenerator.getLabel("Cancel"),
          );
        } else if (state is LandingScoreCardReceivedState) {
          context.go(
              "/${ScoreboardScoreDisplayScreen.routeName}?id=${state.scoreboard.id}");
        }
      },
      child: BlocBuilder<LandingBloc, LandingState>(
          bloc: _bloc,
          builder: (ctx, state) {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                systemOverlayStyle: Theme.of(context).brightness == Brightness.light
                    ? SystemUiOverlayStyle.dark
                    : SystemUiOverlayStyle.light,
                actions: [
                  IconButton(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  width: maxScreenWidth,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/brand_icon.png',
                          height: 100.h,
                        )
                            .animate(
                                onPlay: (controller) =>
                                    controller.repeat(reverse: true))
                            .scale(
                                begin: const Offset(1, 1),
                                end: const Offset(1.05, 1.05),
                                duration: 2.seconds,
                                curve: Curves.easeInOut),
                        SizedBox(height: 24.h),
                        Text(
                          MessageGenerator.getMessage("landing-welcome"),
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: appColors.primaryColor,
                                fontWeight: FontWeight.w800,
                              ),
                        ).animate().fade(duration: 500.ms).slideY(
                            begin: 0.3, end: 0, curve: Curves.easeOutQuad),
                        SizedBox(height: 48.h),
                        Card(
                          elevation: 8,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                getTextInputWidget(
                                  context: context,
                                  label: MessageGenerator.getLabel(
                                      'type in scoreboard name'),
                                  hint:
                                      MessageGenerator.getLabel('messironaldo'),
                                  controller: _scoreCardIdTextController,
                                  keyboardType: TextInputType.text,
                                  textInputAction: TextInputAction.go,
                                  prefixIcon: const Icon(Icons.edit_outlined),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[a-zA-Z0-9]')),
                                    LengthLimitingTextInputFormatter(50),
                                    LowerCaseTextFormatter(),
                                  ],
                                ),
                                SizedBox(height: 24.h),
                                AnimatedClickableTextContainer(
                                  title: MessageGenerator.getLabel(
                                      'Get Scoreboard'),
                                  iconSrc: '',
                                  isActive: false,
                                  bgColor: appColors.pleasantButtonBg,
                                  bgColorHover: appColors.pleasantButtonBgHover,
                                  press: () {
                                    onSubmitScoreboardId();
                                  },
                                ),
                                SizedBox(height: 24.h),
                                Row(
                                  children: [
                                    Expanded(
                                        child: Divider(
                                            color: appColors.listDividerColor)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: Text(
                                        "OR",
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Colors.grey,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    Expanded(
                                        child: Divider(
                                            color: appColors.listDividerColor)),
                                  ],
                                ),
                                SizedBox(height: 24.h),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    context.go(
                                        "/${ScoreboardSetupScreen.routeName}");
                                  },
                                  icon: const Icon(Icons.add_circle_outline),
                                  label: Text(MessageGenerator.getLabel(
                                      'Create New Scoreboard')),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    side: BorderSide(
                                        color: appColors.primaryColor,
                                        width: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    foregroundColor: appColors.primaryColor,
                                    textStyle:
                                        Theme.of(context).textTheme.labelLarge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fade(delay: 200.ms, duration: 500.ms).scale(
                            begin: const Offset(0.9, 0.9),
                            curve: Curves.easeOutBack),
                        SizedBox(height: 48.h),
                        Linkify(
                          onOpen: (link) async {
                            if (!await launchUrl(Uri.parse(link.url))) {}
                          },
                          text: MessageGenerator.getMessage(
                              "landing-visit-site-guide"),
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: Colors.grey),
                          linkStyle:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: appColors.linkTextColor,
                                    fontWeight: FontWeight.bold,
                                  ),
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

  void onSubmitScoreboardId() {
    _bloc.add(LandingGetScoreboardEvent(_scoreCardIdTextController.text));
  }

  void onCreateNewScoreboardButtonClick() {
    context.go("/${ScoreboardSetupScreen.routeName}");
  }
}
