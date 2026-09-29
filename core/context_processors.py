from django.conf import settings

def branding(request):
    return {"PO_PROFILE": settings.PO_PROFILE, "COMPANY_NAME": "Ross Machinery Sales"}
