import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'curriculums_screen.dart' show nganhLabel;
import 'entity_form.dart';
import 'majors_screen.dart' show khoaLabel;
import 'resource_list.dart';
import 'training_api.dart';
import 'training_widgets.dart';

const _studentsPath = '/profiles/students/';
const _teachersPath = '/profiles/teachers/';
const _pendingPath = '/profiles/pending-accounts/';

String _roleText(String role) =>
    role == 'SINH_VIEN' ? 'Sinh viên' : 'Giáo viên';

String _accountLabel(Json u) => u.str('username');

/// Hồ sơ SV/GV (PDT-01) — mockup `PDT-Web-HoSo`: tài khoản chưa có hồ sơ, hai tab Sinh viên / Giáo viên.
class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({super.key});

  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  int _tab = 0;
  final _students = ResourceListController();
  final _teachers = ResourceListController();
  late Future<List<Json>> _pending;

  @override
  void initState() {
    super.initState();
    _pending = _loadPending();
  }

  @override
  void dispose() {
    _students.dispose();
    _teachers.dispose();
    super.dispose();
  }

  Future<List<Json>> _loadPending() => ref
      .read(trainingApiProvider)
      .list(_pendingPath, pageSize: 50)
      .then((p) => p.items);

  void _reloadAll() {
    _students.reload();
    _teachers.reload();
    final next = _loadPending();
    setState(() {
      _pending = next;
    });
  }

  ResourceListController get _ctl => _tab == 0 ? _students : _teachers;

  static Map<String, Object?> _taiKhoan(String role) => {'role': role};

  List<FieldSpec> _specs(bool student) => student
      ? [
          SelectSpec(
            'user',
            'Tài khoản (đã có, chưa có hồ sơ)',
            _pendingPath,
            _accountLabel,
            lockedOnEdit: true,
            queryOf: (_) => _taiKhoan('SINH_VIEN'),
            helper: 'Chỉ hiện tài khoản chưa có hồ sơ.',
          ),
          const TextSpec(
            'ma_sv',
            'Mã sinh viên',
            lockedOnEdit: true,
            half: true,
          ),
          const TextSpec('ho_ten', 'Họ tên', half: true),
          SelectSpec(
            'nganh',
            'Ngành',
            '/majors/',
            nganhLabel,
            lockedOnEdit: true,
            half: true,
            queryOf: (_) => {'trang_thai': 'HOAT_DONG'},
          ),
          const TextSpec(
            'khoa_nhap_hoc',
            'Khóa nhập học',
            lockedOnEdit: true,
            half: true,
            hint: 'VD: K2023',
          ),
          const TextSpec('email', 'Email', required: false, half: true),
          const TextSpec('sdt', 'Số điện thoại', required: false, half: true),
        ]
      : [
          SelectSpec(
            'user',
            'Tài khoản (đã có, chưa có hồ sơ)',
            _pendingPath,
            _accountLabel,
            lockedOnEdit: true,
            queryOf: (_) => _taiKhoan('GIAO_VIEN'),
            helper: 'Chỉ hiện tài khoản chưa có hồ sơ.',
          ),
          const TextSpec(
            'ma_gv',
            'Mã giáo viên',
            lockedOnEdit: true,
            half: true,
          ),
          const TextSpec('ho_ten', 'Họ tên', half: true),
          SelectSpec(
            'khoa',
            'Khoa / viện',
            '/faculties/',
            khoaLabel,
            half: true,
            queryOf: (_) => {'trang_thai': 'HOAT_DONG'},
          ),
          const TextSpec('hoc_vi', 'Học vị', required: false, half: true),
          const TextSpec('email', 'Email', required: false, half: true),
          const TextSpec('sdt', 'Số điện thoại', required: false, half: true),
        ];

  Future<void> _form(bool student, {Json? row, Json? account}) async {
    final api = ref.read(trainingApiProvider);
    final path = student ? _studentsPath : _teachersPath;
    final saved = await showEntityForm(
      context,
      title: row == null ? 'Tạo hồ sơ' : 'Sửa hồ sơ',
      saveLabel: row == null ? 'Lưu hồ sơ' : 'Lưu',
      specs: _specs(student),
      initial: row,
      note: student && row == null
          ? 'CTĐT được chọn theo ngành và khóa. Sau khi lưu sẽ không sửa được.'
          : null,
      initialSelected: {
        'user': ?(row == null
            ? account
            : {'id': row['user'], 'username': row['username']}),
        if (row != null && student)
          'nganh': {'id': row['nganh'], 'ten_nganh': row['nganh_ten']},
        if (row != null && !student)
          'khoa': {'id': row['khoa'], 'ten_khoa': row['khoa_ten']},
      },
      submit: (body) async =>
          row == null ? api.create(path, body) : api.update(path, row.id, body),
    );
    if (saved && mounted) _reloadAll();
  }

  Widget _pendingCard() => FutureBuilder<List<Json>>(
    future: _pending,
    builder: (context, snap) {
      final items = snap.data ?? const <Json>[];
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tài khoản chưa có hồ sơ',
                      style: sectionTitleStyle,
                    ),
                  ),
                  Text(
                    '${items.length} tài khoản',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final u in items)
                    ActionChip(
                      label: Text(
                        '${u.str('username')} · ${_roleText(u.str('role'))} — Tạo hồ sơ',
                      ),
                      onPressed: () {
                        setState(
                          () => _tab = u.str('role') == 'SINH_VIEN' ? 0 : 1,
                        );
                        _form(u.str('role') == 'SINH_VIEN', account: u);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final student = _tab == 0;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pendingCard(),
          TabsRow(
            labels: const ['Sinh viên', 'Giáo viên'],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 20),
          ListToolbar(
            // Đổi tab dựng lại thanh lọc (ô tìm kiếm / bộ lọc riêng từng tab).
            key: ValueKey('toolbar-$_tab'),
            children: [
              SearchBox(
                controller: _ctl,
                label: 'Tìm theo mã / họ tên',
                hint: student ? 'Mã SV hoặc họ tên' : 'Mã GV hoặc họ tên',
              ),
              SizedBox(
                width: 260,
                child: student
                    ? ApiSelect(
                        label: 'Ngành',
                        path: '/majors/',
                        labelOf: nganhLabel,
                        hint: 'Tất cả ngành',
                        onChanged: (o) => _ctl.setFilter('nganh', o?.id),
                      )
                    : ApiSelect(
                        label: 'Khoa / viện',
                        path: '/faculties/',
                        labelOf: khoaLabel,
                        hint: 'Tất cả khoa / viện',
                        onChanged: (o) => _ctl.setFilter('khoa', o?.id),
                      ),
              ),
              AddButton('+ Tạo hồ sơ', () => _form(student)),
            ],
          ),
          const SizedBox(height: 24),
          if (student)
            ResourceList(
              key: const ValueKey('students'),
              controller: _students,
              path: _studentsPath,
              emptyText: 'Chưa có hồ sơ sinh viên nào.',
              minWidth: 1000,
              columns: const [
                ListColumn('Mã SV', width: 120),
                ListColumn('Họ tên', flex: 2),
                ListColumn('Ngành', flex: 2),
                ListColumn('Khóa', width: 90),
                ListColumn('CTĐT', flex: 2),
                ListColumn('GPA', width: 70),
                ListColumn('TC tích lũy', width: 100),
                ListColumn('', width: 80),
              ],
              cells: (r) => [
                Text(r.str('ma_sv'), style: monoStyle),
                Text(r.str('ho_ten'), overflow: TextOverflow.ellipsis),
                Text(r.str('nganh_ten'), overflow: TextOverflow.ellipsis),
                Text(r.str('khoa_nhap_hoc')),
                Text(
                  r.str('ctdt_ma'),
                  style: monoStyle,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(r['gpa'] == null ? '—' : r.str('gpa')),
                Text('${r.num0('tin_chi_tich_luy')}'),
                RowActions([RowButton('Sửa', () => _form(true, row: r))]),
              ],
            )
          else
            ResourceList(
              key: const ValueKey('teachers'),
              controller: _teachers,
              path: _teachersPath,
              emptyText: 'Chưa có hồ sơ giáo viên nào.',
              minWidth: 900,
              columns: const [
                ListColumn('Mã GV', width: 120),
                ListColumn('Họ tên', flex: 2),
                ListColumn('Khoa / viện', flex: 2),
                ListColumn('Học vị', width: 130),
                ListColumn('Email', flex: 2),
                ListColumn('', width: 80),
              ],
              cells: (r) => [
                Text(r.str('ma_gv'), style: monoStyle),
                Text(r.str('ho_ten'), overflow: TextOverflow.ellipsis),
                Text(r.str('khoa_ten'), overflow: TextOverflow.ellipsis),
                Text(r.str('hoc_vi').isEmpty ? '—' : r.str('hoc_vi')),
                Text(r.str('email'), overflow: TextOverflow.ellipsis),
                RowActions([RowButton('Sửa', () => _form(false, row: r))]),
              ],
            ),
        ],
      ),
    );
  }
}
