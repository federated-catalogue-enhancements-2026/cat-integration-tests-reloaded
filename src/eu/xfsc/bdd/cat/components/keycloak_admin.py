"""
Keycloak Admin REST API wrapper for ephemeral RBAC test-user provisioning.

Used by the CAT-FR-AC-01 RBAC role-matrix scenarios (see
"features/18 RBAC Role Matrix.feature") to create a short-lived realm user,
assign it one or more federated-catalogue client roles, and set its
participantId attribute — the shipped dev realm
(keycloak/realms/dev/fc-realm.json) does not ship a fixed test user for
every row of the matrix, and the existing step library
(eu.xfsc.bdd.core.server.keycloak.KeycloakServer /
eu.xfsc.bdd.cat.components.keycloak.CatKeycloakServer) only supports
password-grant tokens for realm users that already exist.

The participantId attribute matters independently of role: PR #153
(eclipse-xfsc/federated-catalogue) had to add attributes.participantId to
fc-asset-creator-test because checkParticipantAccess otherwise rejects a
request "regardless of asset issuer" — confirmed generally by GitHub issue
eclipse-xfsc/federated-catalogue#155. A role-only user would reproduce a
participant-mismatch 403 indistinguishable from a missing-role 403.

Requires the realm's *master*-realm bootstrap admin (KEYCLOAK_ADMIN /
KEYCLOAK_ADMIN_PASSWORD in federated-catalogue/docker/dev.env) — Keycloak's
Admin REST API is reached via the master realm's built-in admin-cli client,
not the federated-catalogue realm/client used for everything else in this
suite.
"""
from typing import Any, Optional
from urllib.parse import quote

import requests

from eu.xfsc.bdd.core.defaults import CONNECT_TIMEOUT_IN_SECONDS

from ..env import (
    KEYCLOAK_ADMIN_PASSWORD,
    KEYCLOAK_ADMIN_USER,
    KEYCLOAK_REALM,
    KEYCLOAK_URL,
)

MASTER_REALM = "master"
ADMIN_CLI_CLIENT_ID = "admin-cli"
# The realm client whose roles (ASSET_CREATE/READ/UPDATE/DELETE, and the composite
# asset-reader/asset-creator/asset-editor/asset-manager roles) this suite provisions
# test users against. All are Keycloak *client* roles, not realm roles — confirmed
# against keycloak/realms/dev/fc-realm.json ("roles.client.federated-catalogue"; the
# realm-level role list holds only uma_authorization/offline_access).
TARGET_CLIENT_ID = "federated-catalogue"

PARTICIPANT_ID_ATTRIBUTE = "participantId"
PASSWORD_CREDENTIAL_TYPE = "password"
UNAUTHORIZED_STATUS_CODE = 401

ADMIN_TOKEN_URL = f"{KEYCLOAK_URL}/realms/{MASTER_REALM}/protocol/openid-connect/token"
CLIENTS_URL = f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/clients"
USERS_URL = f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/users"


class KeycloakAdmin:
    """Thin wrapper around the Keycloak Admin REST API subset needed to
    create, role-assign, and delete ephemeral RBAC test users.

    Every public method returns the raw `requests.Response` (same convention
    as `components/fc_server.py` and `components/keycloak.py`) — the calling
    step asserts on it, it is not asserted on here.

    The master-realm admin token is fetched once (on first use) and cached
    for the lifetime of the instance — one `KeycloakAdmin()` per scenario
    (see `steps/keycloak_admin.py`), reused across create_user/
    assign_client_roles/delete_user — rather than refetched on every call. A
    cached token that a request rejects with 401 (e.g. because it expired
    mid-scenario) is refreshed once and the request retried; a second 401 is
    returned to the caller to assert on, not silently retried forever.
    """

    def __init__(self) -> None:
        self._session = requests.Session()
        self._client_uuid: Optional[str] = None
        self._admin_token: Optional[str] = None

    def _fetch_admin_token(self) -> str:
        response = requests.post(
            url=ADMIN_TOKEN_URL,
            data={
                "grant_type": PASSWORD_CREDENTIAL_TYPE,
                "client_id": ADMIN_CLI_CLIENT_ID,
                "username": KEYCLOAK_ADMIN_USER,
                "password": KEYCLOAK_ADMIN_PASSWORD,
            },
            timeout=CONNECT_TIMEOUT_IN_SECONDS,
        )
        body = response.json() if response.content else {}
        assert response.status_code == 200 and "access_token" in body, (
            f"Keycloak admin token request (master realm, {ADMIN_CLI_CLIENT_ID}) failed: "
            f"{response.status_code} {response.text}"
        )
        return body["access_token"]

    def _admin_headers(self, force_refresh: bool = False) -> dict[str, str]:
        if force_refresh or self._admin_token is None:
            self._admin_token = self._fetch_admin_token()
        return {"Authorization": f"Bearer {self._admin_token}"}

    def _request(self, method: str, url: str, **kwargs: Any) -> requests.Response:
        """Issue one authenticated admin-API call, reusing the cached token.

        On a 401 (most likely: the cached token expired mid-scenario), fetch
        a fresh token once and retry once — a second 401 is returned as-is
        for the caller to assert on, not retried indefinitely.
        """
        response = self._session.request(
            method, url, headers=self._admin_headers(), timeout=CONNECT_TIMEOUT_IN_SECONDS, **kwargs,
        )
        if response.status_code == UNAUTHORIZED_STATUS_CODE:
            response = self._session.request(
                method, url, headers=self._admin_headers(force_refresh=True),
                timeout=CONNECT_TIMEOUT_IN_SECONDS, **kwargs,
            )
        return response

    def _resolve_client_uuid(self) -> str:
        """GET /admin/realms/{realm}/clients?clientId=federated-catalogue — cached per instance."""
        if self._client_uuid is not None:
            return self._client_uuid
        response = self._request("GET", CLIENTS_URL, params={"clientId": TARGET_CLIENT_ID})
        clients = response.json() if response.content else []
        assert response.status_code == 200 and clients, (
            f"Could not resolve client uuid for '{TARGET_CLIENT_ID}': "
            f"{response.status_code} {response.text}"
        )
        self._client_uuid = clients[0]["id"]
        return self._client_uuid

    def create_user(self, username: str, password: str, participant_id: str) -> requests.Response:
        """POST /admin/realms/{realm}/users

        Creates an enabled, email-verified realm user with no pending required
        actions, the given password (permanent, not temporary — so the
        subsequent password-grant token fetch does not get redirected into an
        update-password flow), and a participantId attribute.
        """
        payload = {
            "username": username,
            "enabled": True,
            "emailVerified": True,
            "requiredActions": [],
            "attributes": {PARTICIPANT_ID_ATTRIBUTE: [participant_id]},
            "credentials": [
                {"type": PASSWORD_CREDENTIAL_TYPE, "value": password, "temporary": False},
            ],
        }
        return self._request("POST", USERS_URL, json=payload)

    def assign_client_roles(self, user_id: str, role_names: list[str]) -> requests.Response:
        """Resolve each named federated-catalogue client role (single roles like
        ASSET_READ, or composite roles like asset-creator/asset-manager), then
        POST /admin/realms/{realm}/users/{id}/role-mappings/clients/{client-uuid}."""
        client_uuid = self._resolve_client_uuid()
        role_representations = []
        for role_name in role_names:
            response = self._request("GET", f"{CLIENTS_URL}/{client_uuid}/roles/{quote(role_name, safe='')}")
            assert response.status_code == 200, (
                f"Could not resolve federated-catalogue client role '{role_name}': "
                f"{response.status_code} {response.text}"
            )
            role_representations.append(response.json())
        return self._request(
            "POST", f"{USERS_URL}/{user_id}/role-mappings/clients/{client_uuid}", json=role_representations,
        )

    def delete_user(self, user_id: str) -> requests.Response:
        """DELETE /admin/realms/{realm}/users/{id}"""
        return self._request("DELETE", f"{USERS_URL}/{user_id}")
