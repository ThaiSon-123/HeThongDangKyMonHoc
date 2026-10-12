import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_failure.dart';
import '../../core/download/save_file.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/labeled_dropdown.dart';
import '../admin/accounts/account_dialogs.dart' show failureText;
import 'classes_screen.dart' show hocKyLabel;
import 'courses_screen.dart' show monLabel;
import 'curriculums_screen.dart' show nganhLabel;
import 'entity_form.dart';
import 'resource_list.dart';
import 'training_api.dart';
import 'training_widgets.dart';

const _path = '/registrations/';

/// Hàm lưu tệp, thay được trong test (bản thật tải qua trình duyệt).
final saveFileProvider =
    Provider<Future<void> Function(String, List<int>, {String? mime})>(
      (ref) => saveFile,
    );

/// Theo dõi đăng ký & hủy hộ (PDT-10/11) — mockup `PDT-Web-DangKy`.
class RegistrationsScreen extends ConsumerStatefulWidget {
  const RegistrationsScreen({super.key});

  @override
  ConsumerState<RegistrationsScreen> createState() =>
      _RegistrationsScreenState();
}

class _RegistrationsScreenState extends ConsumerState<RegistrationsScreen> {
  final _ctl = ResourceListController();
  Json? _hocKy, _nganh, _mon;
  String _trangThai = '';

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  static const _trangThaiOpts = <(String, String)>[
    ('', 'Tất cả'),
    ('DA_DANG_KY', 'Đã đăng ký'),
    ('DA_HUY', 'Đã hủy'),
  ];

  Future<void> _cancelFor(Json r) async {
    final api = ref.read(trainingApiProvider);
    final saved = await showEntityForm(
      context,
      title: 'Hủy đăng ký hộ sinh viên',
      saveLabel: 'Hủy đăng ký',
      note:
          '${r.str('ho_ten')} (${r.str('ma_sv')}) — ${r.str('ten_mon')}, lớp ${r.str('ma_lop')}.\n'
          'Hậu quả: sĩ số lớp −1 · học phí của sinh viên được tính lại · nếu sinh viên đã đóng dư '
          'sẽ phát sinh cần hoàn tiền cho Kế toán.',
      specs: const [TextSpec('ly_do', 'Lý do hủy (bắt buộc)')],
      submit: (body) => api.cancel(_path, r.id, body),
    );
    if (!saved || !mounted) return;
    _ctl.reload();
    showAppToast(context, 'Đã hủy đăng ký hộ sinh viên.');
  }

  Future<void> _export() async {
    try {
      final bytes = await ref
          .read(trainingApiProvider)
          .getBytes(
            '${_path}export/',
            query: {..._ctl.filters, 'search': _ctl.search},
          );
      await ref.read(saveFileProvider)(
        'dang_ky_mon_hoc.xlsx',
        bytes,
        mime:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (mounted) showAppToast(context, 'Đã xuất tệp Excel.');
    } on ApiFailure catch (f) {
      if (mounted) {
        showAppToast(context, failureText(f, 'Không xuất được tệp Excel.'));
      }
    } on UnsupportedError {
      if (mounted) showAppToast(context, 'Chỉ xuất được tệp trên bản Web.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListToolbar(
            children: [
              SearchBox(
                controller: _ctl,
                label: 'Tìm sinh viên / lớp',
                hint: 'Mã SV, họ tên, mã lớp, môn',
              ),
              SizedBox(
                width: 210,
                child: ApiSelect(
                  key: ValueKey('hk-${_hocKy?.id}'),
                  label: 'Học kỳ',
                  path: '/semesters/',
                  labelOf: hocKyLabel,
                  hint: 'Tất cả học kỳ',
                  onChanged: (o) {
                    _hocKy = o;
                    _ctl.setFilter('hoc_ky', o?.id);
                  },
                ),
              ),
              SizedBox(
                width: 210,
                child: ApiSelect(
                  label: 'Ngành',
                  path: '/majors/',
                  labelOf: nganhLabel,
                  hint: 'Tất cả ngành',
                  onChanged: (o) {
                    setState(() {
                      _nganh = o;
                      _mon = null;
                    });
                    _ctl
                      ..filters.remove('mon_hoc')
                      ..setFilter('nganh', o?.id);
                  },
                ),
              ),
              SizedBox(
                width: 240,
                child: ApiSelect(
                  key: ValueKey('mon-${_nganh?.id}'),
                  label: 'Môn học',
                  path: '/courses/',
                  query: {'nganh': _nganh?.id},
                  labelOf: monLabel,
                  hint: 'Tất cả môn',
                  onChanged: (o) {
                    _mon = o;
                    _ctl.setFilter('mon_hoc', o?.id);
                  },
                ),
              ),
              SizedBox(
                width: 260,
                child: ApiSelect(
                  key: ValueKey('lop-${_hocKy?.id}-${_mon?.id}'),
                  label: 'Lớp học phần',
                  path: '/class-sections/',
                  query: {'hoc_ky': _hocKy?.id, 'mon_hoc': _mon?.id},
                  labelOf: (l) => l.str('ma_lop'),
                  hint: 'Tất cả lớp',
                  onChanged: (o) => _ctl.setFilter('lop_hoc_phan', o?.id),
                ),
              ),
              SizedBox(
                width: 170,
                child: LabeledDropdown<String>(
                  label: 'Trạng thái',
                  value: _trangThai,
                  options: _trangThaiOpts,
                  onChanged: (v) {
                    setState(() => _trangThai = v);
                    _ctl.setFilter('trang_thai', v.isEmpty ? null : v);
                  },
                ),
              ),
              SizedBox(
                width: 140,
                child: AppButton(
                  label: 'Xuất Excel',
                  height: 44,
                  outlined: true,
                  onPressed: _export,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ResourceList(
            controller: _ctl,
            path: _path,
            minWidth: 1100,
            emptyText: 'Không có đăng ký phù hợp với bộ lọc.',
            columns: const [
              ListColumn('Mã SV', width: 110),
              ListColumn('Họ tên', flex: 2),
              ListColumn('Ngành', flex: 2),
              ListColumn('Môn · Lớp', flex: 3),
              ListColumn('Ngày ĐK', width: 140),
              ListColumn('Trạng thái', width: 120),
              ListColumn('Lý do hủy', flex: 2),
              ListColumn('', width: 100),
            ],
            cells: (r) {
              final dangKy = r.str('trang_thai') == 'DA_DANG_KY';
              final huyDuoc =
                  dangKy &&
                  const ['MO', 'DANG_HOC'].contains(r.str('lop_trang_thai'));
              return [
                Text(r.str('ma_sv'), style: monoStyle),
                Text(r.str('ho_ten'), overflow: TextOverflow.ellipsis),
                Text(r.str('nganh_ten'), overflow: TextOverflow.ellipsis),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.str('ten_mon'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      r.str('ma_lop'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                Text(
                  formatIso(r.str('ngay_dang_ky')),
                  style: const TextStyle(fontSize: 13),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: dangKy
                      ? const _Chip('Đã đăng ký', true)
                      : const _Chip('Đã hủy', false),
                ),
                Text(
                  r.str('ly_do_huy').isEmpty ? '—' : r.str('ly_do_huy'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                huyDuoc
                    ? RowActions([
                        RowButton('Hủy hộ', () => _cancelFor(r), danger: true),
                      ])
                    : const SizedBox.shrink(),
              ];
            },
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.green);

  final String label;
  final bool green;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: green ? const Color(0xFFE6F4EA) : const Color(0xFFECEFF1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: green ? const Color(0xFF2E7D32) : const Color(0xFF455A64),
      ),
    ),
  );
}
