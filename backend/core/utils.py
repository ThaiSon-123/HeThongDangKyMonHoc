from rest_framework.exceptions import ValidationError
from rest_framework.throttling import BaseThrottle


def client_ip(request):
    """IP client theo `REST_FRAMEWORK["NUM_PROXIES"]`: 0 → chỉ tin REMOTE_ADDR (header
    X-Forwarded-For do client gửi bị bỏ qua); N → lấy địa chỉ do proxy thứ N từ cuối ghi."""
    return BaseThrottle().get_ident(request)


def int_param(request, ten):
    """`?ten=` dạng số nguyên (None nếu vắng); sai kiểu → `400` field `ten` thay vì lỗi 500 ở truy vấn."""
    v = request.query_params.get(ten)
    if v in (None, ""):
        return None
    if not str(v).isdigit():
        raise ValidationError({ten: ["Phải là số nguyên."]})
    return int(v)
