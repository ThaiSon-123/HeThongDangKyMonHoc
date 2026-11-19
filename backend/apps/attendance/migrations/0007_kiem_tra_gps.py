from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("attendance", "0006_khuon_vien"),
    ]

    operations = [
        migrations.AddField(
            model_name="attendancesession",
            name="kiem_tra_gps",
            field=models.BooleanField(default=True),
        ),
    ]
