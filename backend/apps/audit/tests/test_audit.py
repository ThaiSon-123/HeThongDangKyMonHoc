"""Nhật ký thao tác (ADM-06) + kiểm tra mọi ViewSet ghi đều có audit (Pha 7)."""

from datetime import timedelta

import pytest
from django.utils import timezone
from rest_framework import viewsets

from apps.audit.models import AuditLog, HanhDong
from apps.auth.models import Role
from core.factories import UserFactory
from core.mixins import AuditLogMixin

pytestmark = pytest.mark.django_db
URL = "/api/admin/audit-logs/"


def log(doi_tuong, hanh_dong=HanhDong.UPDATE, user=None, **kw):
    return AuditLog.objects.create(
        user=user, hanh_dong=hanh_dong, doi_tuong=doi_tuong, doi_tuong_id="1", **kw
    )


@pytest.fixture
def du_lieu():
    nguoi = UserFactory(role=Role.PHONG_DAO_TAO, username="pdt_a")
    return {
        "dao_tao": log("Course", HanhDong.CREATE, nguoi),
        "dao_tao_2": log("Registration", user=nguoi),
        "tai_chinh": log(
            "Payment", HanhDong.CREATE, UserFactory(role=Role.KE_TOAN, username="kt_b")
        ),
        "he_thong": log("SystemConfig", user=UserFactory(role=Role.ADMIN, username="adm_c")),
    }


def doi_tuong(res):
    return [r["doi_tuong"] for r in res.data["results"]]


def test_pham_vi_theo_vai_tro(login_as, du_lieu):
    admin = login_as(UserFactory(role=Role.ADMIN)).get(URL)
    assert admin.data["count"] == 4  # Admin xem tất cả
    pdt = login_as(UserFactory(role=Role.PHONG_DAO_TAO)).get(URL)
    assert set(doi_tuong(pdt)) == {"Course", "Registration"}  # chỉ scope training
    kt = login_as(UserFactory(role=Role.KE_TOAN)).get(URL)
    assert doi_tuong(kt) == ["Payment"]  # chỉ scope finance
    for role in (Role.SINH_VIEN, Role.GIAO_VIEN):
        res = login_as(UserFactory(role=role)).get(URL)
        assert res.status_code == 403 and res.data["error"]["code"] == "KHONG_CO_QUYEN"


def test_pdt_khong_vuot_pham_vi_bang_cach_truyen_scope_hoac_doi_tuong(login_as, du_lieu):
    pdt = login_as(UserFactory(role=Role.PHONG_DAO_TAO))
    assert pdt.get(f"{URL}?scope=finance").data["count"] == 0
    assert pdt.get(f"{URL}?doi_tuong=Payment").data["count"] == 0
    assert pdt.get(f"{URL}?scope=other").data["count"] == 0
    assert pdt.get(f"{URL}?scope=training").data["count"] == 2


def test_loc_va_tim_kiem(login_as, du_lieu):
    admin = login_as(UserFactory(role=Role.ADMIN))
    assert admin.get(f"{URL}?scope=other").data["count"] == 1
    assert admin.get(f"{URL}?hanh_dong=CREATE").data["count"] == 2
    assert doi_tuong(admin.get(f"{URL}?nguoi_thuc_hien=kt_")) == ["Payment"]
    assert doi_tuong(admin.get(f"{URL}?doi_tuong=course")) == [
        "Course"
    ]  # không phân biệt hoa thường
    assert admin.get(f"{URL}?search=SystemConfig").data["count"] == 1
    res = admin.get(f"{URL}?search=pdt_a")
    assert res.data["count"] == 2 and res.data["results"][0]["nguoi_thuc_hien"] == "pdt_a"


def test_loc_theo_ngay_va_moi_nhat_truoc(login_as):
    cu = log("Course")
    AuditLog.objects.filter(pk=cu.pk).update(thoi_gian=timezone.now() - timedelta(days=10))
    moi = log("Major")
    admin = login_as(UserFactory(role=Role.ADMIN))
    assert [r["id"] for r in admin.get(URL).data["results"]] == [moi.id, cu.id]
    hom_nay = timezone.localdate().isoformat()
    assert [r["id"] for r in admin.get(f"{URL}?tu_ngay={hom_nay}").data["results"]] == [moi.id]
    gioi_han = (timezone.localdate() - timedelta(days=5)).isoformat()
    assert [r["id"] for r in admin.get(f"{URL}?den_ngay={gioi_han}").data["results"]] == [cu.id]


def test_chi_tiet_nguoi_thuc_hien_he_thong_va_scope(login_as):
    log("Grade", chi_tiet={"hanh_dong": "duyet_diem", "so_sinh_vien": 40})
    row = login_as(UserFactory(role=Role.ADMIN)).get(URL).data["results"][0]
    assert row["nguoi_thuc_hien"] == "Hệ thống" and row["scope"] == "training"
    assert row["chi_tiet"]["so_sinh_vien"] == 40


def test_khong_co_api_sua_xoa_nhat_ky(login_as):
    api = login_as(UserFactory(role=Role.ADMIN))
    for method in (api.post, api.put, api.patch, api.delete):
        assert method(URL).status_code == 405


# --------------------------------------------------------------- mọi ViewSet ghi đều có audit


def test_moi_viewset_ghi_deu_co_audit():
    """Mọi ViewSet đăng ký ở router mà cho phép POST/PUT/PATCH/DELETE phải dùng `AuditLogMixin` hoặc
    tự gọi `write_audit` (các view có luồng riêng: đăng ký, điểm danh, thanh toán, thông báo)."""
    import inspect

    from config.api_urls import router

    tu_ghi_audit = {  # đã có test kiểm tra audit trong test của chính app
        "RegistrationViewSet",
        "SessionViewSet",
        "AttendanceRequestViewSet",
        "PaymentViewSet",
        "NotificationViewSet",
    }
    thieu = []
    for _prefix, viewset, _basename in router.registry:
        ghi = [m for m in ("create", "update", "partial_update", "destroy") if hasattr(viewset, m)]
        la_ghi = bool(ghi) and not issubclass(viewset, viewsets.ReadOnlyModelViewSet)
        # ViewSet chỉ khai báo http_method_names không có phương thức ghi thì bỏ qua
        methods = getattr(viewset, "http_method_names", None)
        if methods is not None and not {"post", "put", "patch", "delete"} & set(methods):
            la_ghi = False
        if (
            la_ghi
            and not issubclass(viewset, AuditLogMixin)
            and viewset.__name__ not in tu_ghi_audit
        ):
            thieu.append(viewset.__name__)
    assert thieu == [], f"ViewSet ghi chưa có audit: {thieu}"
    assert inspect.isclass(AuditLogMixin)
