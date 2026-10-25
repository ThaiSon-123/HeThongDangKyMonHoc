import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../training/classes_screen.dart' show hocKyLabel;
import '../training/curriculums_screen.dart' show nganhLabel;
import '../training/entity_form.dart' show ApiSelect;
import '../training/resource_list.dart';
import '../training/training_api.dart';
import '../training/training_widgets.dart';
import 'grade_sheet_panel.dart';

/// Duyệt điểm (PDT-12) — mockup `PDT-Web-DuyetDiem`: bảng lớp kèm số dòng điểm theo trạng thái; chọn
/// một lớp để xem bảng điểm cả lớp, nhập hộ, gia hạn, duyệt.
class PdtGradeSheetsScreen extends ConsumerStatefulWidget {
  const PdtGradeSheetsScreen({super.key});

  @override
  ConsumerState<PdtGradeSheetsScreen> createState() =>
      _PdtGradeSheetsScreenState();
}

class _PdtGradeSheetsScreenState extends ConsumerState<PdtGradeSheetsScreen> {
  final _ctl = ResourceListController();
  int? _sel;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  int _chuaNhap(Json r) =>
      (r.num0('so_sv') -
              r.num0('nhap_tam') -
              r.num0('chinh_thuc') -
              r.num0('khoa'))
          .clamp(0, 1 << 30);

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListToolbar(
          children: [
            SearchBox(
              controller: _ctl,
              label: 'Tìm lớp',
              hint: 'Mã lớp hoặc tên môn',
            ),
            SizedBox(
              width: 210,
              child: ApiSelect(
                label: 'Học kỳ',
                path: '/semesters/',
                labelOf: hocKyLabel,
                hint: 'Tất cả học kỳ',
                onChanged: (o) => _ctl.setFilter('hoc_ky', o?.id),
              ),
            ),
            SizedBox(
              width: 210,
              child: ApiSelect(
                label: 'Ngành',
                path: '/majors/',
                labelOf: nganhLabel,
                hint: 'Tất cả ngành',
                onChanged: (o) => _ctl.setFilter('nganh', o?.id),
              ),
            ),
            FilterDropdown(
              controller: _ctl,
              filterKey: 'trang_thai',
              options: const [
                ('', 'Tất cả'),
                ('DANG_HOC', 'Đang học'),
                ('DA_DONG', 'Đã đóng'),
              ],
              label: 'Nhóm lớp',
            ),
          ],
        ),
        const SizedBox(height: 24),
        ResourceList(
          controller: _ctl,
          path: '/grade-sheets/',
          minWidth: 1000,
          emptyText: 'Chưa có lớp nào đang học hoặc đã đóng.',
          onRowTap: (r) => setState(() => _sel = _sel == r.id ? null : r.id),
          rowDetail: (r) => r.id != _sel
              ? null
              : GradeSheetPanel(
                  key: ValueKey(_sel),
                  lopId: _sel!,
                  isPdt: true,
                  onChanged: _ctl.reload,
                ),
          columns: const [
            ListColumn('Mã lớp', width: 150),
            ListColumn('Môn học', flex: 2),
            ListColumn('Giáo viên', flex: 2),
            ListColumn('Số SV', width: 70),
            ListColumn('Trạng thái điểm', flex: 3),
            ListColumn('Lớp', width: 110),
          ],
          cells: (r) => [
            Text(r.str('ma_lop'), style: monoStyle),
            Text(r.str('ten_mon'), overflow: TextOverflow.ellipsis),
            Text(r.str('giao_vien_ten'), overflow: TextOverflow.ellipsis),
            Text('${r.num0('so_sv')}'),
            Text(
              'Nháp ${r.num0('nhap_tam')} · Chính thức ${r.num0('chinh_thuc')} · Đã khóa ${r.num0('khoa')} · '
              'Chưa nhập ${_chuaNhap(r)}',
              style: const TextStyle(fontSize: 12),
            ),
            trangThaiChip(r.str('trang_thai')),
          ],
        ),
      ],
    ),
  );
}
