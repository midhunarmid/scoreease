import 'dart:ui';
import 'package:flutter/material.dart';
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
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 600;

    return Scaffold(
      backgroundColor: appColors.screenBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Premium Mesh Gradient Background
          Positioned(
            top: -size.height * 0.2,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.8,
              height: size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    appColors.primaryColor.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ).animate().fade(duration: 1500.ms).scale(begin: const Offset(0.8, 0.8)),
          ),
          Positioned(
            bottom: -size.height * 0.2,
            left: -size.width * 0.1,
            child: Container(
              width: size.width * 0.6,
              height: size.width * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.purpleAccent.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ).animate().fade(duration: 1800.ms).scale(begin: const Offset(0.8, 0.8)),
          ),
          
          // Full-screen subtle blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.transparent),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 32.0 : 24.0),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: EdgeInsets.all(isDesktop ? 40.0 : 32.0),
                      decoration: BoxDecoration(
                        color: appColors.tileBgColor.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Glowing Icon
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: _isUnlocked 
                                  ? Colors.greenAccent.withValues(alpha: 0.15) 
                                  : appColors.primaryColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _isUnlocked 
                                      ? Colors.greenAccent.withValues(alpha: 0.3) 
                                      : appColors.primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            child: Icon(
                              _isUnlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                              size: 48,
                              color: _isUnlocked ? Colors.greenAccent : appColors.primaryColor,
                            )
                            .animate(target: _isUnlocked ? 1 : 0)
                            .scale(end: const Offset(1.1, 1.1))
                            .tint(color: Colors.greenAccent),
                          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                           .shimmer(duration: 2500.ms, color: Colors.white.withValues(alpha: 0.3)),
                          
                          const SizedBox(height: 32),
                          Text(
                            widget.title,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.message,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).hintColor,
                                  height: 1.6,
                                  fontSize: 15,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 40),
                          
                          // Premium Password Input
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: appColors.primaryColor.withValues(alpha: 0.05),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                )
                              ],
                            ),
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              obscureText: true,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 24, letterSpacing: 8.0, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: "Password",
                                labelStyle: const TextStyle(letterSpacing: 0, fontSize: 14, fontWeight: FontWeight.normal),
                                errorText: _errorText,
                                errorStyle: const TextStyle(letterSpacing: 0, fontWeight: FontWeight.w500),
                                filled: true,
                                fillColor: appColors.inputBgFill,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: appColors.primaryColor, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
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
                          ),
                          const SizedBox(height: 40),
                          
                          // Action Buttons
                          Row(
                            mainAxisAlignment: widget.onCancel != null ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                            children: [
                              if (widget.onCancel != null)
                                TextButton(
                                  onPressed: widget.onCancel,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(
                                    widget.cancelText ?? "Cancel", 
                                    style: TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.w600, fontSize: 16),
                                  ),
                                ),
                              Expanded(
                                flex: widget.onCancel != null ? 0 : 1,
                                child: ElevatedButton(
                                  onPressed: _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: appColors.primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 5,
                                    shadowColor: appColors.primaryColor.withValues(alpha: 0.5),
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text("Unlock", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_rounded, size: 20),
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
               .slideY(begin: 0.1, end: 0, duration: 600.ms, curve: Curves.easeOutCubic)
               .fade(duration: 600.ms)
               .animate(target: _isShaking ? 1 : 0, onComplete: (controller) => setState(() => _isShaking = false))
               .shake(hz: 8, duration: 400.ms),
            ),
          ),
        ],
      ),
    );
  }
}
