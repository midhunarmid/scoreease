import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scoreease/core/presentation/blocs/landing/landing_bloc.dart';
import 'package:scoreease/core/presentation/pages/score_board_setup_screen.dart';
import 'package:scoreease/core/presentation/pages/scoreboard_update_screen.dart';
import 'package:scoreease/core/presentation/utils/constants.dart';
import 'package:scoreease/core/presentation/utils/message_generator.dart';
import 'package:scoreease/core/presentation/utils/theme.dart';
import 'package:scoreease/core/presentation/utils/input_case_text_formatter.dart';
import 'package:scoreease/core/presentation/utils/widget_helper.dart';
import 'package:scoreease/core/presentation/widgets/animated_container.dart';
import 'package:scoreease/core/presentation/widgets/web_optimised_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:progress_dialog_null_safe/progress_dialog_null_safe.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({Key? key}) : super(key: key);
  static const routeName = 'home';

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final TextEditingController _scoreCardIdTextController = TextEditingController();

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
          context.go("/${ScoreboardScoreUpdateScreen.routeName}", extra: state.scoreboard);
        }
      },
      child: BlocBuilder<LandingBloc, LandingState>(
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
                          MessageGenerator.getMessage("landing-welcome"),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue),
                        ),
                        SizedBox(height: 32.h),
                        getTextInputWidget(
                          context: context,
                          label: MessageGenerator.getLabel('type in scoreboard name'),
                          hint: MessageGenerator.getLabel('messironaldo'),
                          controller: _scoreCardIdTextController,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.go,
                          prefixIcon: const Icon(Icons.edit_outlined),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                            LengthLimitingTextInputFormatter(50),
                            LowerCaseTextFormatter(),
                          ],
                        ),
                        SizedBox(
                          height: 8.h,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: AnimatedClickableTextContainer(
                            title: MessageGenerator.getLabel('Get Scoreboard'),
                            iconSrc: '',
                            isActive: false,
                            bgColor: appColors.pleasantButtonBg,
                            bgColorHover: appColors.pleasantButtonBgHover,
                            press: () {
                              onSubmitScoreboardId();
                            },
                          ),
                        ),
                        SizedBox(height: 16.h),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: Theme.of(context).textTheme.labelSmall,
                            children: <TextSpan>[
                              TextSpan(
                                  text: MessageGenerator.getLabel('Create New Scoreboard'),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.red),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      context.go("/${ScoreboardSetupScreen.routeName}");
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

  void onSubmitScoreboardId() {
    _bloc.add(LandingGetScoreboardEvent(_scoreCardIdTextController.text));
  }

  void onCreateNewScoreboardButtonClick() {
    context.go("/${ScoreboardSetupScreen.routeName}");
  }
}
