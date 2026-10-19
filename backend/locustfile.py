"""Load test đăng ký đồng thời (plan.md mục 13): nhiều SV cùng bấm đăng ký một lớp ít chỗ.

Chạy (cần backend + `seed_demo`; tài khoản sv01..sv10 mật khẩu `Demo@12345`):

    pip install locust
    locust -f locustfile.py --host http://localhost:8010 -u 10 -r 10 -t 30s --headless \
        # đặt trước: LOCUST_CLASS_ID=<id lớp MO>

Pass khi: không có lỗi 5xx và `si_so_hien_tai` không vượt `si_so_toi_da` (tự kiểm khi kết thúc,
bằng tài khoản PĐT `pdt1`; vượt → thoát mã 1).
`201` (thành công), `409 LOP_DAY / DA_DANG_KY …`, `400` (nghiệp vụ) và `429` (rate limit) đều là phản hồi đúng.
"""

import os
import time
import uuid

from locust import HttpUser, events, task

MAT_KHAU = os.environ.get("LOCUST_PASSWORD", "Demo@12345")
SO_SV = int(os.environ.get("LOCUST_SO_SV", "10"))
LOP_ID = os.environ.get("LOCUST_CLASS_ID")
_so_nguoi_dung = 0


class SinhVien(HttpUser):
    """Mỗi user ảo là một SV: đăng nhập rồi liên tục đăng ký / hủy cùng một lớp."""

    def on_start(self):
        global _so_nguoi_dung
        _so_nguoi_dung += 1
        ten = f"sv{(_so_nguoi_dung - 1) % SO_SV + 1:02d}"
        res = self.client.post(
            "/api/auth/login/", json={"username": ten, "password": MAT_KHAU}, name="login"
        )
        res.raise_for_status()
        self.client.headers["Authorization"] = f"Bearer {res.json()['access']}"
        self.dk_id = None

    def _chap_nhan(self, res):
        if res.status_code in (200, 201, 204, 400, 409, 429):
            res.success()
        else:
            res.failure(f"{res.status_code} {res.text[:200]}")

    @task(3)
    def dang_ky(self):
        with self.client.post(
            "/api/registrations/",
            json={"lop_hoc_phan": int(LOP_ID)},
            headers={"Idempotency-Key": str(uuid.uuid4())},
            name="POST registrations",
            catch_response=True,
        ) as res:
            self._chap_nhan(res)
            if res.status_code == 201:
                self.dk_id = res.json()["id"]

    @task(1)
    def huy(self):
        if self.dk_id is None:
            return
        with self.client.delete(
            f"/api/registrations/{self.dk_id}/",
            name="DELETE registrations/{id}",
            catch_response=True,
        ) as res:
            self._chap_nhan(res)
            self.dk_id = None


@events.test_start.add_listener
def _kiem_tra_tham_so(environment, **kw):
    if not LOP_ID:
        raise SystemExit("Đặt LOCUST_CLASS_ID=<id lớp học phần đang MO> trước khi chạy.")


@events.test_stop.add_listener
def _kiem_tra_khong_overbook(environment, **kw):
    """Sĩ số cuối cùng không được vượt chỗ tối đa (BR-02/06)."""
    import requests

    host = environment.host
    for _ in range(8):  # 10 SV vừa đăng nhập cùng IP nên login PĐT có thể dính rate limit (10/phút)
        res = requests.post(
            f"{host}/api/auth/login/", json={"username": "pdt1", "password": MAT_KHAU}, timeout=10
        )
        if res.status_code != 429:
            break
        time.sleep(10)
    tk = res.json()["access"]
    lop = requests.get(
        f"{host}/api/class-sections/{LOP_ID}/",
        headers={"Authorization": f"Bearer {tk}"},
        timeout=10,
    ).json()
    print(f"Final seats: {lop['si_so_hien_tai']}/{lop['si_so_toi_da']}")
    if lop["si_so_hien_tai"] > lop["si_so_toi_da"]:
        environment.process_exit_code = 1
