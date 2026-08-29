import 'package:flutter/material.dart';

import '../../../core/design/app_design.dart';
import '../../../core/design/brixta_feedback.dart';
import '../../../core/services/auth/auth_gateway.dart';
import '../../../core/session/app_session_controller.dart';
import '../../../core/widgets/tenant_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final AppSessionController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _companyCodeController = TextEditingController();

  final _employeeController = TextEditingController();

  final _passwordController = TextEditingController();

  bool _loading = false;

  bool _obscure = true;

  String? _error;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _companyCodeController.dispose();

    _employeeController.dispose();

    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // BRIXTA_LOGIN_ACTION_SOUND
    await BrixtaFeedback.action();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final typedCode = _companyCodeController.text.trim();
      await widget.controller.login(
        identifier: _employeeController.text,
        password: _passwordController.text,
        companyCode: typedCode.isEmpty
            ? widget.controller.tenant.code
            : typedCode,
      );
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to sign in. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = widget.controller.tenant;

    return Scaffold(
      backgroundColor: Colors.transparent,

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),

            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ------------------------------------------
                  _LoginHero(tenant: tenant),

                  const SizedBox(height: 26),

                  Text(
                    'Welcome back',
                    style: AppDesign.sans(
                      size: 30,
                      weight: FontWeight.w700,
                      height: 1,
                      letterSpacing: -.9,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Enter your company workspace and employee credentials.',
                    style: AppDesign.sans(
                      size: 13,
                      color: AppDesign.muted,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 26),

                  // FORM
                  // ------------------------------------------
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _companyCodeController,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: 'COMPANY CODE',
                            hintText: widget.controller.tenant.code.isEmpty
                                ? 'COMPANY'
                                : widget.controller.tenant.code,
                          ),
                          validator: (value) {
                            final hasDefault = widget.controller.tenant.code
                                .trim()
                                .isNotEmpty;
                            if (hasDefault) return null;
                            return value == null || value.trim().isEmpty
                                ? 'Enter your company code'
                                : null;
                          },
                        ),

                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _employeeController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'EMPLOYEE ID',
                            hintText: 'IDENTIFIER',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter your employee ID'
                              : null,
                        ),

                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          onFieldSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: 'PASSWORD',
                            hintText: '••••••••',
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                              ),
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter your password'
                              : null,
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 20),

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppDesign.red),
                              borderRadius: BorderRadius.circular(
                                AppDesign.radius,
                              ),
                            ),
                            child: Text(
                              _error!,
                              style: AppDesign.sans(
                                size: 12,
                                color: AppDesign.red,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 30),

                        FilledButton(
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'ENTER WORKSPACE',
                                  style: AppDesign.mono(
                                    size: 10,
                                    color: Colors.white,
                                    weight: FontWeight.w600,
                                    letterSpacing: 2.6,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  Container(height: 1, color: AppDesign.line),

                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'BRIXTA / FIELD',
                        style: AppDesign.mono(
                          size: 8,
                          color: AppDesign.faint,
                          letterSpacing: 1.4,
                        ),
                      ),
                      Text(
                        'SECURE SESSION',
                        style: AppDesign.mono(
                          size: 8,
                          color: AppDesign.faint,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.tenant});

  final dynamic tenant;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDesign.heroRadius),
      child: SizedBox(
        height: 290,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/brixta_work_hero.jpg',
              fit: BoxFit.cover,
              cacheWidth: 1000,
              filterQuality: FilterQuality.medium,
            ),

            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x06000000),
                    Color(0x26000000),
                    Color(0xE6000000),
                  ],
                ),
              ),
            ),

            Positioned(
              top: 18,
              left: 18,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppDesign.white.withValues(alpha: .95),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: TenantLogo(tenant: tenant, size: 36),
              ),
            ),

            Positioned(
              left: 22,
              right: 22,
              bottom: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BRIXTA / FIELD',
                    style: AppDesign.mono(
                      size: 8,
                      color: AppDesign.white.withValues(alpha: .65),
                      weight: FontWeight.w600,
                      letterSpacing: 1.8,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    tenant.displayName.toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppDesign.sans(
                      size: 30,
                      color: AppDesign.white,
                      weight: FontWeight.w700,
                      height: 1,
                      letterSpacing: -.9,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Your work starts here.',
                    style: AppDesign.sans(
                      size: 13,
                      color: AppDesign.white.withValues(alpha: .73),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
