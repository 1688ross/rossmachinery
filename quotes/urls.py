from django.urls import path
from . import views

urlpatterns = [
    path("quotes/", views.quote_list, name="quote_list"),
    path("quotes/new/", views.quote_new, name="quote_new"),
    path("quotes/<int:pk>/", views.quote_preview, name="quote_preview"),
    path("quotes/<int:pk>/edit/", views.quote_edit, name="quote_edit"),
    path("quotes/<int:pk>/document/", views.quote_document, name="quote_document"),
    path("quotes/<int:pk>/pdf/", views.quote_pdf, name="quote_pdf"),
]
