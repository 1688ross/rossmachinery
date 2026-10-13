from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User


@admin.register(User)
class RmsUserAdmin(UserAdmin):
    fieldsets = UserAdmin.fieldsets + (("Platform", {"fields": ("auth_subject",)}),)
    list_display = ("username", "first_name", "last_name", "is_staff", "is_active", "last_login")
