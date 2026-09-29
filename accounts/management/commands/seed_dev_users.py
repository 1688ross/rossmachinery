"""Create the three development logins that match fixtures/seed_dev.sql. Dev only."""
from django.core.management.base import BaseCommand
from accounts.models import User

DEV = [("chuck", "local|chuck"), ("ross", "local|ross"), ("tammie", "local|tammie")]

class Command(BaseCommand):
    def handle(self, *args, **opts):
        for username, subject in DEV:
            u, created = User.objects.get_or_create(username=username, defaults={"auth_subject": subject})
            u.auth_subject = subject
            u.set_password("devpass123")
            u.is_staff = username == "ross"
            u.save()
            self.stdout.write(f"{'created' if created else 'updated'} {username} / devpass123")
