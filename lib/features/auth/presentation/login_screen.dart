import 'package:flutter/material.dart';

import '../../../core/design/app_design.dart';
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

    _companyCodeController.text = widget.controller.tenant.code;
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

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.controller.login(
        identifier: _employeeController.text,
        password: _passwordController.text,
        companyCode: _companyCodeController.text,
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
                  // TECHNICAL HEADER
                  // ------------------------------------------

                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppDesign.surface,
                          border: Border.all(color: AppDesign.line),
                          borderRadius: BorderRadius.circular(AppDesign.radius),
                        ),
                        alignment: Alignment.center,
                        child: TenantLogo(tenant: tenant, size: 38),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SECURE FIELD ACCESS',
                              style: AppDesign.mono(
                                size: 9,
                                color: AppDesign.primary,
                                weight: FontWeight.w600,
                                letterSpacing: 2.2,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              tenant.code.toUpperCase(),
                              style: AppDesign.mono(
                                size: 9,
                                color: AppDesign.faint,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(width: 32, height: 1, color: AppDesign.ink),
                          const SizedBox(height: 5),
                          Container(width: 22, height: 1, color: AppDesign.ink),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 52),

                  Text(
                    tenant.displayName.toUpperCase(),
                    style: AppDesign.serif(
                      size: 46,
                      height: .96,
                      letterSpacing: -1.1,
                    ),
                  ),

                  Text(
                    'field operations',
                    style: AppDesign.serif(
                      size: 40,
                      color: const Color(0xFFB4B4B4),
                      height: .98,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -.8,
                    ),
                  ),

                  const SizedBox(height: 28),

                  Container(height: 1, color: AppDesign.line),

                  const SizedBox(height: 18),

                  Text(
                    'Company-issued access to your live responsibilities, workflows and field records.',
                    style: AppDesign.sans(
                      size: 14,
                      color: AppDesign.muted,
                      height: 1.55,
                    ),
                  ),

                  const SizedBox(height: 38),

                  // ------------------------------------------
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
                          decoration: const InputDecoration(
                            labelText: 'COMPANY CODE',
                            hintText: 'COMPANY',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter your company code'
                              : null,
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
