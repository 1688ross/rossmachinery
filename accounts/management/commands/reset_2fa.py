"""Remove a person's authenticator and backup codes so they set up again at their next sign-in.
For the office administrator when someone has lost both phone and codes:
    docker compose exec app python manage.py reset_2fa <username>"""
from django.core.management.base import BaseCommand, CommandError
from django_otp.plugins.otp_static.models import StaticDevice
from django_otp.plugins.otp_totp.models import TOTPDevice
from accounts.models import User


class Command(BaseCommand):
    def add_arguments(self, parser):
        parser.add_argument("username")

    def handle(self, *args, **opts):
        try:
            u = User.objects.get(username=opts["username"])
        except User.DoesNotExist:
            raise CommandError(f"no user named {opts['username']}")
        n = TOTPDevice.objects.filter(user=u).delete()[0] + StaticDevice.objects.filter(user=u).delete()[0]
        self.stdout.write(f"{u.username}: removed {n} device record(s). They will set up a new authenticator at their next sign-in.")
