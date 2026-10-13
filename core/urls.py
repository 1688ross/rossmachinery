from django.urls import path
from . import views

urlpatterns = [
    path("", views.panel, name="panel"),
    path("po/<uuid:po_id>/", views.po_detail, name="po_detail"),
    path("po/<uuid:po_id>/upload/", views.doc_upload, name="doc_upload"),
    path("po/<uuid:po_id>/step/<uuid:step_id>/", views.step_action, name="step_action"),
    path("po/<uuid:po_id>/okay/<slug:key>/", views.okay_reason, name="okay_reason"),
    path("doc/<uuid:doc_id>/", views.doc_detail, name="doc_detail"),
    path("doc/<uuid:doc_id>/file/", views.doc_file, name="doc_file"),
    path("doc/<uuid:doc_id>/page1.png", views.doc_preview, name="doc_preview"),
]
