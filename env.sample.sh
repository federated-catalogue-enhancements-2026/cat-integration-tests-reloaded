#!/usr/bin/env bash
: "Usage

Duplicate sample file
$ cp env.sample.sh env.sh

Configure file — set CAT_ENV to your target
$ vim env.sh

Source it before running tests
$ source env.sh

Targets:
  docker-compose   Local Docker Compose stack (federated-catalogue/docker/)
  minikube         Local Minikube / k8s cluster
  qa               Remote QA/staging environment
"

# --------------------------------------------------------------------------
# :: bdd-executor framework path
# --------------------------------------------------------------------------
# Path to the bdd-executor repository root.
# This is used by the Makefile to install the eu-xfsc-bdd dependency.
#
# Common scenarios:
#   As submodule:        ../../bdd-executor (cat-integration-tests in bdd-executor/implementations/)
#   As sibling repo:     ../bdd-executor (both repos cloned side by side)
#   Custom location:     /path/to/bdd-executor (any absolute path)
#
# Default if not set: ../.. (assumes submodule structure)
export EU_XFSC_BDD_CORE_PATH="${EU_XFSC_BDD_CORE_PATH:-../..}"

# --------------------------------------------------------------------------
# :: Target environment selector
# --------------------------------------------------------------------------
#export CAT_ENV="docker-compose"  # docker-compose | minikube | qa
export CAT_ENV="docker-compose"


case ${CAT_ENV} in

  docker-compose)
    # Local Docker Compose stack from federated-catalogue/docker/
    # Prerequisites:
    #   cd ../federated-catalogue/docker && docker-compose --env-file dev.env up
    #   Add `127.0.0.1 key-server` to /etc/hosts
    export CAT_FC_HOST="http://localhost:8081"
    export CAT_KEYCLOAK_URL="http://key-server:8080"
    # Must match KEYCLOAK_REALM in federated-catalogue/docker/dev.env (default: federated-catalogue-realm)
    export CAT_KEYCLOAK_REALM="federated-catalogue-realm"
    export CAT_KEYCLOAK_CLIENT_ID="federated-catalogue"
    # Dev-realm defaults from keycloak/realms/dev/fc-realm.json. The dev realm
    # is bundled with the docker-compose stack, so no Keycloak setup is needed —
    # user fc-ca-test (role ADMIN_ALL) and client secret "**********" are
    # already configured at import time.
    export CAT_KEYCLOAK_CLIENT_SECRET="**********"
    export CAT_KEYCLOAK_SCOPE="openid"
    export CAT_TEST_USER="fc-ca-test"
    export CAT_TEST_PASSWORD="CHANGE_ME_dev_only1"
    # Keycloak Admin REST API — used only by the CAT-FR-AC-01 RBAC role-matrix scenarios
    # (features/18 RBAC Role Matrix.feature) to provision/delete ephemeral test users at
    # runtime. Matches federated-catalogue/docker/dev.env's KEYCLOAK_ADMIN/KEYCLOAK_ADMIN_PASSWORD.
    export CAT_KEYCLOAK_ADMIN_USER="admin"
    export CAT_KEYCLOAK_ADMIN_PASSWORD="admin"
    # WireMock for @uses.compliance-mock scenarios (see docker-compose stack)
    export CAT_WIREMOCK_HOST="http://localhost:8089"
    ;;

  minikube)
    # Local Minikube or kind cluster
    # Adjust host/port to match your ingress or NodePort setup
    export CAT_FC_HOST="http://localhost:30081"
    export CAT_KEYCLOAK_URL="http://localhost:30080"
    # Must match the realm configured in the Helm chart (default: federated-catalogue-realm)
    export CAT_KEYCLOAK_REALM="federated-catalogue-realm"
    export CAT_KEYCLOAK_CLIENT_ID="federated-catalogue"
    # Dev realm defaults (same as docker-compose target); set explicitly if your
    # Helm values override them.
    export CAT_KEYCLOAK_CLIENT_SECRET="**********"
    export CAT_KEYCLOAK_SCOPE="openid"
    export CAT_TEST_USER="fc-ca-test"
    export CAT_TEST_PASSWORD="CHANGE_ME_dev_only1"
    # Keycloak Admin REST API — see the docker-compose block above for what this is for.
    export CAT_KEYCLOAK_ADMIN_USER="admin"
    export CAT_KEYCLOAK_ADMIN_PASSWORD="admin"
    export CAT_WIREMOCK_HOST="http://localhost:8089"
    ;;

  qa)
    # Remote QA / staging environment
    # Set these to your actual QA endpoints and credentials
    export CAT_FC_HOST="https://fc-server.qa.example.org"
    export CAT_KEYCLOAK_URL="https://keycloak.qa.example.org"
    # Existing QA stages with a pre-existing gaia-x realm should keep "gaia-x" here.
    export CAT_KEYCLOAK_REALM="federated-catalogue-realm"
    export CAT_KEYCLOAK_CLIENT_ID="federated-catalogue"
    export CAT_KEYCLOAK_CLIENT_SECRET="your-qa-secret-here"
    export CAT_KEYCLOAK_SCOPE="openid"
    export CAT_TEST_USER="qa-test-user"
    export CAT_TEST_PASSWORD="qa-test-password"
    # Keycloak Admin REST API — set to real QA-realm admin credentials if the RBAC
    # role-matrix scenarios (features/18 RBAC Role Matrix.feature) are run against this target.
    export CAT_KEYCLOAK_ADMIN_USER="your-qa-admin-user-here"
    export CAT_KEYCLOAK_ADMIN_PASSWORD="your-qa-admin-password-here"
    # Compliance mock for @uses.compliance-mock scenarios. If the mock runs in-cluster
    # (Helm complianceMock.enabled), port-forward it and point here at the local port:
    #   kubectl port-forward -n federated-catalogue svc/fc-compliance-mock 8089:8080
    export CAT_WIREMOCK_HOST="http://localhost:8089"
    ;;

  *)
    echo "ERROR: Unknown CAT_ENV='${CAT_ENV}'. Use: docker-compose | minikube | qa"
    return 1 2>/dev/null || exit 1
    ;;

esac

echo "CAT_ENV=${CAT_ENV} — FC @ ${CAT_FC_HOST}, Keycloak @ ${CAT_KEYCLOAK_URL}"
