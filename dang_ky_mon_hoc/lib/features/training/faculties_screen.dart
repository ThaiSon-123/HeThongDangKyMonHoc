import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'entity_form.dart';
import 'resource_list.dart';
import 'training_api.dart';
import 'training_widgets.dart';

const _path = '/faculties/';

/// Khoa / viện (PDT-02) — mockup `PDT-Web-KhoaVien`. Không xóa, chỉ ngừng.
class FacultiesScreen extends ConsumerStatefulWidget {
  const FacultiesScreen({super.key});

  @override
  ConsumerState<FacultiesScreen> createState() => _FacultiesScreenState();
}

class _FacultiesScreenState extends ConsumerState<FacultiesScreen> {
  final _ctl = ResourceListController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  static const _specs = <FieldSpec>[
    TextSpec('ma_khoa', 'Mã khoa / viện', lockedOnEdit: true),
    TextSpec('ten_khoa', 'Tên khoa / viện'),
  ];

  Future<void> _form([Json? row]) async {
    final api = ref.read(trainingApiProvider);
    final saved = await showEntityForm(
      context,
      title: row == null ? 'Thêm khoa / viện' : 'Sửa khoa / viện',
      specs: _specs,
      initial: row,
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
      title: stop ? 'Ngừng khoa / viện?' : 'Mở lại khoa / viện?',
      message: stop
          ? 'Ngừng ${row.str('ten_khoa')}? Chỉ ngừng được khi không còn ngành hoặc giáo viên đang hoạt động thuộc khoa / viện này.'
          : 'Mở lại ${row.str('ten_khoa')}?',
      actionLabel: stop ? 'Ngừng khoa / viện' : 'Mở lại',
      danger: stop,
      call: () => ref.read(trainingApiProvider).update(_path, row.id, {
        'trang_thai': status,
      }),
      success: stop ? 'Đã ngừng khoa / viện.' : 'Đã mở lại khoa / viện.',
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
                label: 'Tìm khoa / viện',
                hint: 'Mã hoặc tên',
              ),
              FilterDropdown(
                controller: _ctl,
                filterKey: 'trang_thai',
                options: dungOptions,
              ),
              AddButton('+ Thêm khoa / viện', _form),
            ],
          ),
          const SizedBox(height: 24),
          ResourceList(
            controller: _ctl,
            path: _path,
            emptyText: 'Chưa có khoa / viện nào.',
            columns: const [
              ListColumn('Mã', width: 110),
              ListColumn('Tên khoa / viện', flex: 3),
              ListColumn('Ngành', width: 90),
              ListColumn('Giáo viên', width: 100),
              ListColumn('Môn học', width: 100),
              ListColumn('Trạng thái', width: 130),
              ListColumn('', width: 170),
            ],
            cells: (r) => [
              Text(r.str('ma_khoa'), style: monoStyle),
              Text(r.str('ten_khoa'), overflow: TextOverflow.ellipsis),
              Text('${r.num0('so_nganh')}'),
              Text('${r.num0('so_giao_vien')}'),
              Text('${r.num0('so_mon')}'),
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
