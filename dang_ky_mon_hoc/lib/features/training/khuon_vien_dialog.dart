import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_dialog.dart';

// Chưa vẽ gì thì mở bản đồ ở Đại học Thủ Dầu Một.
const _macDinh = LatLng(10.9805, 106.6745);

/// Vẽ đa giác khuôn viên trường (docs/ke-hoach-gps-khuon-vien-va-esp32.md §3.2): chạm bản đồ để thêm góc,
/// chạm vào một góc để xóa. [giaTri] là JSON `[[vĩ độ, kinh độ], ...]` (rỗng = chưa vẽ);
/// trả JSON mới khi bấm Xong, `null` khi hủy.
Future<String?> showKhuonVienDialog(BuildContext context, String giaTri) =>
    showDialog<String>(
      context: context,
      builder: (_) => _KhuonVienDialog(giaTri),
    );

class _KhuonVienDialog extends StatefulWidget {
  const _KhuonVienDialog(this.giaTri);

  final String giaTri;

  @override
  State<_KhuonVienDialog> createState() => _KhuonVienDialogState();
}

class _KhuonVienDialogState extends State<_KhuonVienDialog> {
  late final List<LatLng> _goc = widget.giaTri.trim().isEmpty
      ? []
      : [
          for (final p in jsonDecode(widget.giaTri) as List)
            LatLng(
              ((p as List)[0] as num).toDouble(),
              (p[1] as num).toDouble(),
            ),
        ];

  String get _json => _goc.isEmpty
      ? ''
      : jsonEncode([
          for (final p in _goc) [p.latitude, p.longitude],
        ]);

  @override
  Widget build(BuildContext context) => AppDialog(
    title: 'Vẽ khuôn viên trường',
    maxWidth: 900,
    actions: [
      DialogButton(
        'Hoàn tác',
        onPressed: _goc.isEmpty ? null : () => setState(_goc.removeLast),
      ),
      DialogButton(
        'Xóa hết',
        onPressed: _goc.isEmpty ? null : () => setState(_goc.clear),
      ),
      DialogButton('Hủy', onPressed: () => Navigator.of(context).pop()),
      DialogButton(
        'Xong',
        filled: true,
        // 1–2 góc chưa thành vùng; 0 góc = xóa khuôn viên (server cho phép, GV sẽ không mở được phiên).
        onPressed: _goc.length == 1 || _goc.length == 2
            ? null
            : () => Navigator.of(context).pop(_json),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Chạm vào bản đồ để thêm góc theo thứ tự quanh khuôn viên; chạm vào một góc để xóa nó. '
          'Đang có ${_goc.length} góc${_goc.length < 3 ? ' (cần ít nhất 3)' : ''}.',
          style: TextStyle(color: AppColors.label, height: 1.5),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 480,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _macDinh,
                initialZoom: 17,
                initialCameraFit: _goc.length >= 2
                    ? CameraFit.coordinates(
                        coordinates: _goc,
                        padding: const EdgeInsets.all(40),
                      )
                    : null,
                onTap: (_, p) => setState(() => _goc.add(p)),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.dang_ky_mon_hoc',
                ),
                if (_goc.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _goc,
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderColor: AppColors.primary,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (final (i, p) in _goc.indexed)
                      Marker(
                        point: p,
                        width: 28,
                        height: 28,
                        child: GestureDetector(
                          onTap: () => setState(() => _goc.removeAt(i)),
                          child: CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SimpleAttributionWidget(
                  source: Text('OpenStreetMap contributors'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
