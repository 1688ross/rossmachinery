from django.urls import path
from . import views

urlpatterns = [
    path("", views.panel, name="panel"),
    path("po/<uuid:po_id>/", views.po_detail, name="po_detail"),
    path("doc/<uuid:doc_id>/", views.doc_detail, name="doc_detail"),
]
