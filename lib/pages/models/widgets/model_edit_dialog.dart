import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/sci_colors.dart';
import '../../../models/model_config.dart';

/// 打开添加 / 编辑模型弹窗。
/// 返回填写的 [ModelConfig]；取消时返回 null。
Future<ModelConfig?> showModelEditDialog(
  BuildContext context, {
  ModelConfig? initial,
}) {
  return showDialog<ModelConfig>(
    context: context,
    builder: (_) => _ModelEditDialog(initial: initial),
  );
}

/// 快捷预设：一键填充常用厂商的模型配置
class _Preset {
  const _Preset({
    required this.name,
    required this.modelId,
    required this.baseUrl,
    this.supportsVision = false,
    this.maxTokens,
  });

  final String name;
  final String modelId;
  final String baseUrl;
  final bool supportsVision;

  /// 该模型允许的 max_tokens 上限（如 GLM-4V-Flash 仅 1024）
  final int? maxTokens;
}

const _presets = <_Preset>[
  _Preset(
    name: 'DeepSeek V4 Flash',
    modelId: 'deepseek-v4-flash',
    baseUrl: 'https://api.deepseek.com/v1',
    supportsVision: false,
  ),
  _Preset(
    name: 'DeepSeek V4 Pro',
    modelId: 'deepseek-v4-pro',
    baseUrl: 'https://api.deepseek.com/v1',
    supportsVision: false,
  ),
  _Preset(
    name: 'OpenAI GPT-4o',
    modelId: 'gpt-4o',
    baseUrl: 'https://api.openai.com/v1',
    supportsVision: true,
  ),
  _Preset(
    name: '智谱 GLM-4',
    modelId: 'glm-4',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    supportsVision: false,
  ),
  _Preset(
    name: '硅基流动 Qwen2.5-7B',
    modelId: 'Qwen/Qwen2.5-7B-Instruct',
    baseUrl: 'https://api.siliconflow.cn/v1',
    supportsVision: false,
  ),
  _Preset(
    name: '硅基流动 Qwen2.5-Coder',
    modelId: 'Qwen/Qwen2.5-Coder-7B-Instruct',
    baseUrl: 'https://api.siliconflow.cn/v1',
    supportsVision: false,
  ),
  _Preset(
    name: '硅基流动 GLM-4-9B',
    modelId: 'THUDM/glm-4-9b-chat',
    baseUrl: 'https://api.siliconflow.cn/v1',
    supportsVision: false,
  ),
  _Preset(
    name: '智谱 GLM-4V-Flash（免费看图）',
    modelId: 'glm-4v-flash',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    supportsVision: true,
    maxTokens: 1024,
  ),
  _Preset(
    name: '硅基流动 Qwen2.5-VL（看图）',
    modelId: 'Qwen/Qwen2.5-VL-7B-Instruct',
    baseUrl: 'https://api.siliconflow.cn/v1',
    supportsVision: true,
  ),
];

class _ModelEditDialog extends StatefulWidget {
  const _ModelEditDialog({this.initial});

  final ModelConfig? initial;

  @override
  State<_ModelEditDialog> createState() => _ModelEditDialogState();
}

class _ModelEditDialogState extends State<_ModelEditDialog> {
  late final bool _isEditing = widget.initial != null;

  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl =
      TextEditingController(text: widget.initial?.displayName ?? '');
  late final _modelIdCtrl =
      TextEditingController(text: widget.initial?.modelId ?? '');
  late final _baseUrlCtrl =
      TextEditingController(text: widget.initial?.baseUrl ?? '');
  late final _apiKeyCtrl =
      TextEditingController(text: _cleanApiKey(widget.initial?.apiKey));
  late final bool _keyWasInvalid = !_isCleanKey(widget.initial?.apiKey);
  late final _tempCtrl =
      TextEditingController(text: (widget.initial?.temperature ?? 0.7).toString());
  late final _maxTokensCtrl =
      TextEditingController(text: (widget.initial?.maxTokens ?? 4096).toString());
  late final List<_HeaderRow> _headers = [
    for (final e in (widget.initial?.headers ?? const <String, String>{}).entries)
      _HeaderRow(nameCtrl: TextEditingController(text: e.key), valueCtrl: TextEditingController(text: e.value)),
    if ((widget.initial?.headers ?? const <String, String>{}).isEmpty) _HeaderRow(),
  ];
  bool _obscureKey = true;
  bool _showAdvanced = false;
  bool _showHeaders = false;
  late bool _supportsVision = widget.initial?.supportsVision ?? false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _modelIdCtrl.dispose();
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _tempCtrl.dispose();
    _maxTokensCtrl.dispose();
    for (final h in _headers) {
      h.dispose();
    }
    super.dispose();
  }

  void _applyPreset(_Preset preset) {
    setState(() {
      _nameCtrl.text = preset.name;
      _modelIdCtrl.text = preset.modelId;
      _baseUrlCtrl.text = preset.baseUrl;
      _supportsVision = preset.supportsVision;
      if (preset.maxTokens != null) {
        _maxTokensCtrl.text = '${preset.maxTokens}';
      }
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final initial = widget.initial;
    Navigator.of(context).pop(ModelConfig(
      id: initial?.id ?? const Uuid().v4(),
      displayName: _nameCtrl.text.trim(),
      modelId: _modelIdCtrl.text.trim(),
      baseUrl: _baseUrlCtrl.text.trim(),
      apiKey: _apiKeyCtrl.text.trim(),
      temperature: double.tryParse(_tempCtrl.text) ?? 0.7,
      maxTokens: int.tryParse(_maxTokensCtrl.text) ?? 4096,
      isDefault: initial?.isDefault ?? false,
      supportsVision: _supportsVision,
      createdAt: initial?.createdAt ?? DateTime.now(),
      headers: {
        for (final h in _headers)
          if (h.nameCtrl.text.trim().isNotEmpty &&
              h.valueCtrl.text.trim().isNotEmpty)
            h.nameCtrl.text.trim(): h.valueCtrl.text.trim(),
      },
    ));
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? '此项必填' : null;

  static bool _isCleanKey(String? key) {
    if (key == null || key.isEmpty) return true;
    return !key.contains('\n') &&
        !key.contains('\r') &&
        key.length <= 512;
  }

  static String _cleanApiKey(String? key) =>
      _isCleanKey(key) ? (key ?? '') : '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: SciColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SciColors.border),
            boxShadow: [BoxShadow(color: SciColors.glow, blurRadius: 24)],
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isEditing ? '编辑模型' : '添加模型',
                          style: const TextStyle(
                            color: SciColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(
                          Icons.close_rounded,
                          color: SciColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '快捷预设 · 点击自动填充',
                    style: TextStyle(
                      color: SciColors.textSecondaryOf(context),
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in _presets)
                        InkWell(
                          onTap: () => _applyPreset(p),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: SciColors.primary.withValues(alpha: 0.4),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              p.name,
                              style: TextStyle(
                                color: SciColors.primary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _field('显示名称', _nameCtrl,
                      hint: 'DeepSeek V4 Flash', validator: _required),
                  const SizedBox(height: 12),
                  _field('Model ID', _modelIdCtrl,
                      hint: 'deepseek-v4-flash',
                      helper: '即请求体中的 model 参数，如 deepseek-v4-flash',
                      validator: _required),
                  const SizedBox(height: 12),
                  _field('API Base URL', _baseUrlCtrl,
                      hint: 'https://api.deepseek.com/v1',
                      validator: _required),
                  const SizedBox(height: 12),
                  _keyField(),
                  const SizedBox(height: 8),
                  _sectionToggle(
                    '高级参数',
                    _showAdvanced,
                    () => setState(() => _showAdvanced = !_showAdvanced),
                  ),
                  if (_showAdvanced) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _field('Temperature', _tempCtrl, hint: '0.7'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field('Max Tokens', _maxTokensCtrl,
                              hint: '4096'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '支持图片输入（视觉模型）',
                            style: TextStyle(
                              color: SciColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Switch(
                          value: _supportsVision,
                          activeThumbColor: SciColors.primary,
                          onChanged: (v) =>
                              setState(() => _supportsVision = v),
                        ),
                      ],
                    ),
                    Text(
                      '关闭时图片仅本地展示，不随消息发送（文本模型必须关闭）',
                      style: const TextStyle(
                        color: SciColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _sectionToggle(
                    '请求头',
                    _showHeaders,
                    () => setState(() => _showHeaders = !_showHeaders),
                  ),
                  if (_showHeaders) ...[
                    const SizedBox(height: 8),
                    for (final h in _headers)
                      Row(
                        children: [
                          Expanded(
                            child: _field('名称', h.nameCtrl,
                                hint: 'Authorization'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _field('值', h.valueCtrl, hint: 'Bearer xxx'),
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => _headers.remove(h)),
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: SciColors.textSecondary,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => _headers.add(_HeaderRow())),
                        icon: Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: SciColors.primary,
                        ),
                        label: Text(
                          '添加请求头',
                          style: TextStyle(
                            color: SciColors.primary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          '取消',
                          style: TextStyle(color: SciColors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _save,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [SciColors.primary, SciColors.secondary],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: SciColors.neonShadow(blur: 10),
                          ),
                          child: Text(
                            _isEditing ? '保存修改' : '保存模型',
                            style: const TextStyle(
                              color: Color(0xFF00222B),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String? hint,
    String? helper,
    FormFieldValidator<String>? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: SciColors.textSecondary,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          validator: validator,
          style: const TextStyle(color: SciColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            isDense: true,
            helperStyle: const TextStyle(
              color: SciColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _keyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'API Key',
          style: TextStyle(
            color: SciColors.textSecondary,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: _apiKeyCtrl,
          obscureText: _obscureKey,
          validator: _required,
          style: const TextStyle(color: SciColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'sk-...',
            helperText: _keyWasInvalid
                ? '检测到原 Key 异常，已清空，请重新填写'
                : null,
            isDense: true,
            helperStyle: const TextStyle(
              color: SciColors.danger,
              fontSize: 10,
            ),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureKey = !_obscureKey),
              icon: Icon(
                _obscureKey
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 18,
                color: SciColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionToggle(String label, bool open, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Icon(
            open
                ? Icons.keyboard_arrow_down_rounded
                : Icons.keyboard_arrow_right_rounded,
            color: SciColors.primary,
            size: 20,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: SciColors.primary,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow {
  _HeaderRow({TextEditingController? nameCtrl, TextEditingController? valueCtrl})
      : nameCtrl = nameCtrl ?? TextEditingController(),
        valueCtrl = valueCtrl ?? TextEditingController();

  final TextEditingController nameCtrl;
  final TextEditingController valueCtrl;

  void dispose() {
    nameCtrl.dispose();
    valueCtrl.dispose();
  }
}
