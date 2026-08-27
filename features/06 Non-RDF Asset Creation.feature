@domain.asset @extended @req.CAT-FR-AM-01
Feature: Non-RDF Asset Creation
  As a user of the Federated Catalogue
  I want to upload assets in arbitrary formats via the /assets endpoint
  So that the catalogue can store Contract Templates, PDFs, images and other file types alongside RDF credentials

  # The /assets endpoint accepts non-RDF content types.
  # Non-RDF assets bypass RDF verification and are stored in the FileStore.
  # RDF assets continue through the existing verification + graph storage path.

  Background:
    Given CAT Keycloak is up
      And saved Keycloak token
      And Federated Catalogue Server is up

  Scenario: Upload plain text file via multipart/form-data
    # A plain text contract template is uploaded as multipart/form-data.
    # The server stores it without RDF verification and returns 201 with metadata.
    Given asset from fixture "valid/non-rdf/template.txt" is not uploaded
    When add asset from fixture "valid/non-rdf/template.txt" with content-type "text/plain"
    Then get http 201:Created code
      And response content-type is "text/plain"
      And response has file size greater than 0

  Scenario: Upload YAML config file via multipart/form-data
    # YAML files are treated as non-RDF assets.
    Given asset from fixture "valid/non-rdf/config.yaml" is not uploaded
    When add asset from fixture "valid/non-rdf/config.yaml" with content-type "application/x-yaml"
    Then get http 201:Created code
      And response content-type is "application/x-yaml"
      And response has file size greater than 0

  Scenario: Upload PDF binary file via multipart/form-data
    # A PDF file is uploaded as multipart/form-data with binary integrity preserved.
    Given asset from fixture "valid/non-rdf/sample.pdf" is not uploaded
    When add asset from fixture "valid/non-rdf/sample.pdf" with content-type "application/pdf"
    Then get http 201:Created code
      And response content-type is "application/pdf"
      And response has file size greater than 0

  Scenario: Upload plain JSON without @context is stored without verification
    # A JSON file without @context is NOT JSON-LD. It is stored as a non-RDF asset
    # without going through RDF verification or graph storage.
    Given asset from fixture "valid/non-rdf/contract.json" is not uploaded
    When add asset from fixture "valid/non-rdf/contract.json" with content-type "application/json"
    Then get http 201:Created code
      And response content-type is "application/json"
      And response has file size greater than 0

  Scenario: Upload file via application/octet-stream
    # Binary upload using raw body with application/octet-stream content-type.
    # The server accepts it as a non-RDF asset.
    Given asset from fixture "valid/non-rdf/sample.pdf" is not uploaded
    When add asset from fixture "valid/non-rdf/sample.pdf" as raw binary
    Then get http 201:Created code
      And response has file size greater than 0

  @req.CAT-FR-AC-01
  Scenario: User with only ASSET_CREATE can create an asset but cannot delete it
    # fc-asset-creator-test has only ASSET_CREATE — proves a fine-grained role
    # grants exactly its own operation, not others (CAT-FR-AC-01 role isolation).
    Given asset from fixture "valid/non-rdf/template.txt" is not uploaded
    Given Keycloak token for user "fc-asset-creator-test" with password "CHANGE_ME_dev_only1"
    When add asset from fixture "valid/non-rdf/template.txt" with content-type "text/plain"
    Then get http 201:Created code
      And save asset id from last response
    When delete saved asset
    Then get http 403:Forbidden code
    # Cleanup: the restricted user cannot delete it, so re-authenticate as the
    # default admin user to remove the asset and avoid leaking test data.
    Given Keycloak token for user "fc-ca-test" with password "CHANGE_ME_dev_only1"
    When delete saved asset
    Then get http 200:Success code
