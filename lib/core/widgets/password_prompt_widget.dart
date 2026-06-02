import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:scoreease/core/utils/theme.dart';
import 'package:scoreease/core/utils/security_helper.dart';

class PasswordPromptWidget extends StatefulWidget {
  final String expectedPassword;
  final String title;
  final String message;
  final VoidCallback onSuccess;
  final VoidCallback? onCancel;
  final String? cancelText;

  const PasswordPromptWidget({
    Key? key,
    required this.expectedPassword,
    required this.title,
    required this.message,
    required this.onSuccess,
    this.onCancel,
    this.cancelText,
  }) : super(key: key);

  @override
  State<PasswordPromptWidget> createState() => _PasswordPromptWidgetState();
}

class _PasswordPromptWidgetState extends State<PasswordPromptWidget> {
  final _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _errorText;
  bool _isShaking = false;
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  void _submit() {
    final hashedInput = SecurityHelper.hashPassword(_controller.text);
    if (hashedInput == widget.expectedPassword) {
      setState(() {
        _isUnlocked = true;
        _errorText = null;
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        widget.onSuccess();
      });
    } else {
      setState(() {
        _errorText = "Incorrect password. Please try again.";
        _isShaking = true;
      });
      _controller.clear();
      FocusScope.of(context).requestFocus(_focusNode);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appColors.screenBg,
      body: Stack(
        children: [
          // Decorative background blur elements
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: appColors.primaryColor.withValues(alpha: 0.1),
              ),
            ).animate().fade(duration: 1000.ms).scale(begin: const Offset(0.8, 0.8)),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: appColors.primaryColor.withValues(alpha: 0.05),
              ),
            ).animate().fade(duration: 1200.ms).scale(begin: const Offset(0.8, 0.8)),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24.r),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxWidth: 400.w),
                    padding: EdgeInsets.all(32.w),
                    decoration: BoxDecoration(
                      color: appColors.tileBgColor.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(
                        color: appColors.primaryColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon with dynamic state
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: _isUnlocked 
                                ? Colors.green.withValues(alpha: 0.1) 
                                : appColors.primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isUnlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                            size: 48.w,
                            color: _isUnlocked ? Colors.green : appColors.primaryColor,
                          )
                          .animate(target: _isUnlocked ? 1 : 0)
                          .scale(end: const Offset(1.2, 1.2))
                          .tint(color: Colors.green),
                        ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                         .shimmer(duration: 2000.ms, color: appColors.primaryColor.withValues(alpha: 0.2)),
                        
                        SizedBox(height: 24.h),
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          widget.message,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).hintColor,
                                height: 1.5,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 32.h),
                        
                        // Password Input
                        TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          obscureText: true,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 20.sp, letterSpacing: 4.0),
                          decoration: InputDecoration(
                            labelText: "Password",
                            labelStyle: TextStyle(letterSpacing: 0, fontSize: 14.sp),
                            errorText: _errorText,
                            errorStyle: const TextStyle(letterSpacing: 0),
                            filled: true,
                            fillColor: appColors.inputBgFill.withValues(alpha: 0.5),
                            border: appColors.textInputEnabledBorder,
                            enabledBorder: appColors.textInputEnabledBorder,
                            focusedBorder: appColors.textInputFocusedBorder,
                            contentPadding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
                          ),
                          onSubmitted: (_) => _submit(),
                          onChanged: (val) {
                            if (_errorText != null) {
                              setState(() {
                                _errorText = null;
                                _isShaking = false;
                              });
                            }
                          },
                        ),
                        SizedBox(height: 32.h),
                        
                        // Action Buttons
                        Row(
                          mainAxisAlignment: widget.onCancel != null ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                          children: [
                            if (widget.onCancel != null)
                              TextButton(
                                onPressed: widget.onCancel,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                                ),
                                child: Text(
                                  widget.cancelText ?? "Cancel", 
                                  style: TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.w600),
                                ),
                              ),
                            Expanded(
                              flex: widget.onCancel != null ? 0 : 1,
                              child: ElevatedButton(
                                onPressed: _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: appColors.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 14.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("Unlock", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 8.w),
                                    const Icon(Icons.arrow_forward_rounded, size: 20),
                                  ],
                                ),
                              ).animate(target: _isUnlocked ? 1 : 0).scale(end: const Offset(1.05, 1.05)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate()
             .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutCubic)
             .fade(duration: 400.ms)
             .animate(target: _isShaking ? 1 : 0, onComplete: (controller) => setState(() => _isShaking = false))
             .shake(hz: 8, duration: 400.ms),
          ),
        ],
      ),
    );
  }
}
