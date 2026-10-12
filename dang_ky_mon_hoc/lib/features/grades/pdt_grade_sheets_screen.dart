import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
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
          onRowTap: (r) => setState(() => _sel = r.id),
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
        const SizedBox(height: 24),
        if (_sel == null)
          const PanelCard(
            child: Text(
              'Chọn một lớp ở bảng trên để xem bảng điểm cả lớp và các thao tác.',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          )
        else
          GradeSheetPanel(
            key: ValueKey(_sel),
            lopId: _sel!,
            isPdt: true,
            onChanged: _ctl.reload,
          ),
      ],
    ),
  );
}
