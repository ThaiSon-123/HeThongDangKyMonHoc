from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("attendance", "0007_kiem_tra_gps"),
    ]

    operations = [
        migrations.AddField(
            model_name="challenge",
            name="co_bluetooth",
            field=models.BooleanField(default=False),
        ),
    ]
