// lib/screens/auth/invite_register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class InviteRegisterScreen extends StatefulWidget {
  final String? inviteCode;

  const InviteRegisterScreen({Key? key, this.inviteCode}) : super(key: key);

  @override
  _InviteRegisterScreenState createState() => _InviteRegisterScreenState();
}

class _InviteRegisterScreenState extends State<InviteRegisterScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();

  final _phoneFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _api = ApiService();

  int _currentStep = 0; // 0: phone, 1: code, 2: registration
  bool _isLoading = false;
  String? _errorMessage;
  String? _verifiedInviteCode;

  // Маска для телефона: +7 (XXX) XXX-XX-XX
  final _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    _verifiedInviteCode = widget.inviteCode;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  String _getCleanPhone() {
    return _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
  }

  Future<void> _sendCode() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _api.post('/auth/send-code', {
        'phone': _getCleanPhone(),
        'inviteCode': _verifiedInviteCode,
      });

      if (response['success'] == true) {
        setState(() {
          _currentStep = 1;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Код отправлен на ${_phoneController.text}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _errorMessage = response['error'] ?? 'Ошибка отправки кода';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    if (!_codeFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _api.post('/auth/verify-code', {
        'phone': _getCleanPhone(),
        'code': _codeController.text,
      });

      if (response['success'] == true) {
        setState(() {
          _currentStep = 2;
          _isLoading = false;
          _verifiedInviteCode = response['inviteCode'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Телефон подтвержден!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _errorMessage = response['error'] ?? 'Неверный код';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _completeRegistration() async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _api.post('/auth/verify-code', {
        'phone': _getCleanPhone(),
        'code': _codeController.text,
        'username': _usernameController.text.trim(),
        'password': _passwordController.text,
        'fullName': _fullNameController.text.trim(),
      });

      if (response['success'] == true && response['user'] != null) {
        final authProvider = context.read<AuthProvider>();

        // Сохраняем токен и пользователя
        if (response['token'] != null) {
          await _api.saveToken(response['token']);
        }

        // Обновляем состояние в провайдере
        authProvider.setAuthenticated(response['user'], response['token']);

        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
          );
        }
      } else {
        setState(() {
          _errorMessage = response['error'] ?? 'Ошибка регистрации';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 30),
                      _buildStepIndicator(),
                      const SizedBox(height: 30),
                      if (_errorMessage != null) _buildErrorMessage(),
                      _buildCurrentStep(),
                      const SizedBox(height: 20),
                      _buildBackButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String emoji = '📱';
    String title = 'Регистрация';

    if (_currentStep == 1) {
      emoji = '🔐';
      title = 'Подтверждение';
    } else if (_currentStep == 2) {
      emoji = '👤';
      title = 'Создание аккаунта';
    }

    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 60)),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF7C3AED),
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepDot(0, 'Телефон'),
        _buildStepLine(0),
        _buildStepDot(1, 'Код'),
        _buildStepLine(1),
        _buildStepDot(2, 'Данные'),
      ],
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = step == _currentStep;
    final isCompleted = step < _currentStep;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? Colors.green
                : isActive
                    ? const Color(0xFF7C3AED)
                    : Colors.grey[300],
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? const Color(0xFF7C3AED) : Colors.grey[600],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    final isCompleted = step < _currentStep;

    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isCompleted ? Colors.green : Colors.grey[300],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildPhoneStep();
      case 1:
        return _buildCodeStep();
      case 2:
        return _buildRegistrationStep();
      default:
        return Container();
    }
  }

  Widget _buildPhoneStep() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _phoneController,
            inputFormatters: [_phoneMask],
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Номер телефона',
              hintText: '+7 (XXX) XXX-XX-XX',
              prefixIcon: const Icon(Icons.phone),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Введите номер телефона';
              }
              final clean = _getCleanPhone();
              if (clean.length != 11) {
                return 'Введите корректный номер';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Получить код',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStep() {
    return Form(
      key: _codeFormKey,
      child: Column(
        children: [
          Text(
            'Введите код из SMS',
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          Text(
            _phoneController.text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              hintText: '000000',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              if (value == null || value.length != 6) {
                return 'Введите 6-значный код';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Подтвердить',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 15),
          TextButton(
            onPressed: _isLoading ? null : _sendCode,
            child: const Text('Отправить код повторно'),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationStep() {
    return Form(
      key: _registerFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: 'Имя пользователя',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите имя пользователя';
              }
              if (value.trim().length < 3) {
                return 'Минимум 3 символа';
              }
              if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                return 'Только буквы, цифры и _';
              }
              return null;
            },
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _fullNameController,
            decoration: InputDecoration(
              labelText: 'Полное имя',
              prefixIcon: const Icon(Icons.badge),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите полное имя';
              }
              return null;
            },
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Пароль',
              prefixIcon: const Icon(Icons.lock),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Введите пароль';
              }
              if (value.length < 6) {
                return 'Минимум 6 символов';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _completeRegistration,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Создать аккаунт',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return TextButton.icon(
      onPressed: () {
        if (_currentStep > 0) {
          setState(() {
            _currentStep--;
            _errorMessage = null;
          });
        } else {
          Navigator.of(context).pop();
        }
      },
      icon: const Icon(Icons.arrow_back),
      label: Text(_currentStep > 0 ? 'Назад' : 'К входу'),
    );
  }
}
