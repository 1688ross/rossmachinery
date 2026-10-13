from django.contrib.auth import views as auth_views
from django.urls import path
from . import views

urlpatterns = [
    path("login/", auth_views.LoginView.as_view(template_name="accounts/login.html"), name="login"),
    path("logout/", auth_views.LogoutView.as_view(), name="logout"),
    path("2fa/setup/", views.two_factor_setup, name="two_factor_setup"),
    path("2fa/verify/", views.two_factor_verify, name="two_factor_verify"),
    path("2fa/backup-codes/", views.two_factor_new_codes, name="two_factor_new_codes"),
    path("2fa/codes/", views.two_factor_codes, name="two_factor_codes"),
    path("account/", views.account, name="account"),
]
