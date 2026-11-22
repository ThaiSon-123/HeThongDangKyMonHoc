import django.core.validators
import django.db.models.deletion
from django.db import migrations, models
from django.db.models import Max
from django.db.models.functions import Upper


def tao_phong_tu_lich(apps, schema_editor):
    """Mỗi mã phòng đang có trong lịch → một Room (gộp hoa/thường như kiểm tra trùng phòng cũ)."""
    Room = apps.get_model("training", "Room")
    Schedule = apps.get_model("training", "Schedule")
    Schedule.objects.update(phong=Upper("phong"))
    for d in Schedule.objects.values("phong").annotate(sc=Max("lop_hoc_phan__si_so_toi_da")):
        Room.objects.create(
            ma=d["phong"],
            suc_chua=d["sc"] or 1,  # chưa biết sức chứa thật: lấy sĩ số tối đa lớn nhất đã xếp vào phòng
            loai="THUC_HANH" if d["phong"].startswith("LAB") else "LY_THUYET",
        )


class Migration(migrations.Migration):
    dependencies = [("training", "0002_lo_trinh_ctdt")]

    operations = [
        migrations.CreateModel(
            name="Room",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("ma", models.CharField(max_length=30, unique=True)),
                (
                    "suc_chua",
                    models.PositiveIntegerField(validators=[django.core.validators.MinValueValidator(1)]),
                ),
                (
                    "loai",
                    models.CharField(
                        choices=[("LY_THUYET", "Lý thuyết"), ("THUC_HANH", "Thực hành")],
                        default="LY_THUYET",
                        max_length=20,
                    ),
                ),
            ],
            options={"verbose_name": "Phòng học", "verbose_name_plural": "Phòng học", "ordering": ["ma"]},
        ),
        migrations.RunPython(tao_phong_tu_lich, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="schedule",
            name="phong",
            field=models.ForeignKey(
                db_column="phong",
                on_delete=django.db.models.deletion.PROTECT,
                related_name="lich_hoc",
                to="training.room",
                to_field="ma",
            ),
        ),
    ]
