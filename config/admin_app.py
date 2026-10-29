from django.contrib.admin.apps import AdminConfig


class WorkbenchAdminConfig(AdminConfig):
    default_site = "config.admin_site.WorkbenchAdminSite"
