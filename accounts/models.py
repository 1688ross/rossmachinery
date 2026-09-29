import uuid
from django.contrib.auth.models import AbstractUser
from django.db import models


def new_subject():
    return uuid.uuid4().hex


class User(AbstractUser):
    """Django login identity. Linked to app.users through auth_subject (a stable uuid string).
    Lives in schema 'django' (see db_table) so RLS never applies to it."""
    auth_subject = models.CharField(max_length=64, unique=True, default=new_subject)

    class Meta:
        db_table = 'django"."accounts_user'
