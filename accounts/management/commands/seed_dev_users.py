"""Create the development logins that match fixtures/seed_dev.sql. Dev and demo only.

Refuses to run unless RMS_SEED_DEMO=1 is set explicitly. Passwords are the published dev
password; authenticator keys and backup codes are generated at random on each machine and
printed once, never derived from anything in the repository."""
import os
from django.core.management.base import BaseCommand, CommandError
from django_otp.plugins.otp_static.models import StaticDevice, StaticToken
from django_otp.plugins.otp_totp.models import TOTPDevice
from accounts.models import User

DEV = [("chuck", "local|chuck", "Chuck", "Culliton"), ("ross", "local|ross", "Ross", "Culliton"), ("tammie", "local|tammie", "Tammie", "Smith"),
       ("ashley", "local|ashley", "Ashley", "Culliton"), ("zach", "local|zach", "Zach", "Morales")]   # names match fixtures/seed_dev*.sql


class Command(BaseCommand):
    def handle(self, *args, **opts):
        if os.environ.get("RMS_SEED_DEMO") != "1":
            raise CommandError("seed_dev_users creates sample logins with a known password. Set RMS_SEED_DEMO=1 to confirm this is a dev or demo box.")
        for username, subject, first, last in DEV:
            u, created = User.objects.get_or_create(username=username, defaults={"auth_subject": subject})
            u.auth_subject, u.first_name, u.last_name = subject, first, last   # the quote form signs with the full name
            u.set_password("devpass123")
            u.is_staff = u.is_superuser = username == "ross"    # ross is the demo administrator
            u.save()
            line = f"{'created' if created else 'updated'} {username} / devpass123"
            # Dev convenience: every sample user except ross gets a ready authenticator with a fresh
            # random key and eight backup codes, printed here once so tests and demos can use them.
            # ross has none, to show the first-sign-in setup flow.
            if username != "ross" and not TOTPDevice.objects.filter(user=u, confirmed=True).exists():
                dev = TOTPDevice.objects.create(user=u, name="dev authenticator", confirmed=True)
                sd, _ = StaticDevice.objects.get_or_create(user=u, name="backup", defaults={"confirmed": True})
                sd.token_set.all().delete()
                codes = [StaticToken.random_token() for _ in range(8)]
                for c in codes:
                    sd.token_set.create(token=c)
                line += f"  authenticator key {dev.key}  backup codes {' '.join(codes)}"
            self.stdout.write(line)
