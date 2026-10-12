import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_failure.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/labeled_dropdown.dart';
import '../../shared/widgets/labeled_field.dart';
import '../admin/accounts/account_dialogs.dart' show failureText;
import 'training_api.dart';

/// Khai báo một ô của form thêm/sửa. Khóa [key] = tên field gửi lên API (và nhận lỗi về).
sealed class FieldSpec {
  const FieldSpec(
    this.key,
    this.label, {
    this.helper,
    this.required = true,
    this.lockedOnEdit = false,
    this.half = false,
    this.send = true,
  });

  final String key;
  final String label;
  final String? helper;
  final bool required;

  /// Không cho sửa sau khi tạo (vd mã khoa/viện).
  final bool lockedOnEdit;

  /// Chiếm nửa hàng (ghép đôi với ô kế bên khi hộp thoại đủ rộng).
  final bool half;

  /// `false` = ô chỉ để lọc/chọn, không gửi lên API (vd "Ngành" khi tạo lớp).
  final bool send;
}

class TextSpec extends FieldSpec {
  const TextSpec(
    super.key,
    super.label, {
    super.helper,
    super.required,
    super.lockedOnEdit,
    super.half,
    this.number = false,
    this.hint,
  });

  /// Số nguyên không âm: gửi lên dạng `int`.
  final bool number;
  final String? hint;
}

class ChoiceSpec extends FieldSpec {
  const ChoiceSpec(
    super.key,
    super.label,
    this.options, {
    super.helper,
    super.lockedOnEdit,
    super.half,
  });

  /// (giá trị gửi lên, nhãn). Phần tử đầu là mặc định khi tạo mới.
  final List<(Object, String)> options;
}

class DateSpec extends FieldSpec {
  const DateSpec(
    super.key,
    super.label, {
    super.helper,
    super.required,
    super.half,
  });
}

class DateTimeSpec extends FieldSpec {
  const DateTimeSpec(
    super.key,
    super.label, {
    super.helper,
    super.required,
    super.half,
  });
}

/// Ô chọn có gợi ý, tải từ API khi gõ. [queryOf] nhận các đối tượng đã chọn ở ô khác
/// (lọc liên động); khi ô trong [dependsOn] đổi thì ô này bị xóa chọn.
class SelectSpec extends FieldSpec {
  const SelectSpec(
    super.key,
    super.label,
    this.path,
    this.labelOf, {
    super.helper,
    super.required,
    super.lockedOnEdit,
    super.half,
    super.send,
    this.dependsOn = const [],
    this.queryOf,
    this.hint = 'Gõ để tìm…',
  });

  final String path;
  final String Function(Json option) labelOf;
  final List<String> dependsOn;
  final Map<String, Object?> Function(Map<String, Json?> selected)? queryOf;
  final String hint;
}

/// Mở form thêm/sửa. [initial] = giá trị hiện có của bản ghi (sửa); [initialSelected] = đối tượng
/// đã chọn của các [SelectSpec] (để hiện nhãn). [submit] nhận body, ném [ApiFailure] khi server từ chối.
/// Trả `true` nếu đã lưu.
Future<bool> showEntityForm(
  BuildContext context, {
  required String title,
  required List<FieldSpec> specs,
  required Future<void> Function(Json body) submit,
  Json? initial,
  Map<String, Json> initialSelected = const {},
  String saveLabel = 'Lưu',
  String? note,
  double maxWidth = 560,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _EntityDialog(
      title: title,
      specs: specs,
      submit: submit,
      initial: initial,
      initialSelected: initialSelected,
      saveLabel: saveLabel,
      note: note,
      maxWidth: maxWidth,
    ),
  );
  return saved ?? false;
}

class _EntityDialog extends ConsumerStatefulWidget {
  const _EntityDialog({
    required this.title,
    required this.specs,
    required this.submit,
    required this.initial,
    required this.initialSelected,
    required this.saveLabel,
    required this.note,
    required this.maxWidth,
  });

  final String title;
  final List<FieldSpec> specs;
  final Future<void> Function(Json body) submit;
  final Json? initial;
  final Map<String, Json> initialSelected;
  final String saveLabel;
  final String? note;
  final double maxWidth;

  @override
  ConsumerState<_EntityDialog> createState() => _EntityDialogState();
}

class _EntityDialogState extends ConsumerState<_EntityDialog> {
  final _text = <String, TextEditingController>{};
  final _values = <String, Object?>{}; // choice / date / datetime / select (id)
  final _selected = <String, Json?>{};
  final _errors = <String, String>{};
  String? _banner;
  bool _loading = false;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initial ?? const {};
    for (final s in widget.specs) {
      switch (s) {
        case TextSpec():
          _text[s.key] = TextEditingController(text: init.str(s.key));
        case ChoiceSpec():
          _values[s.key] = init[s.key] ?? s.options.first.$1;
        case DateSpec() || DateTimeSpec():
          _values[s.key] = init[s.key];
        case SelectSpec():
          // Tạo mới có thể đặt sẵn lựa chọn qua initialSelected (vd chọn tài khoản từ chip).
          _values[s.key] = init[s.key] ?? widget.initialSelected[s.key]?.id;
          _selected[s.key] = widget.initialSelected[s.key];
      }
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _locked(FieldSpec s) => _editing && s.lockedOnEdit;

  void _onSelect(SelectSpec s, Json? option) {
    setState(() {
      _selected[s.key] = option;
      _values[s.key] = option?.id;
      _errors.remove(s.key);
      // Ô phụ thuộc vào ô này bị xóa chọn (lọc liên động).
      for (final d in widget.specs.whereType<SelectSpec>()) {
        if (d.dependsOn.contains(s.key)) {
          _selected[d.key] = null;
          _values[d.key] = null;
        }
      }
    });
  }

  Future<void> _save() async {
    final errors = <String, String>{};
    final body = <String, Object?>{};
    for (final s in widget.specs) {
      if (_locked(s) && s is! SelectSpec) continue;
      Object? value;
      switch (s) {
        case TextSpec():
          final raw = _text[s.key]!.text.trim();
          if (raw.isEmpty && s.required) {
            errors[s.key] = 'Bắt buộc nhập.';
          } else if (s.number) {
            value = raw.isEmpty ? null : int.tryParse(raw);
            if (raw.isNotEmpty && value == null) errors[s.key] = 'Nhập số.';
          } else {
            value = raw;
          }
        default:
          value = _values[s.key];
          if (value == null && s.required && s.send) {
            errors[s.key] = 'Bắt buộc chọn.';
          }
      }
      if (s.send && !(_locked(s))) body[s.key] = value;
    }
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
        _banner = null;
      });
      return;
    }
    setState(() {
      _errors.clear();
      _banner = null;
      _loading = true;
    });
    try {
      await widget.submit(body);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiFailure catch (f) {
      if (!mounted) return;
      final keys = widget.specs.map((s) => s.key).toSet();
      final own = {
        for (final e in f.fields.entries)
          if (keys.contains(e.key)) e.key: e.value,
      };
      setState(() {
        _loading = false;
        _errors.addAll(own);
        _banner = own.isNotEmpty && own.length == f.fields.length
            ? null
            : failureText(f, 'Không thể lưu, vui lòng thử lại.');
      });
    }
  }

  Widget _field(FieldSpec s) {
    final error = _errors[s.key];
    final locked = _locked(s);
    switch (s) {
      case TextSpec():
        return LabeledField(
          label: s.label,
          controller: _text[s.key]!,
          hint: s.hint,
          helper: locked ? 'Không đổi sau khi tạo.' : s.helper,
          error: error,
          enabled: !locked,
          keyboardType: s.number ? TextInputType.number : null,
          inputFormatters: s.number
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
        );
      case ChoiceSpec():
        return LabeledDropdown<Object>(
          label: s.label,
          value: _values[s.key]!,
          options: s.options,
          helper: s.helper,
          onChanged: locked ? null : (v) => setState(() => _values[s.key] = v),
        );
      case DateSpec():
        return _PickerField(
          label: s.label,
          text: formatYmd(_values[s.key] as String?),
          empty: _values[s.key] == null,
          helper: s.helper,
          error: error,
          onTap: () async {
            final d = await _pickDate(_values[s.key] as String?);
            if (d != null) {
              setState(() => _values[s.key] = _ymd(d));
            }
          },
        );
      case DateTimeSpec():
        return _PickerField(
          label: s.label,
          text: formatIso(_values[s.key] as String?),
          empty: _values[s.key] == null,
          helper: s.helper,
          error: error,
          onTap: () async {
            final v = await _pickDateTime(_values[s.key] as String?);
            if (v != null) setState(() => _values[s.key] = v);
          },
        );
      case SelectSpec():
        final query = s.queryOf?.call(_selected) ?? const {};
        return ApiSelect(
          // Đổi bộ lọc cha → dựng lại ô để xóa chữ đang gõ và tải gợi ý mới.
          key: ValueKey('${s.key}|$query|${_selected[s.key]?.id}'),
          label: s.label,
          path: s.path,
          query: query,
          labelOf: s.labelOf,
          selected: _selected[s.key],
          hint: s.hint,
          helper: locked ? 'Không đổi sau khi tạo.' : s.helper,
          error: error,
          enabled: !locked,
          onChanged: (o) => _onSelect(s, o),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.title,
      maxWidth: widget.maxWidth,
      actions: [
        DialogButton(
          'Hủy',
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
        ),
        DialogButton(
          widget.saveLabel,
          filled: true,
          loading: _loading,
          onPressed: _save,
        ),
      ],
      child: LayoutBuilder(
        builder: (context, c) {
          final twoUp = c.maxWidth >= 460;
          final w = twoUp ? (c.maxWidth - 14) / 2 : c.maxWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.note != null) ...[
                AlertBanner(kind: BannerKind.info, message: widget.note!),
                const SizedBox(height: 14),
              ],
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final s in widget.specs)
                    SizedBox(
                      width: s.half && twoUp ? w : c.maxWidth,
                      child: _field(s),
                    ),
                ],
              ),
              if (_banner != null) ...[
                const SizedBox(height: 14),
                AlertBanner(kind: BannerKind.error, message: _banner!),
              ],
            ],
          );
        },
      ),
    );
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<DateTime?> _pickDate(String? current) => showDatePicker(
    context: context,
    initialDate: DateTime.tryParse(current ?? '') ?? DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );

  /// Chọn ngày rồi giờ; trả chuỗi ISO có múi giờ +07:00 (giờ Việt Nam, như backend).
  Future<String?> _pickDateTime(String? current) async {
    final cur = DateTime.tryParse(current ?? '')
        ?.toUtc()
        .add(const Duration(hours: 7));
    final date = await showDatePicker(
      context: context,
      initialDate: cur ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur?.hour ?? 8, minute: cur?.minute ?? 0),
    );
    if (time == null) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${_ymd(date)}T${two(time.hour)}:${two(time.minute)}:00+07:00';
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.text,
    required this.empty,
    required this.onTap,
    this.helper,
    this.error,
  });

  final String label;
  final String text;
  final bool empty;
  final VoidCallback onTap;
  final String? helper;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.label,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasError ? AppColors.danger : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      empty ? 'Chọn…' : text,
                      style: TextStyle(
                        fontSize: 15,
                        color: empty ? AppColors.muted : AppColors.text,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              helper!,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.danger,
              ),
            ),
          ),
      ],
    );
  }
}

/// Ô chọn gõ-để-tìm (design.md 1.7/1.9): tải gợi ý từ `GET path?search=…&…query`, chọn một mục.
/// Gõ lại sau khi đã chọn → bỏ chọn ([onChanged] nhận `null`).
class ApiSelect extends ConsumerStatefulWidget {
  const ApiSelect({
    super.key,
    required this.label,
    required this.path,
    required this.labelOf,
    required this.onChanged,
    this.query = const {},
    this.selected,
    this.hint = 'Gõ để tìm…',
    this.helper,
    this.error,
    this.enabled = true,
  });

  final String label;
  final String path;
  final String Function(Json option) labelOf;
  final ValueChanged<Json?> onChanged;
  final Map<String, Object?> query;
  final Json? selected;
  final String hint;
  final String? helper;
  final String? error;
  final bool enabled;

  @override
  ConsumerState<ApiSelect> createState() => _ApiSelectState();
}

class _ApiSelectState extends ConsumerState<ApiSelect> {
  Json? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  Future<Iterable<Json>> _options(TextEditingValue v) async {
    try {
      final page = await ref
          .read(trainingApiProvider)
          .list(
            widget.path,
            pageSize: 20,
            // Chữ đang hiện = nhãn đã chọn → coi như chưa lọc để mở lại thấy đủ gợi ý.
            search: _selected != null && v.text == widget.labelOf(_selected!)
                ? ''
                : v.text,
            query: widget.query,
          );
      return page.items;
    } on ApiFailure {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => RawAutocomplete<Json>(
        initialValue: TextEditingValue(
          text: _selected == null ? '' : widget.labelOf(_selected!),
        ),
        displayStringForOption: widget.labelOf,
        optionsBuilder: widget.enabled ? _options : (_) => const [],
        onSelected: (o) {
          _selected = o;
          widget.onChanged(o);
        },
        fieldViewBuilder: (context, controller, focus, onSubmit) =>
            LabeledField(
              label: widget.label,
              controller: controller,
              hint: widget.hint,
              helper: widget.helper,
              error: widget.error,
              enabled: widget.enabled,
              suffix: const Icon(Icons.arrow_drop_down, color: AppColors.muted),
              onChanged: (t) {
                if (_selected != null && t != widget.labelOf(_selected!)) {
                  _selected = null;
                  widget.onChanged(null);
                }
              },
              focusNode: focus,
            ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 240,
                maxWidth: box.maxWidth,
                minWidth: box.maxWidth,
              ),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    InkWell(
                      onTap: () => onSelected(o),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Text(
                          widget.labelOf(o),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
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
