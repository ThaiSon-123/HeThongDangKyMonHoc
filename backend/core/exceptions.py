"""Envelope lỗi nghiệp vụ + mã lỗi (plan.md mục 8.4).

Chỉ dùng mã trong danh sách dưới đây — không tự chế mã mới (plan.md mục 17, DoD #2).
Lỗi validation field giữ nguyên dạng DRF mặc định {"field": ["..."]}.
"""

from rest_framework import status
from rest_framework.exceptions import APIException


class BusinessError(APIException):
    """Lỗi nghiệp vụ — trả envelope {error: {code, message, details}}."""

    status_code = status.HTTP_400_BAD_REQUEST
    default_detail = "Lỗi nghiệp vụ."
    default_code = "LOI_NGHIEP_VU"

    def __init__(self, code=None, message=None, details=None, status_code=None):
        self.code = code or self.default_code
        self.message = message or self.default_detail
        self.details = details or {}
        if status_code is not None:
            self.status_code = status_code
        super().__init__(self.message)

    def to_envelope(self):
        body = {"code": self.code, "message": self.message}
        if self.details:
            body["details"] = self.details
        return {"error": body}


class Codes:
    """Mã lỗi nghiệp vụ (plan.md mục 8.4)."""

    NGOAI_CUA_SO_DANG_KY = "NGOAI_CUA_SO_DANG_KY"
    LOP_CHUA_MO = "LOP_CHUA_MO"
    LOP_DAY = "LOP_DAY"
    TRUNG_LICH = "TRUNG_LICH"
    DA_DANG_KY = "DA_DANG_KY"
    DA_DAT_MON = "DA_DAT_MON"
    THIEU_TIEN_QUYET = "THIEU_TIEN_QUYET"
    VUOT_TIN_TC_TOI_DA = "VUOT_TIN_TC_TOI_DA"
    VUOT_TIN_TC_CANH_BAO = "VUOT_TIN_TC_CANH_BAO"
    QUA_HAN_NHAP_DIEM = "QUA_HAN_NHAP_DIEM"
    TRANG_THAI_KHONG_HOP_LE = "TRANG_THAI_KHONG_HOP_LE"
    KHONG_CO_QUYEN = "KHONG_CO_QUYEN"
    TAI_KHOAN_BI_KHOA = "TAI_KHOAN_BI_KHOA"
    CHUA_CAU_HINH_GIA = "CHUA_CAU_HINH_GIA"
    SO_TIEN_KHONG_HOP_LE = "SO_TIEN_KHONG_HOP_LE"
    QUA_NHIEU_YEU_CAU = "QUA_NHIEU_YEU_CAU"


# HTTP mặc định cho từng mã
_CODE_STATUS = {
    Codes.NGOAI_CUA_SO_DANG_KY: 400,
    Codes.LOP_CHUA_MO: 400,
    Codes.LOP_DAY: 409,
    Codes.TRUNG_LICH: 409,
    Codes.DA_DANG_KY: 409,
    Codes.DA_DAT_MON: 400,
    Codes.THIEU_TIEN_QUYET: 400,
    Codes.VUOT_TIN_TC_TOI_DA: 400,
    Codes.VUOT_TIN_TC_CANH_BAO: 400,
    Codes.QUA_HAN_NHAP_DIEM: 409,
    Codes.TRANG_THAI_KHONG_HOP_LE: 409,
    Codes.KHONG_CO_QUYEN: 403,
    Codes.TAI_KHOAN_BI_KHOA: 403,
    Codes.CHUA_CAU_HINH_GIA: 400,
    Codes.SO_TIEN_KHONG_HOP_LE: 400,
    Codes.QUA_NHIEU_YEU_CAU: 429,
}


def business_error(code, message, details=None):
    """Tiện ích raise: tự suy HTTP status từ mã."""
    return BusinessError(
        code=code,
        message=message,
        details=details,
        status_code=_CODE_STATUS.get(code, 400),
    )


def api_exception_handler(exc, context):
    """Bọc lỗi nghiệp vụ vào envelope; giữ nguyên lỗi DRF khác."""
    # Import trong hàm: rest_framework.views → schemas → settings.AUTHENTICATION_CLASSES
    # → apps.auth.authentication → core.exceptions = vòng lặp nếu import ở top-level.
    from rest_framework.exceptions import Throttled
    from rest_framework.response import Response
    from rest_framework.views import exception_handler as drf_exception_handler

    if isinstance(exc, BusinessError):
        return Response(exc.to_envelope(), status=exc.status_code)
    if isinstance(exc, Throttled):
        error = BusinessError(
            Codes.QUA_NHIEU_YEU_CAU,
            "Bạn thao tác quá nhanh, vui lòng thử lại sau.",
            {"retry_after": exc.wait} if exc.wait else None,
            status_code=429,
        )
        response = Response(error.to_envelope(), status=429)
        if exc.wait:
            response["Retry-After"] = str(int(exc.wait))
        return response
    return drf_exception_handler(exc, context)
