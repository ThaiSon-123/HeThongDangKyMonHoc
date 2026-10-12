from rest_framework.throttling import BaseThrottle


def client_ip(request):
    """IP client theo `REST_FRAMEWORK["NUM_PROXIES"]`: 0 → chỉ tin REMOTE_ADDR (header
    X-Forwarded-For do client gửi bị bỏ qua); N → lấy địa chỉ do proxy thứ N từ cuối ghi."""
    return BaseThrottle().get_ident(request)
