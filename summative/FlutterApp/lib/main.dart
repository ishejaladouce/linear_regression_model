import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Public prediction endpoint on Render.
const apiUrl = 'https://reading-fluency-api-srxu.onrender.com/predict';

/// Average reading speed of all children in the training data.
const averageWordsPerMinute = 17.8;

// App colours: a warm coffee and chocolate theme.
const _chocolate = Color(0xFF3E2723);
const _caramel = Color(0xFFD4A373);
const _latte = Color(0xFFFAF6F0);
const _fieldFill = Color(0xFFFDFAF6);
const _border = Color(0xFFE8DDD0);

void main() => runApp(const ReadingFluencyApp());

class ReadingFluencyApp extends StatelessWidget {
  const ReadingFluencyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _border),
    );
    return MaterialApp(
      title: 'Reading Fluency Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _chocolate, primary: _chocolate),
        scaffoldBackgroundColor: _latte,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _fieldFill,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: fieldBorder,
          enabledBorder: fieldBorder,
          focusedBorder: fieldBorder.copyWith(
            borderSide: const BorderSide(color: _chocolate, width: 1.6),
          ),
        ),
      ),
      home: const PredictionPage(),
    );
  }
}

/// Describes one input the model needs.
class InputField {
  const InputField(this.key, this.label, this.hint, this.icon, {this.isNumber = false});

  final String key;
  final String label;
  final String hint;
  final IconData icon;
  final bool isNumber;
}

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  static const _childFields = [
    InputField('country', 'Country', 'Ethiopia, Malawi, Rwanda or Tanzania', Icons.public),
    InputField('language', 'Language of the test', 'e.g. Kinyarwanda, Amharic, Kiswahili', Icons.translate),
    InputField('location', 'School location', 'Rural or Urban', Icons.location_on_outlined),
    InputField('gender', 'Gender', 'Male or Female', Icons.person_outline),
    InputField('age', 'Age', '5 to 14 years', Icons.cake_outlined, isNumber: true),
    InputField('grade', 'Grade', '1 to 4', Icons.school_outlined, isNumber: true),
  ];
  static const _skillFields = [
    InputField('familiar_words_per_min', 'Familiar words per minute', '0 to 200',
        Icons.menu_book_outlined, isNumber: true),
    InputField('listening_comprehension_pct', 'Listening comprehension (%)', '0 to 100',
        Icons.hearing_outlined, isNumber: true),
  ];
  static const _allFields = [..._childFields, ..._skillFields];

  final _controllers = {for (final field in _allFields) field.key: TextEditingController()};
  final _scrollController = ScrollController();

  double? _prediction;
  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  /// Shows a result or an error, then scrolls down so the user sees it.
  void _showResult({double? prediction, String? error}) {
    setState(() {
      _prediction = prediction;
      _error = error;
      _isLoading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _predict() async {
    FocusScope.of(context).unfocus();

    // 1. Check the inputs on the phone first.
    final body = <String, dynamic>{};
    for (final field in _allFields) {
      final text = _controllers[field.key]!.text.trim();
      if (text.isEmpty) return _showResult(error: 'Please fill in: ${field.label}');
      if (field.isNumber) {
        final number = num.tryParse(text);
        if (number == null) return _showResult(error: '${field.label} must be a number.');
        body[field.key] = number;
      } else {
        body[field.key] = text;
      }
    }

    // 2. Send them to the API.
    setState(() => _isLoading = true);
    try {
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 90));
      final data = jsonDecode(response.body);

      // 3. Show the prediction or a readable error.
      if (response.statusCode == 200) {
        _showResult(prediction: (data['predicted_words_per_minute'] as num).toDouble());
      } else if (response.statusCode == 422) {
        final messages = (data['detail'] as List).map((error) {
          final key = (error['loc'] as List).last;
          final label = _allFields
              .firstWhere((field) => field.key == key,
                  orElse: () => InputField('$key', '$key', '', Icons.error))
              .label;
          return '$label: ${error['msg']}';
        }).join('\n');
        _showResult(error: messages);
      } else {
        _showResult(error: 'Server error (${response.statusCode}). Please try again.');
      }
    } catch (_) {
      _showResult(error: 'Could not reach the server. Check your internet and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionCard(
                    title: 'About the child',
                    icon: Icons.child_care,
                    children: [for (final field in _childFields) _buildField(field)],
                  ),
                  _SectionCard(
                    title: 'Reading skills',
                    icon: Icons.auto_stories_outlined,
                    children: [for (final field in _skillFields) _buildField(field)],
                  ),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _predict,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                                SizedBox(width: 12),
                                Text('Predicting...', style: TextStyle(fontSize: 16)),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.insights),
                                SizedBox(width: 10),
                                Text('Predict',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _buildResult(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(InputField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _controllers[field.key],
        textInputAction: TextInputAction.next,
        textCapitalization: field.isNumber ? TextCapitalization.none : TextCapitalization.words,
        keyboardType: field.isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: field.label,
          hintText: field.hint,
          prefixIcon: Icon(field.icon, color: _chocolate),
        ),
      ),
    );
  }

  Widget _buildResult() {
    if (_error != null) {
      return Container(
        key: const ValueKey('error'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF2B8B5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFB3261E)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_error!,
                  style: const TextStyle(color: Color(0xFF8C1D18), fontSize: 15, height: 1.4)),
            ),
          ],
        ),
      );
    }

    if (_prediction != null) {
      final aboveAverage = _prediction! >= averageWordsPerMinute;
      return Container(
        key: ValueKey(_prediction),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _chocolate,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            const Text('Predicted reading speed',
                style: TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 8),
            Text(_prediction!.toStringAsFixed(1),
                style: const TextStyle(
                    color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold)),
            const Text('words per minute',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(aboveAverage ? Icons.trending_up : Icons.volunteer_activism,
                      color: _caramel, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      aboveAverage
                          ? 'Above the average reader (18 wpm)'
                          : 'Below average (18 wpm): may need reading support',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('empty'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: const Row(
        children: [
          Icon(Icons.lightbulb_outline, color: _chocolate),
          SizedBox(width: 12),
          Expanded(
            child: Text('Fill in the details and tap Predict to see the result here.',
                style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

/// Dark chocolate header that explains what the app does.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 16, 24, 20),
      decoration: const BoxDecoration(
        color: _chocolate,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: Column(
        children: [
          const Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
              children: [
                TextSpan(text: 'Reading '),
                TextSpan(text: 'Fluency', style: TextStyle(color: _caramel)),
                TextSpan(text: ' Predictor'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Predicts how many words a child aged 5 to 14 can read per minute, '
            'to help find children who need reading support early.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// White rounded card that groups related fields.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _chocolate.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _chocolate),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}