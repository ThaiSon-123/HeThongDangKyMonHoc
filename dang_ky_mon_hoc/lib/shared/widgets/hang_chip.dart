import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/layout.dart';

/// Một lựa chọn trong [HangChip].
typedef MucChip = ({String nhan, bool chon, ValueChanged<bool> onChon});

/// Hàng chip chọn. Web: mỗi chip giãn đều hết bề ngang (chip của Material không tự giãn nên vẽ riêng);
/// Android/điện thoại: chip Material xếp dòng như cũ. [chonMot] = chọn một (ChoiceChip), ngược lại FilterChip.
class HangChip extends StatelessWidget {
  const HangChip({super.key, required this.muc, this.chonMot = false});

  final List<MucChip> muc;
  final bool chonMot;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || isCompact(context)) {
      return Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final m in muc)
            chonMot
                ? ChoiceChip(
                    label: Text(m.nhan),
                    selected: m.chon,
                    onSelected: m.onChon,
                  )
                : FilterChip(
                    label: Text(m.nhan),
                    selected: m.chon,
                    onSelected: m.onChon,
                  ),
        ],
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final (i, m) in muc.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              button: true,
              selected: m.chon,
              child: Material(
                color: m.chon ? scheme.secondaryContainer : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: m.chon
                      ? BorderSide.none
                      : BorderSide(color: scheme.outlineVariant),
                ),
                child: InkWell(
                  customBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onTap: () => m.onChon(!m.chon),
                  child: SizedBox(
                    height: 40,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (m.chon && !chonMot) ...[
                            const Icon(Icons.check, size: 18),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            m.nhan,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
