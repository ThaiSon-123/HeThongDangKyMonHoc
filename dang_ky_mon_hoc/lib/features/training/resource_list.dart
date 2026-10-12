import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/page_result.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/labeled_dropdown.dart';
import '../../shared/widgets/labeled_field.dart';
import 'training_api.dart';

/// Trạng thái truy vấn của một danh sách: tìm kiếm, bộ lọc, trang. Đổi bộ lọc → về trang 1.
class ResourceListController extends ChangeNotifier {
  String search = '';
  int page = 1;
  final Map<String, Object?> filters = {};
  int _version = 0;

  /// Tăng mỗi lần cần tải lại (sau khi thêm/sửa).
  int get version => _version;

  void setSearch(String v) {
    search = v;
    page = 1;
    notifyListeners();
  }

  void setFilter(String key, Object? value) {
    if (value == null) {
      filters.remove(key);
    } else {
      filters[key] = value;
    }
    page = 1;
    notifyListeners();
  }

  void setPage(int p) {
    page = p;
    notifyListeners();
  }

  void reload() {
    _version++;
    notifyListeners();
  }
}

class ListColumn {
  const ListColumn(this.title, {this.width, this.flex = 1});

  final String title;

  /// Cột cố định; `null` = giãn theo [flex].
  final double? width;
  final int flex;
}

/// Bảng phân trang dùng chung của các màn PĐT: tải `GET path` theo [controller], hiện khung
/// đang tải / lỗi (kèm "Thử lại") / rỗng, và thanh phân trang (25 dòng/trang).
class ResourceList extends ConsumerStatefulWidget {
  const ResourceList({
    super.key,
    required this.controller,
    required this.path,
    required this.columns,
    required this.cells,
    this.onRowTap,
    this.emptyText = 'Chưa có dữ liệu.',
    this.minWidth = 900,
    this.footer,
  });

  final ResourceListController controller;
  final String path;
  final List<ListColumn> columns;

  /// Các ô của một dòng, đúng thứ tự [columns].
  final List<Widget> Function(Json row) cells;
  final void Function(Json row)? onRowTap;
  final String emptyText;
  final double minWidth;
  final Widget Function(PageResult<Json> page)? footer;

  @override
  ConsumerState<ResourceList> createState() => _ResourceListState();
}

class _ResourceListState extends ConsumerState<ResourceList> {
  static const _pageSize = 25;
  late Future<PageResult<Json>> _future;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_load);
    _future = _fetch();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_load);
    super.dispose();
  }

  Future<PageResult<Json>> _fetch() {
    final c = widget.controller;
    return ref
        .read(trainingApiProvider)
        .list(
          widget.path,
          page: c.page,
          pageSize: _pageSize,
          search: c.search,
          query: c.filters,
        );
  }

  void _load() {
    final next = _fetch();
    setState(() {
      _future = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PageResult<Json>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) return ListErrorCard(onRetry: _load);
        final page = snap.data;
        if (page == null) return const ListSkeleton();
        return _table(page);
      },
    );
  }

  Widget _cell(ListColumn c, Widget child) => c.width != null
      ? SizedBox(width: c.width, child: child)
      : Expanded(flex: c.flex, child: child);

  Widget _table(PageResult<Json> page) {
    final c = widget.controller;
    final pages = page.pages(_pageSize);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(box.maxWidth, widget.minWidth),
                child: Column(
                  children: [
                    _row(
                      color: const Color(0xFFFAFAFA),
                      cells: [
                        for (final col in widget.columns)
                          _cell(
                            col,
                            Text(
                              col.title.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                      ],
                    ),
                    for (final r in page.items)
                      InkWell(
                        onTap: widget.onRowTap == null
                            ? null
                            : () => widget.onRowTap!(r),
                        child: _row(
                          cells: [
                            for (final (i, w) in widget.cells(r).indexed)
                              _cell(widget.columns[i], w),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (page.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Center(
                child: Text(
                  widget.emptyText,
                  style: const TextStyle(fontSize: 14, color: AppColors.muted),
                ),
              ),
            ),
          if (widget.footer != null) widget.footer!(page),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Text(
                  '${page.count} bản ghi',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Trang trước',
                      onPressed: c.page > 1
                          ? () => c.setPage(c.page - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      'Trang ${c.page}/$pages · $_pageSize dòng/trang',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Trang sau',
                      onPressed: c.page < pages
                          ? () => c.setPage(c.page + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row({required List<Widget> cells, Color color = Colors.white}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          border: const Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            for (final (i, c) in cells.indexed) ...[
              if (i > 0) const SizedBox(width: 16),
              c,
            ],
          ],
        ),
      );
}

/// Thanh lọc (thẻ trắng): ô tìm kiếm, bộ lọc, nút "+ Thêm …".
class ListToolbar extends StatelessWidget {
  const ListToolbar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppColors.cardShadow,
    ),
    child: Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: children,
    ),
  );
}

/// Ô tìm kiếm có debounce 300ms.
class SearchBox extends StatefulWidget {
  const SearchBox({
    super.key,
    required this.controller,
    this.label = 'Tìm kiếm',
    this.hint,
    this.width = 280,
  });

  final ResourceListController controller;
  final String label;
  final String? hint;
  final double width;

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  final _text = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    child: LabeledField(
      label: widget.label,
      hint: widget.hint,
      controller: _text,
      onChanged: (v) {
        _debounce?.cancel();
        _debounce = Timer(
          const Duration(milliseconds: 300),
          () => widget.controller.setSearch(v),
        );
      },
    ),
  );
}

/// Ô chọn lọc theo một giá trị cố định (vd Trạng thái); giá trị rỗng = không lọc.
class FilterDropdown extends StatefulWidget {
  const FilterDropdown({
    super.key,
    required this.controller,
    required this.filterKey,
    required this.options,
    this.label = 'Trạng thái',
    this.width = 170,
  });

  final ResourceListController controller;
  final String filterKey;

  /// (giá trị gửi lên, nhãn); phần tử đầu là "Tất cả" với giá trị rỗng.
  final List<(String, String)> options;
  final String label;
  final double width;

  @override
  State<FilterDropdown> createState() => _FilterDropdownState();
}

class _FilterDropdownState extends State<FilterDropdown> {
  String _value = '';

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    child: LabeledDropdown<String>(
      label: widget.label,
      value: _value,
      options: widget.options,
      onChanged: (v) {
        setState(() => _value = v);
        widget.controller.setFilter(widget.filterKey, v.isEmpty ? null : v);
      },
    ),
  );
}

/// Các lựa chọn Trạng thái dùng chung cho Khoa/viện, Ngành, CTĐT.
const dungOptions = <(String, String)>[
  ('', 'Tất cả'),
  ('HOAT_DONG', 'Hoạt động'),
  ('NGUNG', 'Ngừng'),
];

/// Nút "+ Thêm …" của thanh lọc.
class AddButton extends StatelessWidget {
  const AddButton(this.label, this.onPressed, {super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: math.max(150, label.length * 9.5 + 40),
    child: AppButton(label: label, height: 44, onPressed: onPressed),
  );
}

/// Nút nhỏ viền trong ô thao tác của dòng.
class RowButton extends StatelessWidget {
  const RowButton(this.label, this.onPressed, {super.key, this.danger = false});

  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(
          color: danger ? const Color(0xFFE8B4B0) : const Color(0xFFC4C9D4),
        ),
        foregroundColor: danger ? AppColors.danger : AppColors.primary,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    ),
  );
}

/// Dãy nút thao tác canh phải, co lại vừa cột.
class RowActions extends StatelessWidget {
  const RowActions(this.buttons, {super.key});

  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerRight,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, b) in buttons.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          b,
        ],
      ],
    ),
  );
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget bar(double h, [double? w]) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF5),
        borderRadius: BorderRadius.circular(10),
      ),
    );
    return Semantics(
      label: 'Đang tải dữ liệu',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(20, 220),
            for (var i = 0; i < 5; i++) ...[
              const SizedBox(height: 14),
              bar(44),
            ],
          ],
        ),
      ),
    );
  }
}

class ListErrorCard extends StatelessWidget {
  const ListErrorCard({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppColors.cardShadow,
    ),
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFDECEA),
          ),
          child: const Text(
            '!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Không tải được dữ liệu',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Kết nối bị gián đoạn hoặc máy chủ đang bận. Hãy thử lại sau ít giây.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: 140,
          child: AppButton(label: 'Thử lại', height: 44, onPressed: onRetry),
        ),
      ],
    ),
  );
}
