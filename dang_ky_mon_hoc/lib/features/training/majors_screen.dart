import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'entity_form.dart';
import 'resource_list.dart';
import 'training_api.dart';
import 'training_widgets.dart';

const _path = '/majors/';

String khoaLabel(Json k) => k.str('ten_khoa');

/// Ngành (PDT-02) — mockup `PDT-Web-Nganh`. Mỗi ngành thuộc một khoa / viện.
class MajorsScreen extends ConsumerStatefulWidget {
  const MajorsScreen({super.key});

  @override
  ConsumerState<MajorsScreen> createState() => _MajorsScreenState();
}

class _MajorsScreenState extends ConsumerState<MajorsScreen> {
  final _ctl = ResourceListController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  static const _specs = <FieldSpec>[
    TextSpec('ma_nganh', 'Mã ngành', lockedOnEdit: true, half: true),
    TextSpec(
      'thoi_gian_dao_tao',
      'Thời gian đào tạo (năm)',
      number: true,
      half: true,
    ),
    TextSpec('ten_nganh', 'Tên ngành'),
    SelectSpec(
      'khoa',
      'Khoa / viện quản lý',
      '/faculties/',
      khoaLabel,
      queryOf: _chiHoatDong,
    ),
  ];

  static Map<String, Object?> _chiHoatDong(Map<String, Json?> _) => {
    'trang_thai': 'HOAT_DONG',
  };

  Future<void> _form([Json? row]) async {
    final api = ref.read(trainingApiProvider);
    final saved = await showEntityForm(
      context,
      title: row == null ? 'Thêm ngành' : 'Sửa ngành',
      specs: _specs,
      initial: row,
      initialSelected: row == null
          ? const {}
          : {
              'khoa': {'id': row['khoa'], 'ten_khoa': row['khoa_ten']},
            },
      submit: (body) async => row == null
          ? api.create(_path, body)
          : api.update(_path, row.id, body),
    );
    if (!saved || !mounted) return;
    _ctl.reload();
  }

  void _setStatus(Json row, String status) {
    final stop = status == 'NGUNG';
    confirmAndRun(
      context,
      title: stop ? 'Ngừng ngành?' : 'Mở lại ngành?',
      message: stop
          ? 'Ngừng ngành ${row.str('ten_nganh')}? Ngành sẽ không còn dùng được cho CTĐT và hồ sơ mới; dữ liệu hiện có được giữ nguyên.'
          : 'Mở lại ngành ${row.str('ten_nganh')}?',
      actionLabel: stop ? 'Ngừng ngành' : 'Mở lại',
      danger: stop,
      call: () => ref.read(trainingApiProvider).update(_path, row.id, {
        'trang_thai': status,
      }),
      success: stop ? 'Đã ngừng ngành.' : 'Đã mở lại ngành.',
      onDone: _ctl.reload,
    );
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
                label: 'Tìm ngành',
                hint: 'Mã hoặc tên',
              ),
              SizedBox(
                width: 260,
                child: ApiSelect(
                  label: 'Khoa / viện',
                  path: '/faculties/',
                  labelOf: khoaLabel,
                  hint: 'Tất cả khoa / viện',
                  onChanged: (o) => _ctl.setFilter('khoa', o?.id),
                ),
              ),
              FilterDropdown(
                controller: _ctl,
                filterKey: 'trang_thai',
                options: dungOptions,
              ),
              AddButton('+ Thêm ngành', _form),
            ],
          ),
          const SizedBox(height: 24),
          ResourceList(
            controller: _ctl,
            path: _path,
            emptyText: 'Chưa có ngành nào.',
            columns: const [
              ListColumn('Mã ngành', width: 110),
              ListColumn('Tên ngành', flex: 3),
              ListColumn('Khoa / viện', flex: 2),
              ListColumn('Thời gian đào tạo', width: 140),
              ListColumn('Số CTĐT', width: 90),
              ListColumn('Trạng thái', width: 130),
              ListColumn('', width: 170),
            ],
            cells: (r) => [
              Text(r.str('ma_nganh'), style: monoStyle),
              Text(r.str('ten_nganh'), overflow: TextOverflow.ellipsis),
              Text(r.str('khoa_ten'), overflow: TextOverflow.ellipsis),
              Text('${r.num0('thoi_gian_dao_tao')} năm'),
              Text('${r.num0('so_ctdt')}'),
              trangThaiChip(r.str('trang_thai')),
              RowActions([
                RowButton('Sửa', () => _form(r)),
                if (r.str('trang_thai') == 'HOAT_DONG')
                  RowButton('Ngừng', () => _setStatus(r, 'NGUNG'), danger: true)
                else
                  RowButton('Mở lại', () => _setStatus(r, 'HOAT_DONG')),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}
