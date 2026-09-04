@domain.asset @req.CAT-FR-AM-03 @cfg.default
Feature: Asset Metadata Enrichment
  As an authorized user of the Federated Catalogue
  I want to attach RDF metadata to a non-RDF asset via POST /assets
  So that the non-RDF asset becomes queryable through the graph database

  # when an RDF graph is uploaded via POST /assets and its primary
  # @id matches the subject IRI of an existing non-RDF asset, the server stores
  # the triples as enrichment (HTTP 200) instead of creating a new asset (201)
  # or a new version. The non-RDF binary content stays intact.

  Background:
    Given CAT Keycloak is up
      And saved Keycloak token
      And Federated Catalogue Server is up

  Scenario: Enrich non-RDF asset with RDF metadata, content preserved and triple queryable
    # Upload a non-RDF asset, then upload an RDF graph whose @id is the asset's IRI.
    # The non-RDF binary content stays intact and the new triples become queryable.
    Given asset from fixture "valid/non-rdf/template.txt" is not uploaded
    When add asset from fixture "valid/non-rdf/template.txt" with content-type "text/plain"
    Then get http 201:Created code
     And save asset id from last response
     And save file size from last response
    When enrich saved asset with fixture "valid/enrichment/metadata-basic.jsonld"
    Then get http 200:Success code
     And response assetId matches saved asset id
     And response triplesAdded is at least 1
     And response triplesRejected is 0
    When get saved asset
    Then get http 200:Success code
     And response content-type is "text/plain"
     And response file size matches saved file size
    When execute SPARQL query
      """
      PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
      PREFIX ex: <http://example.org/>
      SELECT ?asset WHERE {
        <<(?asset rdf:type ex:ContractTemplate)>>
          <https://www.w3.org/2018/credentials#credentialSubject> ?subject .
      }
      LIMIT 50
      """
    Then get http 200:Success code
     And query result contains saved asset id
    Then asset from fixture "valid/non-rdf/template.txt" is not uploaded

  Scenario: Re-uploading an RDF asset with the same subject creates a new version
    # Upload an RDF asset, then POST another RDF graph with the same primary @id.
    # The second upload is recognized as a new version of the existing RDF asset.
    Given credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded
      And credential from fixture "valid/version-control/gaiax-participant-correct-type-v2.vp.jsonld" is not uploaded
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 201:Created code
     And save asset id from last response
    When add credential from fixture "valid/version-control/gaiax-participant-correct-type-v2.vp.jsonld"
    Then get http 201:Created code
    When get saved asset versions
    Then get http 200:Success code
     And response has 2 total versions
    Then credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded
     And credential from fixture "valid/version-control/gaiax-participant-correct-type-v2.vp.jsonld" is not uploaded

  Scenario: Re-enrichment replaces prior triples instead of appending
    # Each enrichment call deletes the previous triples for the subject before
    # writing the new ones, so the latest title literal replaces the prior one.
    # (Asserted via the dct:title literal — the user-facing "replace" signal.)
    Given asset from fixture "valid/non-rdf/template.txt" is not uploaded
    When add asset from fixture "valid/non-rdf/template.txt" with content-type "text/plain"
    Then get http 201:Created code
     And save asset id from last response
    When enrich saved asset with fixture "valid/enrichment/metadata-draft.jsonld"
    Then get http 200:Success code
    When enrich saved asset with fixture "valid/enrichment/metadata-final.jsonld"
    Then get http 200:Success code
    When execute SPARQL query
      """
      PREFIX dct: <http://purl.org/dc/terms/>
      SELECT ?asset WHERE {
        <<(?asset dct:title "Final v1")>>
          <https://www.w3.org/2018/credentials#credentialSubject> ?subject .
      }
      LIMIT 50
      """
    Then get http 200:Success code
     And query result contains saved asset id
    When execute SPARQL query
      """
      PREFIX dct: <http://purl.org/dc/terms/>
      SELECT ?asset WHERE {
        <<(?asset dct:title "Draft v1")>>
          <https://www.w3.org/2018/credentials#credentialSubject> ?subject .
      }
      LIMIT 50
      """
    Then get http 200:Success code
     And query result does not contain saved asset id
    Then asset from fixture "valid/non-rdf/template.txt" is not uploaded

  Scenario: Version-specific read of a non-RDF asset returns its own content
    # Regression test for backlog story 072: GET /assets/{id}?version=N shares the same
    # content-resolution code as the no-version read (feature file's first scenario), but was
    # never exercised through the version-specific path. A non-RDF asset's persisted content
    # column holds the enrichment RDF document, not the original payload; before the fix, the
    # version-specific read returned that column's value directly instead of falling back to the
    # file store, so an enrichment leaked out as the reported asset body. Enriching before the
    # version-specific read (a standalone non-RDF asset always has exactly one content version —
    # only a genuine re-upload with the same subject IRI would add one, and the multipart upload
    # endpoint always mints a fresh IRI) makes the assertion non-trivial: it fails against an
    # implementation that returns the persisted content column for a versioned read.
    Given asset from fixture "valid/non-rdf/template.txt" is not uploaded
    When add asset from fixture "valid/non-rdf/template.txt" with content-type "text/plain"
    Then get http 201:Created code
     And save asset id from last response
     And save file size from last response
    When enrich saved asset with fixture "valid/enrichment/metadata-basic.jsonld"
    Then get http 200:Success code
    When get saved asset at version 1
    Then get http 200:Success code
     And response content-type is "text/plain"
     And response file size matches saved file size
     And response rawContent matches fixture "valid/non-rdf/template.txt"
    When get saved asset at version 2
    Then get http 404:Not Found code
    Then asset from fixture "valid/non-rdf/template.txt" is not uploaded

  Scenario: Reported size, hash and content-type describe the payload, not the enrichment document (AM-03)
    # Reproduces: a 27-byte non-RDF payload enriched with a ~129-byte metadata document, asserting
    # fileSize/assetHash/contentType describe the payload, not the enrichment document.
    # `contentKind` is deliberately not asserted — not part of the documented Asset schema.
    # KNOWN DEFECT: the list path (GET /assets) reports fileSize: null for non-RDF assets, so the
    # final list assertion is EXPECTED RED until fixed. Not weakened to match the defect.
    Given asset from fixture "valid/non-rdf/qa-am-03-27-bytes.txt" is not uploaded
    When add asset from fixture "valid/non-rdf/qa-am-03-27-bytes.txt" with content-type "text/plain"
    Then get http 201:Created code
     And save asset id from last response
     And save file size from last response
    When enrich saved asset with fixture "valid/enrichment/metadata-qa-am-03.jsonld"
    Then get http 200:Success code
    When get saved asset
    Then get http 200:Success code
     And response content-type is "text/plain"
     And response file size matches saved file size
     And response assetHash matches saved asset hash
    When list assets filtered by saved asset id
    Then get http 200:Success code
     And listed asset meta contentType is "text/plain", file size and assetHash match saved values
    Then asset from fixture "valid/non-rdf/qa-am-03-27-bytes.txt" is not uploaded

  Scenario: Enriching a human-readable asset is rejected with HTTP 422
    # Human-readable representations are managed via /assets/{id}/human-readable
    # and must not be enriched.
    Given credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded
      And asset from fixture "valid/non-rdf/sample.pdf" is not uploaded
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 201:Created code
     And save asset id from last response
    When upload human-readable from fixture "valid/non-rdf/sample.pdf" with content-type "application/pdf" for saved asset
    Then get http 201:Created code
     And save human-readable id from last response
    When enrich saved human-readable asset with fixture "valid/enrichment/metadata-basic.jsonld"
    Then get http 422:Unprocessable Entity code
    Then credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded
     And asset from fixture "valid/non-rdf/sample.pdf" is not uploaded
