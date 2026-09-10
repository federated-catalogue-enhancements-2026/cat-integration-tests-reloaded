"""
Step definitions for ephemeral Keycloak test-user provisioning, used by the
CAT-FR-AC-01 RBAC role-matrix scenarios (see "features/18 RBAC Role Matrix.feature").

Creates a short-lived realm user via Keycloak's Admin REST API
(eu.xfsc.bdd.cat.components.keycloak_admin.KeycloakAdmin), assigns it the
requested federated-catalogue client role(s), then fetches a password-grant
token for it the same way steps/keycloak.py does for a fixed realm user. The
user is deleted again in environment.py's after_scenario hook — see
_track_provisioned_user below for the registration side of that cleanup.
"""
import uuid

from behave import given

from eu.xfsc.bdd.cat.components.keycloak import CatKeycloakServer
from eu.xfsc.bdd.cat.components.keycloak_admin import KeycloakAdmin
from eu.xfsc.bdd.core.server.keycloak import Token

PROVISIONED_USER_PREFIX = "cit-rbac-"
# Mirrors fc-asset-creator-test's own participantId (keycloak/realms/dev/fc-realm.json) — a
# realm user with no participantId 403s on checkParticipantAccess regardless of role, see
# GitHub issue eclipse-xfsc/federated-catalogue#155 and components/keycloak_admin.py.
PROVISIONED_USER_PARTICIPANT_ID = "did:web:compliance.lab.gaia-x.eu"

CREATED_STATUS_CODE = 201
NO_CONTENT_STATUS_CODE = 204


class ContextType:
    keycloak: CatKeycloakServer
    keycloak_admin: KeycloakAdmin
    FileToken: Token
    provisioned_keycloak_user_ids: list[str]


def _track_provisioned_user(context: ContextType, user_id: str) -> None:
    """Register a provisioned user for deletion in after_scenario — same
    accumulate-then-clean-up pattern as _uploaded_schema_ids/disabled_schema_modules
    in steps/catalogue_steps.py and steps/admin_api.py."""
    if not hasattr(context, "provisioned_keycloak_user_ids"):
        context.provisioned_keycloak_user_ids = []
    context.provisioned_keycloak_user_ids.append(user_id)


@given('Keycloak token for a provisioned user with roles "{role_names}"')
def token_for_provisioned_user_with_roles(context: ContextType, role_names: str) -> None:
    """Create an ephemeral realm user, assign it the given comma-separated
    federated-catalogue client role(s) — single roles (e.g. "ASSET_READ") or
    composite roles (e.g. "asset-creator", "asset-manager") both work, since
    Keycloak's role-mapping endpoint accepts either — and switch the shared
    Keycloak client to a password-grant token for that user."""
    roles = [name.strip() for name in role_names.split(",") if name.strip()]
    assert roles, f'No role names parsed from "{role_names}"'
    _provision_user_and_fetch_token(context, roles)


@given('Keycloak token for a provisioned user with no roles')
def token_for_provisioned_user_with_no_roles(context: ContextType) -> None:
    """Same ephemeral-user provisioning as token_for_provisioned_user_with_roles,
    but skips client-role assignment entirely — used by the RBAC role matrix's
    zero-roles row to isolate "no role" from "no participantId" as the cause of
    the expected 403s (unlike fc-restricted-test, this user has participantId set)."""
    _provision_user_and_fetch_token(context, [])


def _provision_user_and_fetch_token(context: ContextType, roles: list[str]) -> None:
    """Shared provisioning logic for the two steps above: create an ephemeral
    realm user, optionally assign it client roles, then switch the shared
    Keycloak client to a password-grant token for that user."""
    if not hasattr(context, "keycloak_admin"):
        context.keycloak_admin = KeycloakAdmin()
    username = f"{PROVISIONED_USER_PREFIX}{uuid.uuid4().hex[:12]}"
    # Per-user random password, not a fixed constant: after_scenario's cleanup swallows
    # delete failures, so a failed teardown against a shared realm must not leave a live
    # account with a known, reusable password.
    password = uuid.uuid4().hex

    create_response = context.keycloak_admin.create_user(
        username, password, PROVISIONED_USER_PARTICIPANT_ID,
    )
    assert create_response.status_code == CREATED_STATUS_CODE, (
        f"Keycloak admin user creation for '{username}' failed: "
        f"{create_response.status_code} {create_response.text}"
    )
    location = create_response.headers.get("Location", "")
    user_id = location.rstrip("/").rsplit("/", maxsplit=1)[-1]
    assert user_id, f"Keycloak admin user creation for '{username}' returned no Location header"
    _track_provisioned_user(context, user_id)

    if roles:
        assign_response = context.keycloak_admin.assign_client_roles(user_id, roles)
        assert assign_response.status_code == NO_CONTENT_STATUS_CODE, (
            f"Could not assign roles {roles} to provisioned user '{username}' ({user_id}): "
            f"{assign_response.status_code} {assign_response.text}"
        )

    context.keycloak.username = username
    context.keycloak.password = password
    context.keycloak.last_token = context.keycloak.fetch_token()
