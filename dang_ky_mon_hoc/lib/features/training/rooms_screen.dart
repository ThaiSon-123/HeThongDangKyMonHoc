import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'entity_form.dart';
import 'resource_list.dart';
import 'training_api.dart';
import 'training_widgets.dart';

const _path = '/rooms/';

const _loai = <(String, String)>[
  ('LY_THUYET', 'Lý thuyết'),
  ('THUC_HANH', 'Thực hành'),
];

String _tenLoai(String v) =>
    _loai.firstWhere((e) => e.$1 == v, orElse: () => (v, v)).$2;

/// Phòng học: mã, sức chứa, loại. Xóa được khi phòng chưa có lịch học.
class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  final _ctl = ResourceListController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  static const _specs = <FieldSpec>[
    TextSpec('ma', 'Mã phòng', lockedOnEdit: true, hint: 'VD: A101, LAB01'),
    TextSpec('suc_chua', 'Sức chứa', number: true, half: true),
    ChoiceSpec('loai', 'Loại phòng', _loai, half: true),
  ];

  Future<void> _form([Json? row]) async {
    final api = ref.read(trainingApiProvider);
    final saved = await showEntityForm(
      context,
      title: row == null ? 'Thêm phòng học' : 'Sửa phòng học',
      specs: _specs,
      initial: row,
      submit: (body) async => row == null
          ? api.create(_path, body)
          : api.update(_path, row.id, body),
    );
    if (!saved || !mounted) return;
    _ctl.reload();
  }

  void _delete(Json row) => confirmAndRun(
    context,
    title: 'Xóa phòng học?',
    message:
        'Xóa phòng ${row.str('ma')}? Chỉ xóa được khi phòng chưa có lịch học.',
    actionLabel: 'Xóa phòng',
    danger: true,
    call: () => ref.read(trainingApiProvider).delete(_path, row.id),
    success: 'Đã xóa phòng ${row.str('ma')}.',
    onDone: _ctl.reload,
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListToolbar(
            children: [
              SearchBox(controller: _ctl, label: 'Tìm phòng', hint: 'Mã phòng'),
              FilterDropdown(
                controller: _ctl,
                filterKey: 'loai',
                options: const [('', 'Tất cả'), ..._loai],
              ),
              AddButton('+ Thêm phòng', _form),
            ],
          ),
          const SizedBox(height: 24),
          ResourceList(
            controller: _ctl,
            path: _path,
            emptyText: 'Chưa có phòng học nào.',
            columns: const [
              ListColumn('Mã phòng', flex: 2),
              ListColumn('Sức chứa', width: 110),
              ListColumn('Loại', width: 130),
              ListColumn('', width: 170),
            ],
            cells: (r) => [
              Text(r.str('ma'), style: monoStyle),
              Text('${r.num0('suc_chua')}'),
              Text(_tenLoai(r.str('loai'))),
              RowActions([
                RowButton('Sửa', () => _form(r)),
                RowButton('Xóa', () => _delete(r), danger: true),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}
