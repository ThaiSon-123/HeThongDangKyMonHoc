from django.core.exceptions import ValidationError


class LetterAndDigitValidator:
    """Chính sách mật khẩu (plan.md mục 8.1): phải có cả chữ lẫn số.
    Độ dài ≥ 8 do MinimumLengthValidator đảm nhiệm."""

    def validate(self, password, user=None):
        if not (any(c.isalpha() for c in password) and any(c.isdigit() for c in password)):
            raise ValidationError("Mật khẩu phải có cả chữ và số.", code="password_no_letter_digit")

    def get_help_text(self):
        return "Mật khẩu phải có ít nhất 8 ký tự, gồm cả chữ và số."
