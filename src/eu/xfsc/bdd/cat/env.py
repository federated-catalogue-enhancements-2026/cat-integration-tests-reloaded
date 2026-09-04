"""
Keep all OS env used.
"""
import os

from .defaults import PREFIX

# pylint: disable=line-too-long
# :start: Federated Catalogue
FC_HOST = os.getenv(PREFIX + "_FC_HOST")
# :end: Federated Catalogue

# :start: Keycloak
KEYCLOAK_URL = os.getenv(PREFIX + "_KEYCLOAK_URL") or ""
KEYCLOAK_REALM = os.getenv(PREFIX + "_KEYCLOAK_REALM") or ""
KEYCLOAK_CLIENT_ID = os.getenv(PREFIX + "_KEYCLOAK_CLIENT_ID") or ""
KEYCLOAK_CLIENT_SECRET = os.getenv(PREFIX + "_KEYCLOAK_CLIENT_SECRET") or ""
KEYCLOAK_SCOPE = os.getenv(PREFIX + "_KEYCLOAK_SCOPE") or ""
# :end: Keycloak

# :start: Keycloak Admin API (ephemeral RBAC test-user provisioning, see
# components/keycloak_admin.py). Defaults match the dev-realm bootstrap admin
# (federated-catalogue/docker/dev.env: KEYCLOAK_ADMIN/KEYCLOAK_ADMIN_PASSWORD).
KEYCLOAK_ADMIN_USER = os.getenv(PREFIX + "_KEYCLOAK_ADMIN_USER") or "admin"
KEYCLOAK_ADMIN_PASSWORD = os.getenv(PREFIX + "_KEYCLOAK_ADMIN_PASSWORD") or "admin"
# :end: Keycloak Admin API

# :start: Test User
TEST_USER = os.getenv(PREFIX + "_TEST_USER") or ""
TEST_PASSWORD = os.getenv(PREFIX + "_TEST_PASSWORD") or ""
# :end: Test User

# pylint: enable=line-too-long
