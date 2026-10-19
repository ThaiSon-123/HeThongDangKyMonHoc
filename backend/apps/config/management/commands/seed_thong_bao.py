"""Nạp THÔNG BÁO mẫu (nội dung giả theo lịch năm học 2026-2027): thông báo theo vai trò, theo lớp học phần và gửi riêng
từng người, kèm trạng thái đã đọc. Ngày gửi đặt trong 180 ngày gần đây vì hộp thư chỉ hiện thông báo trong khoảng đó.

Chạy lại an toàn nhưng XOÁ MỌI THÔNG BÁO hiện có (kể cả do app tạo) rồi nạp lại. Chạy SAU seed_lich_su_hoc_tap.
"""

import random
from datetime import datetime, timedelta

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.db.models import Count
from django.utils import timezone

from apps.auth.models import Role
from apps.notifications.models import Audience, Notification, NotificationRead
from apps.notifications.services import hop_thu
from apps.profiles.models import StudentProfile
from apps.training.models import ClassSection

SEED = 2030
DA_DOC_TRUOC_NGAY = datetime(2026, 10, 1)  # thông báo cũ hơn mốc này phần lớn đã đọc; mới hơn thì chưa đọc
TAT_CA = [Role.SINH_VIEN, Role.GIAO_VIEN, Role.PHONG_DAO_TAO, Role.KE_TOAN]


def luc(nam, thang, ngay, gio=8):
    return timezone.make_aware(datetime(nam, thang, ngay, gio))


# (ngày gửi, người gửi: "PDT" | "KT" | "ADMIN", vai trò nhận, tiêu đề, nội dung)
THEO_VAI_TRO = [
    (luc(2026, 5, 4), "PDT", [Role.SINH_VIEN], "Đăng ký học phần học kỳ hè 2025-2026",
     "Học kỳ hè bắt đầu từ 15/06/2026. Sinh viên có nhu cầu học vượt hoặc học lại đăng ký từ 18/05 đến 29/05/2026."),
    (luc(2026, 6, 8), "PDT", [Role.SINH_VIEN], "Công bố điểm học kỳ 2 năm học 2025-2026",
     "Điểm học kỳ 2 đã được khóa. Sinh viên xem bảng điểm tại mục Điểm và liên hệ Phòng đào tạo nếu có thắc mắc."),
    (luc(2026, 6, 12), "PDT", [Role.GIAO_VIEN], "Nhắc hạn nhập điểm học kỳ 2",
     "Giảng viên hoàn tất nhập và khóa điểm các lớp học phần học kỳ 2 trước ngày 20/06/2026."),
    (luc(2026, 8, 20), "PDT", [Role.SINH_VIEN, Role.GIAO_VIEN], "Kế hoạch năm học 2026-2027",
     "Năm học 2026-2027 gồm học kỳ 1 (07/09/2026 - 17/01/2027), học kỳ 2 (01/02/2027 - 06/06/2027) và học kỳ hè."),
    (luc(2026, 9, 7), "PDT", [Role.SINH_VIEN, Role.GIAO_VIEN], "Khai giảng học kỳ 1 năm học 2026-2027",
     "Học kỳ 1 chính thức bắt đầu hôm nay. Sinh viên kiểm tra thời khóa biểu và phòng học tại mục Thời khóa biểu."),
    (luc(2026, 10, 10), "KT", [Role.SINH_VIEN, Role.KE_TOAN], "Công bố mức học phí năm học 2026-2027",
     "Học phí tính theo đơn giá từng ngành; tín chỉ khối kiến thức chung 700.000 đồng, tín chỉ thực hành 650.000 đồng."),
    (luc(2026, 10, 12), "PDT", [Role.KE_TOAN, Role.PHONG_DAO_TAO], "Chốt số liệu đăng ký trước khi tính học phí",
     "Phòng đào tạo chốt danh sách đăng ký sau khi cửa sổ đăng ký đóng (15/11/2026) để Kế toán tính học phí."),
    (luc(2026, 10, 14), "PDT", [Role.SINH_VIEN], "Mở đăng ký học phần học kỳ 1 năm học 2026-2027",
     "Đăng ký từ 15/10 đến 15/11/2026. Sinh viên diện cảnh báo học vụ được đăng ký tối đa 14 tín chỉ, các sinh viên khác tối đa 24."),
    (luc(2026, 10, 16), "KT", [Role.SINH_VIEN], "Nhắc hạn đóng học phí học kỳ 1",
     "Hạn đóng học phí học kỳ 1 năm học 2026-2027 là 10/12/2026. Thông tin chuyển khoản xem tại mục Học phí."),
    (luc(2026, 10, 18), "ADMIN", TAT_CA, "Bảo trì hệ thống đêm 25/10/2026",
     "Hệ thống tạm ngừng từ 23:00 ngày 25/10 đến 01:00 ngày 26/10/2026 để sao lưu và nâng cấp."),
]

# mẫu thông báo của giảng viên gửi cho lớp: (tiêu đề, nội dung)
THEO_LOP = [
    ("Nhắc nộp bài tập lớn", "Cả lớp nộp bài tập lớn trước 23:59 thứ Sáu tuần này; bài nộp trễ bị trừ điểm quá trình."),
    ("Thông báo kiểm tra giữa kỳ", "Kiểm tra giữa kỳ diễn ra trong buổi học tuần sau, thời lượng 45 phút, được dùng tài liệu."),
    ("Công bố điểm quá trình", "Điểm quá trình đã được nhập tạm. Sinh viên có ý kiến gửi lại giảng viên trong 3 ngày."),
]
NGAY_LOP = [luc(2026, 4, 28), luc(2026, 5, 5), luc(2026, 5, 12), luc(2026, 5, 19), luc(2026, 5, 26), luc(2026, 6, 2)]
SO_LOP_THONG_BAO = 6


class Command(BaseCommand):
    help = "Nạp thông báo mẫu (theo vai trò, theo lớp, gửi riêng) và trạng thái đã đọc."

    @transaction.atomic
    def handle(self, *args, **options):
        User = get_user_model()
        nguoi_gui = {
            "PDT": User.objects.filter(role=Role.PHONG_DAO_TAO).order_by("id").first(),
            "KT": User.objects.filter(role=Role.KE_TOAN).order_by("id").first(),
            "ADMIN": User.objects.filter(role=Role.ADMIN).order_by("id").first(),
        }
        if not all(nguoi_gui.values()):
            raise CommandError("Thiếu tài khoản admin / phòng đào tạo / kế toán — chạy seed_tai_khoan_van_phong trước.")
        Notification.objects.all().delete()

        moi = []  # (thông báo, ngày gửi)
        for ngay, ai, vai_tro, tieu_de, noi_dung in THEO_VAI_TRO:
            n = Notification.objects.create(
                tieu_de=tieu_de, noi_dung=noi_dung, audience=Audience.ROLE,
                target_refs=[str(r) for r in vai_tro], nguoi_gui=nguoi_gui[ai],
            )
            moi.append((n, ngay))

        # Lớp học phần học kỳ 2 năm học 2025-2026 có từ 5 sinh viên (mỗi môn một lớp, rải đều): giảng viên gửi cho cả lớp
        lops = ClassSection.objects.filter(ma_lop__endswith="2526.2").annotate(so_sv=Count("dang_ky")).filter(so_sv__gte=5)
        moi_mon = {}
        for lop in lops.select_related("giao_vien__user", "mon_hoc").order_by("id"):
            moi_mon.setdefault(lop.mon_hoc_id, lop)
        chon = list(moi_mon.values())
        for i, lop in enumerate(chon[:: max(1, len(chon) // SO_LOP_THONG_BAO)][:SO_LOP_THONG_BAO]):
            tieu_de, noi_dung = THEO_LOP[i % len(THEO_LOP)]
            n = Notification.objects.create(
                tieu_de=f"{tieu_de} - {lop.mon_hoc.ten_mon}", noi_dung=noi_dung, audience=Audience.CLASS,
                target_refs=[lop.id], nguoi_gui=lop.giao_vien.user,
            )
            moi.append((n, NGAY_LOP[i]))

        # gửi riêng: sinh viên diện cảnh báo học vụ (GPA < 2.0)
        for ho_so in StudentProfile.objects.filter(gpa__lt=2).select_related("user").order_by("ma_sv"):
            n = Notification.objects.create(
                tieu_de="Cảnh báo học vụ",
                noi_dung=f"GPA tích lũy của bạn là {ho_so.gpa} (dưới 2.0). Học kỳ này bạn đăng ký tối đa 14 tín chỉ.",
                audience=Audience.USER, target_refs=[ho_so.user_id], nguoi_gui=None,
            )
            moi.append((n, luc(2026, 10, 15)))

        for n, ngay in moi:  # auto_now_add ghi ngày chạy lệnh → đặt lại theo kịch bản
            Notification.objects.filter(pk=n.pk).update(ngay_gui=ngay)

        so_da_doc = self._da_doc(User, moi)
        n_vt = sum(n.audience == Audience.ROLE for n, _ in moi)
        n_lop = sum(n.audience == Audience.CLASS for n, _ in moi)
        n_rieng = sum(n.audience == Audience.USER for n, _ in moi)
        self.stdout.write(
            f"Đã nạp {len(moi)} thông báo ({n_vt} theo vai trò, {n_lop} theo lớp, {n_rieng} gửi riêng); "
            f"{so_da_doc} lượt đã đọc."
        )

    def _da_doc(self, User, moi):
        """Mỗi người dùng đã đọc ~85% thông báo cũ hơn DA_DOC_TRUOC_NGAY; thông báo mới thì chưa đọc."""
        rng = random.Random(SEED)
        moc = timezone.make_aware(DA_DOC_TRUOC_NGAY)
        ngay_cua = {n.id: ngay for n, ngay in moi}
        doc = []
        for user in User.objects.exclude(role=Role.ADMIN).order_by("id"):
            for n in hop_thu(user):
                if ngay_cua[n.id] < moc and rng.random() < 0.85:
                    doc.append(NotificationRead(notification=n, user=user))
        NotificationRead.objects.bulk_create(doc)
        for n, ngay in moi:
            NotificationRead.objects.filter(notification=n).update(ngay_doc=ngay + timedelta(days=1))
        return len(doc)
