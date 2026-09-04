@domain.validation @req.CAT-FR-CO-05
Feature: On-Demand Asset Validation
  As a user of the Federated Catalogue
  I want to validate stored assets against stored schemas
  So that I can check conformance at any time

  Background:
    Given CAT Keycloak is up
      And saved Keycloak token
      And Federated Catalogue Server is up

  @smoke
  Scenario: Validate Loire JWT participant against SHACL shape — conforming
    Given schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded as "text/turtle"
    Then save schema id from last response
    Given credential from fixture "loire/valid/participant.loire.signed.jwt" is not uploaded
    When add credential from fixture "loire/valid/participant.loire.signed.jwt"
    Then save asset id from last response
    When validate saved asset against schema by saved id
    Then get http 200:Success code
      And response conforms to schema
      And response has a validation result id
      And uploaded schemas are cleaned up

  Scenario: Validate Loire JWT participant against all SHACL shapes — result returned
    Given schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded as "text/turtle"
      And credential from fixture "loire/valid/participant.loire.signed.jwt" is not uploaded
    When add credential from fixture "loire/valid/participant.loire.signed.jwt"
    Then save asset id from last response
    When validate saved asset against all schemas
    Then get http 200:Success code
      And response has a validation result id
      And uploaded schemas are cleaned up

  @cfg.default
  Scenario: Validate credential JSON-LD against SHACL shape — conforming
    # JSON-LD without LD-proof — only accepted when VC signature verification is off (default config).
    Given schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded as "text/turtle"
    Then save schema id from last response
    Given credential from fixture "loire/valid/participant.loire.jsonld" is not uploaded
    When add credential from fixture "loire/valid/participant.loire.jsonld"
    Then save asset id from last response
    When validate saved asset against schema by saved id
    Then get http 200:Success code
      And response conforms to schema
      And response has a validation result id
      And uploaded schemas are cleaned up

  @cfg.default
  Scenario: Validate JSON-LD RDF asset against SHACL shape and JSON Schema together — both conform
    # SRS 3.1.6 applicability: a JSON Schema is applicable to an RDF asset serialised in JSON-LD.
    # This is SRS 5 validation request 1 — combined SHACL + JSON Schema validation of one asset.
    # JSON-LD without LD-proof — only accepted when VC signature verification is off (default config).
    Given schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded as "text/turtle"
    Then save schema id from last response as "shape_schema_id"
    Given schema from fixture "schemas/participant-jsonld.schema.json" is uploaded as "application/schema+json"
    Then save schema id from last response as "json_schema_id"
    Given credential from fixture "loire/valid/participant.loire.jsonld" is not uploaded
    When add credential from fixture "loire/valid/participant.loire.jsonld"
    Then save asset id from last response
    When validate saved asset against saved schemas
    Then get http 200:Success code
      And response conforms to schema
      And response has 2 validation result ids
      And uploaded schemas are cleaned up

  @cfg.default
  Scenario: Validate JSON-LD RDF asset against SHACL shape and JSON Schema together — SHACL half non-conforming
    # Negative twin of the scenario above: same two schemas, but this asset is explicitly typed
    # gax-core:Participant (matching the SHACL shape's target class under the Tagus namespace)
    # and lacks schema:legalName, so the SHACL leg genuinely fails instead of vacuously
    # conforming against zero matched focus nodes.
    Given schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded as "text/turtle"
    Then save schema id from last response as "shape_schema_id"
    Given schema from fixture "schemas/participant-jsonld.schema.json" is uploaded as "application/schema+json"
    Then save schema id from last response as "json_schema_id"
    Given asset from fixture "invalid/rdf/participant-missing-legalname.jsonld" is not uploaded
    When add asset from fixture "invalid/rdf/participant-missing-legalname.jsonld" with content-type "application/ld+json"
    Then save asset id from last response
    When validate saved asset against saved schemas
    Then get http 200:Success code
      And response does not conform to schema
      And response has at least 1 violation
      And response report contains raw SHACL report
      And response has 2 validation result ids
      And uploaded schemas are cleaned up

  Scenario: Validate RDF asset against SHACL — non-conforming, violations returned
    # Turtle fixture explicitly typed as gax-core:Participant but missing schema:legalName
    Given schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded as "text/turtle"
    Then save schema id from last response
    Given asset from fixture "invalid/rdf/participant-missing-legalname.ttl" is not uploaded
    When add asset from fixture "invalid/rdf/participant-missing-legalname.ttl" with content-type "text/turtle"
    Then save asset id from last response
    When validate saved asset against schema by saved id
    Then get http 200:Success code
      And response does not conform to schema
      And response has at least 1 violation
      And response report contains raw SHACL report
      And response has a validation result id
      And uploaded schemas are cleaned up

  Scenario: Validate JSON asset against JSON Schema — conforming
    Given schema from fixture "schemas/person.schema.json" is uploaded as "application/schema+json"
    Then save schema id from last response
    Given asset from fixture "valid/non-rdf/person-valid.json" is not uploaded
    When add asset from fixture "valid/non-rdf/person-valid.json" with content-type "application/json"
    Then save asset id from last response
    When validate saved asset against schema by saved id
    Then get http 200:Success code
      And response conforms to schema
      And response has a validation result id
      And uploaded schemas are cleaned up

  Scenario: Validate JSON asset against JSON Schema — non-conforming, violations returned
    Given schema from fixture "schemas/person.schema.json" is uploaded as "application/schema+json"
    Then save schema id from last response
    Given asset from fixture "invalid/non-rdf/person-invalid.json" is not uploaded
    When add asset from fixture "invalid/non-rdf/person-invalid.json" with content-type "application/json"
    Then save asset id from last response
    When validate saved asset against schema by saved id
    Then get http 200:Success code
      And response does not conform to schema
      And response has at least 1 violation
      And response has a validation result id
      And uploaded schemas are cleaned up

  Scenario: Validate XML asset against XML Schema — conforming
    Given schema from fixture "schemas/config.xsd" is uploaded as "application/xml"
    Then save schema id from last response
    Given asset from fixture "valid/non-rdf/config-valid.xml" is not uploaded
    When add asset from fixture "valid/non-rdf/config-valid.xml" with content-type "application/xml"
    Then save asset id from last response
    When validate saved asset against schema by saved id
    Then get http 200:Success code
      And response conforms to schema
      And response has a validation result id
      And uploaded schemas are cleaned up

  Scenario: Validate XML asset against XML Schema — non-conforming, violations returned
    Given schema from fixture "schemas/config.xsd" is uploaded as "application/xml"
    Then save schema id from last response
    Given asset from fixture "invalid/non-rdf/config-invalid.xml" is not uploaded
    When add asset from fixture "invalid/non-rdf/config-invalid.xml" with content-type "application/xml"
    Then save asset id from last response
    When validate saved asset against schema by saved id
    Then get http 200:Success code
      And response does not conform to schema
      And response has at least 1 violation
      And response has a validation result id
      And uploaded schemas are cleaned up

  Scenario: Validate RDF/XML asset against SHACL shape — conforming
    # Verifies RDF/XML serialisation is routed to SHACL, not XML Schema
    Given schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded as "text/turtle"
    Then save schema id from last response
    Given asset from fixture "valid/rdf/simple.rdf" is not uploaded
    When add asset from fixture "valid/rdf/simple.rdf" with content-type "application/rdf+xml"
    Then save asset id from last response
    When validate saved asset against schema by saved id
    Then get http 200:Success code
      And response conforms to schema
      And response has a validation result id
      And uploaded schemas are cleaned up

  Scenario: Validate RDF/XML asset against SHACL — non-conforming, violations returned
    # Participant missing schema:legalName — same constraint as Turtle fixture but RDF/XML serialisation
    Given schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded as "text/turtle"
    Then save schema id from last response
    Given asset from fixture "invalid/rdf/participant-missing-legalname.rdf" is not uploaded
    When add asset from fixture "invalid/rdf/participant-missing-legalname.rdf" with content-type "application/rdf+xml"
    Then save asset id from last response
    When validate saved asset against schema by saved id
    Then get http 200:Success code
      And response does not conform to schema
      And response has at least 1 violation
      And response has a validation result id
      And uploaded schemas are cleaned up

  Scenario: Validate RDF/XML asset against XML Schema via explicit schemaId — conforming
    # Symmetry case for SRS 3.1.6: an explicit schemaId makes an XML Schema applicable to an
    # RDF asset serialised in RDF/XML (validateAgainstAllSchemas above never takes this path —
    # only an explicit schemaId does). This XSD requires at least two top-level entries; it is
    # a plain XML structural constraint on the raw RDF/XML bytes, unrelated to SHACL.
    Given schema from fixture "schemas/participant-list.xsd" is uploaded as "application/xml"
    Then save schema id from last response
    Given asset from fixture "valid/rdf/participant-list.rdf" is not uploaded
    When add asset from fixture "valid/rdf/participant-list.rdf" with content-type "application/rdf+xml"
    Then save asset id from last response
    When validate saved asset against schema by saved id
    Then get http 200:Success code
      And response conforms to schema
      And response has a validation result id
      And uploaded schemas are cleaned up

  Scenario: Validate RDF/XML asset against XML Schema via explicit schemaId — non-conforming
    # Same schemaId path, same XSD; this asset has only one top-level entry where the schema
    # requires two — an XML Schema structural violation, not a SHACL constraint violation.
    Given schema from fixture "schemas/participant-list.xsd" is uploaded as "application/xml"
    Then save schema id from last response
    Given asset from fixture "invalid/rdf/participant-list-incomplete.rdf" is not uploaded
    When add asset from fixture "invalid/rdf/participant-list-incomplete.rdf" with content-type "application/rdf+xml"
    Then save asset id from last response
    When validate saved asset against schema by saved id
    Then get http 200:Success code
      And response does not conform to schema
      And response has at least 1 violation
      And response has a validation result id
      And uploaded schemas are cleaned up

  Scenario: Validation result is retrievable by ID after validation
    Given schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded as "text/turtle"
      And credential from fixture "loire/valid/participant.loire.signed.jwt" is not uploaded
    When add credential from fixture "loire/valid/participant.loire.signed.jwt"
    Then save asset id from last response
    When validate saved asset against all schemas
    Then get http 200:Success code
      And response has a validation result id
    When get validation result by saved id
    Then get http 200:Success code
      And uploaded schemas are cleaned up

  Scenario: Validation results for asset are listed after validation
    Given schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded as "text/turtle"
      And credential from fixture "loire/valid/participant.loire.signed.jwt" is not uploaded
    When add credential from fixture "loire/valid/participant.loire.signed.jwt"
    Then save asset id from last response
    When validate saved asset against all schemas
    Then get http 200:Success code
    When get validation results for saved asset
    Then get http 200:Success code
      And response validation results list is not empty
      And uploaded schemas are cleaned up

  Scenario: Validate asset with unknown schema ID returns 404
    Given credential from fixture "loire/valid/participant.loire.signed.jwt" is not uploaded
    When add credential from fixture "loire/valid/participant.loire.signed.jwt"
    Then save asset id from last response
    When validate saved asset against schema "urn:nonexistent-schema-validate-test"
    Then get http 404:Not Found code

  Scenario: Validate JSON asset with SHACL schema returns 400 — type mismatch
    Given schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded as "text/turtle"
    Then save schema id from last response
    Given asset from fixture "valid/non-rdf/contract.json" is not uploaded
    When add asset from fixture "valid/non-rdf/contract.json" with content-type "application/json"
    Then save asset id from last response
    When validate saved asset against schema by saved id
    Then get http 400:Bad Request code
      And uploaded schemas are cleaned up

  Scenario: Validate asset with unrecognised content-type returns 422
    # application/pdf has no applicable validation strategy — no engine handles this content-type
    Given schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded as "text/turtle"
    Then save schema id from last response
    Given asset from fixture "valid/non-rdf/sample.pdf" is not uploaded
    When add asset from fixture "valid/non-rdf/sample.pdf" with content-type "application/pdf"
    Then save asset id from last response
    When validate saved asset against schema by saved id
    Then get http 422:Unprocessable Entity code
      And uploaded schemas are cleaned up

  Scenario: Validate RDF asset with no schema specified returns 404
    Given credential from fixture "loire/valid/participant.loire.signed.jwt" is not uploaded
    When add credential from fixture "loire/valid/participant.loire.signed.jwt"
    Then save asset id from last response
    When validate saved asset with no schema
    Then get http 404:Not Found code

  Scenario: Validate JSON asset with validateAgainstAllSchemas and no JSON schema in store returns 404
    # Only a SHACL schema is present — not applicable to JSON assets; no matching schema found
    Given schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded as "text/turtle"
    Given asset from fixture "valid/non-rdf/person-valid.json" is not uploaded
    When add asset from fixture "valid/non-rdf/person-valid.json" with content-type "application/json"
    Then save asset id from last response
    When validate saved asset against all schemas
    Then get http 404:Not Found code
      And uploaded schemas are cleaned up

  Scenario: Validate asset without auth token returns 403
    Given credential from fixture "loire/valid/participant.loire.signed.jwt" is not uploaded
    When add credential from fixture "loire/valid/participant.loire.signed.jwt"
    Then save asset id from last response
    Given no auth token
    When validate saved asset against all schemas
    Then get http 403:Forbidden code

  @cfg.default
  Scenario: Validate two RDF assets together against SHACL shape — result returned
    # Mixes signed JWT and unsigned JSON-LD — JSON-LD upload only succeeds when VC signature verification is off.
    Given schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded as "text/turtle"
      And credential from fixture "loire/valid/participant.loire.signed.jwt" is not uploaded
    When add credential from fixture "loire/valid/participant.loire.signed.jwt"
    Then save asset id from last response as "asset_id_1"
    Given credential from fixture "loire/valid/participant.loire.jsonld" is not uploaded
    When add credential from fixture "loire/valid/participant.loire.jsonld"
    Then save asset id from last response as "asset_id_2"
    When validate saved assets against all schemas
    Then get http 200:Success code
      And response has a validation result id
      And uploaded schemas are cleaned up

  @cfg.default
  Scenario: Multi-asset SHACL: two assets combined into single data graph
    # digital-service-offering JWT is missing required gx:* properties; trust-framework SHACL on upload
    # rejects it under strict config — only runs in default config (VERIFY_SCHEMA off).
    Given schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded as "text/turtle"
      And credential from fixture "loire/valid/participant.loire.signed.jwt" is not uploaded
    When add credential from fixture "loire/valid/participant.loire.signed.jwt"
    Then save asset id from last response as "asset_id_1"
    Given credential from fixture "loire/valid/digital-service-offering.loire.signed.jwt" is not uploaded
    When add credential from fixture "loire/valid/digital-service-offering.loire.signed.jwt"
    Then save asset id from last response as "asset_id_2"
    When validate saved assets against all schemas
    Then get http 200:Success code
      And response has a validation result id
      And uploaded schemas are cleaned up

  Scenario: Multi-asset validate with empty assetIds returns 400
    When validate empty asset list against all schemas
    Then get http 400:Bad Request code

  Scenario: Multi-asset validate with 21 assetIds returns 400
    # Exceeds the OpenAPI max=20 limit (decision D7)
    When validate 21 dummy assets against all schemas
    Then get http 400:Bad Request code

  Scenario: Multi-asset validate with non-RDF asset returns 422
    Given schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded as "text/turtle"
      And credential from fixture "loire/valid/participant.loire.signed.jwt" is not uploaded
    When add credential from fixture "loire/valid/participant.loire.signed.jwt"
    Then save asset id from last response as "asset_id_1"
    Given asset from fixture "valid/non-rdf/contract.json" is not uploaded
    When add asset from fixture "valid/non-rdf/contract.json" with content-type "application/json"
    Then save asset id from last response as "asset_id_2"
    When validate saved assets against all schemas
    Then get http 422:Unprocessable Entity code
      And uploaded schemas are cleaned up

  Scenario: Multi-asset validate without auth returns 403
    Given no auth token
    When validate 1 dummy asset against all schemas
    Then get http 403:Forbidden code

  Scenario: Validate JSON asset when JSON Schema module is disabled returns 400 module_disabled
    # requireModuleEnabled() throws ClientException → 400 with body "module_disabled:JSON_SCHEMA"
    Given schema from fixture "schemas/person.schema.json" is uploaded as "application/schema+json"
    Then save schema id from last response
    Given asset from fixture "valid/non-rdf/person-valid.json" is not uploaded
    When add asset from fixture "valid/non-rdf/person-valid.json" with content-type "application/json"
    Then save asset id from last response
    Given JSON Schema module is disabled
    When validate saved asset against schema by saved id
    Then get http 400:Bad Request code
      And response body contains "module_disabled:JSON_SCHEMA"
      And JSON Schema module is re-enabled
      And uploaded schemas are cleaned up

  Scenario: Validate XML asset when XML Schema module is disabled returns 400 module_disabled
    # requireModuleEnabled() throws ClientException → 400 with body "module_disabled:XML_SCHEMA"
    Given schema from fixture "schemas/config.xsd" is uploaded as "application/xml"
    Then save schema id from last response
    Given asset from fixture "valid/non-rdf/config-valid.xml" is not uploaded
    When add asset from fixture "valid/non-rdf/config-valid.xml" with content-type "application/xml"
    Then save asset id from last response
    Given XML Schema module is disabled
    When validate saved asset against schema by saved id
    Then get http 400:Bad Request code
      And response body contains "module_disabled:XML_SCHEMA"
      And XML Schema module is re-enabled
      And uploaded schemas are cleaned up

  Scenario: JSON Schema module toggle takes effect — off rejects, on accepts
    # Demonstrates the toggle's symmetric effect: the same validation request is
    # rejected with module_disabled when the module is off, and succeeds when it is on.
    Given schema from fixture "schemas/person.schema.json" is uploaded as "application/schema+json"
    Then save schema id from last response
    Given asset from fixture "valid/non-rdf/person-valid.json" is not uploaded
    When add asset from fixture "valid/non-rdf/person-valid.json" with content-type "application/json"
    Then save asset id from last response
    Given JSON Schema module is disabled
    When validate saved asset against schema by saved id
    Then get http 400:Bad Request code
      And response body contains "module_disabled:JSON_SCHEMA"
    Given JSON Schema module is enabled
    When validate saved asset against schema by saved id
    Then get http 200:Success code
      And response conforms to schema
      And uploaded schemas are cleaned up

  Scenario: XML Schema module toggle takes effect — off rejects, on accepts
    Given schema from fixture "schemas/config.xsd" is uploaded as "application/xml"
    Then save schema id from last response
    Given asset from fixture "valid/non-rdf/config-valid.xml" is not uploaded
    When add asset from fixture "valid/non-rdf/config-valid.xml" with content-type "application/xml"
    Then save asset id from last response
    Given XML Schema module is disabled
    When validate saved asset against schema by saved id
    Then get http 400:Bad Request code
      And response body contains "module_disabled:XML_SCHEMA"
    Given XML Schema module is enabled
    When validate saved asset against schema by saved id
    Then get http 200:Success code
      And response conforms to schema
      And uploaded schemas are cleaned up

  Scenario: Deleting an asset cascades delete of its validation results
    # AssetDeletedEvent → ValidationResultCleanupListener removes validation_result rows.
    Given schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded as "text/turtle"
    Then save schema id from last response
    Given credential from fixture "loire/valid/participant.loire.signed.jwt" is not uploaded
    When add credential from fixture "loire/valid/participant.loire.signed.jwt"
    Then save asset id from last response
    When validate saved asset against schema by saved id
    Then get http 200:Success code
      And response has a validation result id
    When delete saved asset
    Then get http 200:Success code
    When get validation result by saved id
    Then get http 404:Not Found code
      And uploaded schemas are cleaned up

  Scenario: Validate with token lacking ASSET_READ role returns 403
    # fc-restricted-test has only SCHEMA_READ — POST /assets/validate requires ASSET_READ or ADMIN_ALL.
    Given credential from fixture "loire/valid/participant.loire.signed.jwt" is not uploaded
    When add credential from fixture "loire/valid/participant.loire.signed.jwt"
    Then save asset id from last response
    Given Keycloak token for user "fc-restricted-test" with password "CHANGE_ME_dev_only1"
    When validate saved asset against all schemas
    Then get http 403:Forbidden code

  Scenario: Validate JSON asset against JSON Schema with file:// $ref returns 400
    # SSRF protection: JsonSchemaValidator rejects external $ref URIs (file://) before schema loading.
    Given schema from fixture "schemas/person-ssrf-file-ref.schema.json" is uploaded as "application/schema+json"
    Then save schema id from last response
    Given asset from fixture "valid/non-rdf/person-valid.json" is not uploaded
    When add asset from fixture "valid/non-rdf/person-valid.json" with content-type "application/json"
    Then save asset id from last response
    When validate saved asset against schema by saved id
    Then get http 400:Bad Request code
      And uploaded schemas are cleaned up

  Scenario: Validate JSON asset against JSON Schema with http:// $ref returns 400
    # SSRF protection: http:// $ref is blocked (only https:// is permitted).
    Given schema from fixture "schemas/person-ssrf-http-ref.schema.json" is uploaded as "application/schema+json"
    Then save schema id from last response
    Given asset from fixture "valid/non-rdf/person-valid.json" is not uploaded
    When add asset from fixture "valid/non-rdf/person-valid.json" with content-type "application/json"
    Then save asset id from last response
    When validate saved asset against schema by saved id
    Then get http 400:Bad Request code
      And uploaded schemas are cleaned up
