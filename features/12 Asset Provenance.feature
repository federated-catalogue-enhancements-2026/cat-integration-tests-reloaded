@domain.asset @req.CAT-FR-LM-02 @cfg.default
Feature: Asset Provenance and Versioning
  Verifies that provenance credentials can be attached to asset versions, retrieved,
  and verified — and that adding provenance does not create new asset revisions.

  Background:
    Given CAT Keycloak is up
      And saved Keycloak token
      And Federated Catalogue Server is up
      And credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded

  Scenario: Attach provenance credentials to versioned asset, retrieve and verify them
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 201:Created code
     And save asset id from last response
    When update saved asset with fixture "valid/version-control/gaiax-participant-v2.vp.jsonld"
    Then get http 200:Success code
    When get saved asset versions
    Then get http 200:Success code
     And save asset version count and latest version ordinal
    When add provenance credential for saved asset at version 1 with predicate "prov:wasGeneratedBy"
    Then get http 201:Created code
     And save provenance credential id from last response
    When add provenance credential for saved asset at version 2 with predicate "prov:wasRevisionOf"
    Then get http 201:Created code
    When list provenance credentials for saved asset
    Then response has 2 provenance credentials
    When list provenance credentials for saved asset at version 1
    Then response contains saved provenance credential
    When get saved provenance credential
    Then get http 200:Success code
    When verify saved provenance credential
    Then provenance verification result is valid
    When verify all provenance credentials for saved asset
    Then all provenance verification results are valid
    When get saved asset versions
    Then total version count is unchanged
     And credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded

  Scenario: Adding a provenance credential does not create a new asset version
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 201:Created code
     And save asset id from last response
    When get saved asset versions
    Then get http 200:Success code
     And save asset version count and latest version ordinal
    When add provenance credential for saved asset at saved version with predicate "prov:wasGeneratedBy"
    Then get http 201:Created code
    When get saved asset versions
    Then get http 200:Success code
     And total version count is unchanged
     And credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded

  Scenario: Deleting an asset cascades delete of its provenance credentials
    # AssetDeletedEvent → ProvenanceCleanupListener removes provenance_credentials rows.
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 201:Created code
     And save asset id from last response
    When add provenance credential for saved asset at version 1 with predicate "prov:wasGeneratedBy"
    Then get http 201:Created code
    When list provenance credentials for saved asset
    Then response has 1 provenance credentials
    When delete saved asset
    Then get http 200:Success code
    When list provenance credentials for saved asset
    Then get http 404:Not Found code

  Scenario Outline: Activity- and agent-side PROV-O predicates are accepted on credentialSubject
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 201:Created code
     And save asset id from last response
    When add provenance credential for saved asset at version 1 with predicate "<predicate>"
    Then get http 201:Created code
    When list provenance credentials for saved asset
    Then response has 1 provenance credentials
     And projected graph contains predicate "<predicate>" for saved asset at version 1
     And credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded

    Examples:
      | predicate              |
      | prov:generated         |
      | prov:used              |
      | prov:wasAssociatedWith |
      | prov:actedOnBehalfOf   |

  Scenario: Multiple PROV-O predicates on the same credentialSubject are all projected
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 201:Created code
     And save asset id from last response
    When add provenance credential for saved asset at version 1 with predicates "prov:wasGeneratedBy,prov:wasAssociatedWith,prov:actedOnBehalfOf"
    Then get http 201:Created code
    When list provenance credentials for saved asset
    Then response has 1 provenance credentials
     And projected graph contains predicate "prov:wasGeneratedBy" for saved asset at version 1
     And projected graph contains predicate "prov:wasAssociatedWith" for saved asset at version 1
     And projected graph contains predicate "prov:actedOnBehalfOf" for saved asset at version 1
     And credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded

  Scenario: Cascade-delete by asset IRI is idempotent and clears every version
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 201:Created code
     And save asset id from last response
    When add provenance credential for saved asset at version 1 with predicate "prov:wasGeneratedBy"
    Then get http 201:Created code
    When cascade-delete saved asset by id
    Then get http 204:No Content code
    # Spec: 204 on unknown id (idempotent)
    When cascade-delete saved asset by id
    Then get http 204:No Content code
    When list provenance credentials for saved asset
    Then get http 404:Not Found code

  @domain.asset
  Scenario: Activity-centric provenance VC is accepted
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 201:Created code
     And save asset id from last response
    When add activity-centric provenance credential for saved asset at version 1 with activity IRI "urn:activity:test-1" and predicates "prov:generated,prov:wasAssociatedWith"
    Then get http 201:Created code
    When list provenance credentials for saved asset
    Then response has 1 provenance credentials
     And projected graph contains predicate "prov:generated" for activity IRI "urn:activity:test-1"
     And projected graph contains predicate "prov:wasAssociatedWith" for activity IRI "urn:activity:test-1"
     And credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded

  @domain.asset
  Scenario: Multiple activity-centric provenance credentials on the same asset version
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 201:Created code
     And save asset id from last response
    When add activity-centric provenance credential for saved asset at version 1 with activity IRI "urn:activity:multi-a" and predicates "prov:generated,prov:wasAssociatedWith"
    Then get http 201:Created code
    When add activity-centric provenance credential for saved asset at version 1 with activity IRI "urn:activity:multi-b" and predicates "prov:generated,prov:wasInformedBy"
    Then get http 201:Created code
    When list provenance credentials for saved asset
    Then response has 2 provenance credentials
     And projected graph contains predicate "prov:generated" for activity IRI "urn:activity:multi-a"
     And projected graph contains predicate "prov:generated" for activity IRI "urn:activity:multi-b"
     And credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded

  @domain.asset
  Scenario: Cascade-delete by asset IRI removes activity-centric provenance across versions
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 201:Created code
     And save asset id from last response
    When update saved asset with fixture "valid/version-control/gaiax-participant-v2.vp.jsonld"
    Then get http 200:Success code
    When add activity-centric provenance credential for saved asset at version 1 with activity IRI "urn:activity:cascade-v1" and predicates "prov:generated"
    Then get http 201:Created code
    When add activity-centric provenance credential for saved asset at version 2 with activity IRI "urn:activity:cascade-v2" and predicates "prov:generated"
    Then get http 201:Created code
    When cascade-delete saved asset by id
    Then get http 204:No Content code
    # Spec: 204 on unknown id (idempotent)
    When cascade-delete saved asset by id
    Then get http 204:No Content code
    When list provenance credentials for saved asset
    Then get http 404:Not Found code

  @domain.asset
  Scenario: SPARQL-Star discovery query finds asset credential subject via reification
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 201:Created code
     And save asset id from last response
    When execute SPARQL query
      """
      PREFIX cred: <https://www.w3.org/2018/credentials#>
      PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
      PREFIX gx: <https://w3id.org/gaia-x/2511#>
      SELECT ?subject WHERE {
        <<(?subject rdf:type gx:LegalPerson)>> cred:credentialSubject ?cs .
      }
      LIMIT 10
      """
    Then get http 200:Success code
     And query result contains "did:key:z6MkjRagNiMu91DduvCvgEsqLZDVzrJzFrwahc4tXLt9DoHd"
     And credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded

  Scenario: Verifying an asset with no provenance credentials reports failure without a timestamp
    # CAT-FR-LM-02 vacuous-pass fix: zero credentials must not verify as isValid=true.
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 201:Created code
     And save asset id from last response
    When verify all provenance credentials for saved asset
    Then get http 200:Success code
     And all provenance verification results are invalid with reason "No provenance credentials present for this asset"
     And all provenance verification results have no verification timestamp
     And credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded

  Scenario: A version without provenance credentials is distinguishable from a sibling version with valid ones
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 201:Created code
     And save asset id from last response
    When update saved asset with fixture "valid/version-control/gaiax-participant-v2.vp.jsonld"
    Then get http 200:Success code
    When add provenance credential for saved asset at version 1 with predicate "prov:wasGeneratedBy"
    Then get http 201:Created code
    When verify all provenance credentials for saved asset at version 1
    Then get http 200:Success code
     And all provenance verification results are valid
    When verify all provenance credentials for saved asset at version 2
    Then get http 200:Success code
     And all provenance verification results are invalid with reason "No provenance credentials present for this asset"
     And all provenance verification results have no verification timestamp
     And credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded

  Scenario: Attaching a human-readable companion does not advance the asset version counter
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 201:Created code
     And save asset id from last response
    When get saved asset versions
    Then save asset version count and latest version ordinal
    When attach human-readable companion "valid/dcs-templates/contract-template-v1.txt" to saved asset
    Then get http 201:Created code
    When get saved asset versions
    Then total version count is unchanged
     And credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded
