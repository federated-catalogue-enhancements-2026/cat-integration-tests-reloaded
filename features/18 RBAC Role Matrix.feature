@domain.security @extended @req.CAT-FR-AC-01
Feature: RBAC role matrix for asset endpoints
  As an operator of the Federated Catalogue
  I want each of the four fine-grained asset roles (ASSET_CREATE, ASSET_READ, ASSET_UPDATE,
  ASSET_DELETE) — alone, absent, partially combined, and fully combined — to grant exactly its
  matching set of operations
  So that role enforcement is verified end-to-end against the shipped Keycloak realm, not
  only at unit-test level

  # All seven scenarios assert all four operations (create/read/update/delete); none are @wip. All
  # seven provision ephemeral users at runtime via the Keycloak Admin REST API wrapper
  # (src/eu/xfsc/bdd/cat/components/keycloak_admin.py, steps/keycloak_admin.py), including the
  # zero-roles row, whose provisioned user has participantId set but is assigned no client roles.
  # Every provisioned user shares one participantId, so any two belong to the same participant.
  #
  # Delete/revoke enforce participant ownership: the caller's participant must match the asset's
  # issuer, unless the caller is admin. An asset created by fc-ca-test has a null issuer and can
  # never be deleted or revoked by a non-admin regardless of role, so scenarios needing a
  # pre-existing base asset seed it via a separate provisioned ASSET_CREATE user with the same
  # participantId, isolating the role question from the ownership question.
  #
  # PUT /assets/{id} has no non-RDF content path, so revoke (POST /assets/{hash}/revoke) serves as
  # the representative ASSET_UPDATE-gated write with the same role and ownership checks, but
  # content-agnostic — not a full content-replacement update.

  Background:
    Given CAT Keycloak is up
      And saved Keycloak token
      And Federated Catalogue Server is up

  @req.CAT-FR-AC-01
  Scenario: User with zero asset roles gets 403 on every asset operation
    # The provisioned user has participantId set (like the other six rows) but is assigned no
    # client roles — none of the four ASSET_* roles, or any other. That isolates the variable
    # this row exists to test: every asset operation is denied because of the missing role, not
    # because of a missing participant, proving the "zero roles" row of the matrix unambiguously.
    # Base asset is seeded by a second, same-participantId ASSET_CREATE user — not fc-ca-test —
    # so the delete cell's 403 is attributable to the missing role, not to the null-issuer
    # ownership gate on delete/revoke described above.
    Given asset from fixture "valid/non-rdf/template.txt" is not uploaded
    Given Keycloak token for a provisioned user with roles "ASSET_CREATE"
    When add asset from fixture "valid/non-rdf/template.txt" with content-type "text/plain"
    Then get http 201:Created code
      And save asset id from last response
    Given Keycloak token for a provisioned user with no roles
    When add asset from fixture "valid/non-rdf/template.txt" with content-type "text/plain"
    Then get http 403:Forbidden code
    When get saved asset
    Then get http 403:Forbidden code
    When update saved asset with fixture "valid/non-rdf/config.yaml"
    Then get http 403:Forbidden code
    When delete saved asset
    Then get http 403:Forbidden code
    # Cleanup: re-authenticate as admin to remove the asset the zero-role user could not touch.
    Given Keycloak token for user "fc-ca-test" with password "CHANGE_ME_dev_only1"
    When delete saved asset
    Then get http 200:Success code

  @req.CAT-FR-AC-01
  Scenario: User with only ASSET_CREATE can create an asset but cannot read, update or delete it
    # The leftover-asset cleanup ("is not uploaded") must run before switching to the
    # role-restricted provisioned user — an ASSET_CREATE-only user cannot clean up a leftover
    # asset from a prior failed run, since it lacks ASSET_DELETE.
    Given asset from fixture "valid/non-rdf/template.txt" is not uploaded
    Given Keycloak token for a provisioned user with roles "ASSET_CREATE"
    When add asset from fixture "valid/non-rdf/template.txt" with content-type "text/plain"
    Then get http 201:Created code
      And save asset id from last response
    When get saved asset
    Then get http 403:Forbidden code
    When revoke saved asset
    Then get http 403:Forbidden code
    When delete saved asset
    Then get http 403:Forbidden code
    Given Keycloak token for user "fc-ca-test" with password "CHANGE_ME_dev_only1"
    When delete saved asset
    Then get http 200:Success code

  @req.CAT-FR-AC-01
  Scenario: User with only ASSET_READ can read an asset but cannot create, update or delete
    # Base asset seeded by a second, same-participantId ASSET_CREATE user — see the
    # participant-scoping finding above; an fc-ca-test-issued asset (null issuer) cannot be
    # revoked/deleted by any non-admin caller regardless of role, which would make the
    # revoke/delete cells below ambiguous.
    Given asset from fixture "valid/non-rdf/template.txt" is not uploaded
    Given Keycloak token for a provisioned user with roles "ASSET_CREATE"
    When add asset from fixture "valid/non-rdf/template.txt" with content-type "text/plain"
    Then get http 201:Created code
      And save asset id from last response
    Given Keycloak token for a provisioned user with roles "ASSET_READ"
    When get saved asset
    Then get http 200:Success code
    When add asset from fixture "valid/non-rdf/template.txt" with content-type "text/plain"
    Then get http 403:Forbidden code
    When revoke saved asset
    Then get http 403:Forbidden code
    When delete saved asset
    Then get http 403:Forbidden code
    Given Keycloak token for user "fc-ca-test" with password "CHANGE_ME_dev_only1"
    When delete saved asset
    Then get http 200:Success code

  @req.CAT-FR-AC-01
  Scenario: User with only ASSET_UPDATE can revoke an asset but cannot create, read or delete it
    # Base asset is seeded by a SECOND provisioned user holding ASSET_CREATE (same participantId,
    # not the identity under test) rather than fc-ca-test — see the participant-scoping finding
    # above; an fc-ca-test-issued asset (null issuer) cannot be revoked/deleted by any non-admin
    # caller regardless of role. "Update" is tested via revoke, not PUT — see the PUT-limitation
    # finding above.
    Given asset from fixture "valid/non-rdf/template.txt" is not uploaded
    Given Keycloak token for a provisioned user with roles "ASSET_CREATE"
    When add asset from fixture "valid/non-rdf/template.txt" with content-type "text/plain"
    Then get http 201:Created code
      And save asset id from last response
    Given Keycloak token for a provisioned user with roles "ASSET_UPDATE"
    When revoke saved asset
    Then get http 200:Success code
    When add asset from fixture "valid/non-rdf/template.txt" with content-type "text/plain"
    Then get http 403:Forbidden code
    When get saved asset
    Then get http 403:Forbidden code
    When delete saved asset
    Then get http 403:Forbidden code
    Given Keycloak token for user "fc-ca-test" with password "CHANGE_ME_dev_only1"
    When delete saved asset
    Then get http 200:Success code

  @req.CAT-FR-AC-01
  Scenario: User with only ASSET_DELETE can delete an asset but cannot create, read or update it
    # Base asset seeded by a second, same-participantId ASSET_CREATE user — see the
    # participant-scoping finding above; deleting an fc-ca-test-issued (null-issuer) asset is
    # denied to any non-admin caller regardless of role, which is not a role-matrix defect.
    Given asset from fixture "valid/non-rdf/template.txt" is not uploaded
    Given Keycloak token for a provisioned user with roles "ASSET_CREATE"
    When add asset from fixture "valid/non-rdf/template.txt" with content-type "text/plain"
    Then get http 201:Created code
      And save asset id from last response
    Given Keycloak token for a provisioned user with roles "ASSET_DELETE"
    When add asset from fixture "valid/non-rdf/template.txt" with content-type "text/plain"
    Then get http 403:Forbidden code
    When get saved asset
    Then get http 403:Forbidden code
    When revoke saved asset
    Then get http 403:Forbidden code
    When delete saved asset
    Then get http 200:Success code

  @req.CAT-FR-AC-01
  Scenario: User with ASSET_CREATE and ASSET_READ can create and read but not update or delete
    Given asset from fixture "valid/non-rdf/template.txt" is not uploaded
    Given Keycloak token for a provisioned user with roles "asset-creator"
    When add asset from fixture "valid/non-rdf/template.txt" with content-type "text/plain"
    Then get http 201:Created code
      And save asset id from last response
    When get saved asset
    Then get http 200:Success code
    When revoke saved asset
    Then get http 403:Forbidden code
    When delete saved asset
    Then get http 403:Forbidden code
    Given Keycloak token for user "fc-ca-test" with password "CHANGE_ME_dev_only1"
    When delete saved asset
    Then get http 200:Success code

  @req.CAT-FR-AC-01
  Scenario: User with all four asset roles can create, read, update and delete
    Given asset from fixture "valid/non-rdf/template.txt" is not uploaded
    Given Keycloak token for a provisioned user with roles "asset-manager"
    When add asset from fixture "valid/non-rdf/template.txt" with content-type "text/plain"
    Then get http 201:Created code
      And save asset id from last response
    When get saved asset
    Then get http 200:Success code
    When revoke saved asset
    Then get http 200:Success code
    When delete saved asset
    Then get http 200:Success code
