# noinspection PyUnresolvedReferences
import os
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path

from behave_html_formatter.html import HTMLFormatter
from eu.xfsc.bdd.core import environment
# noinspection PyUnresolvedReferences
from eu.xfsc.bdd.core.steps import *
from eu.xfsc.bdd.core.server.keycloak import Token


def before_all(context) -> None:
    environment.before_all(context)

    context.FileToken = Token(Path(__file__).parent / ".tmp")
    _stamp_html_report(context)


def _stamp_html_report(context) -> None:
    # Appends the target base URL and run timestamp to the HTML report title so the
    # report self-evidently proves which deployment instance was tested. Runs once
    # globally (called from before_all) — not per scenario.
    base_url = os.environ.get("CAT_FC_HOST", "unknown")
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    for formatter in context._runner.formatters:
        if isinstance(formatter, HTMLFormatter):
            formatter.set_title(f" — {base_url}  @  {timestamp}", append=True, style="font-size:0.6em;color:#555")


def before_scenario(context, scenario) -> None:
    """Reset multi-asset tracking to avoid cross-scenario leakage."""
    if hasattr(context, "last_asset_ids"):
        del context.last_asset_ids


def after_scenario(context, scenario) -> None:
    """Always clean up uploaded schemas to prevent cross-scenario leakage when a scenario fails."""
    try:
        schema_ids = list(context._uploaded_schema_ids)
    except (AttributeError, KeyError):
        schema_ids = []
    for schema_id in schema_ids:
        try:
            encoded = urllib.parse.quote(schema_id, safe="")
            context.fc_server.delete_schema(encoded)
        except Exception:  # noqa: BLE001
            pass
    try:
        context._uploaded_schema_ids = []
    except (AttributeError, KeyError):
        pass

    # Reset trust-framework enabled state to the seeded default (all disabled). Discovery and
    # compliance scenarios enable a family via Background; with a family enabled the server
    # switches to strict semantics (untyped credentials rejected), which breaks later
    # @cfg.default scenarios (e.g. provenance, custom-subclass) and leaks across runs. The
    # state is Background-set, so per-scenario Gherkin steps cannot clean it up on failure —
    # this hook is the only safe place.
    # GET /trust-frameworks returns only enabled families (no "enabled" field), so every id
    # in the response is currently enabled and must be reset to disabled.
    try:
        frameworks = context.fc_server.get_trust_frameworks().json()
    except Exception:  # noqa: BLE001
        frameworks = []
    for framework in frameworks if isinstance(frameworks, list) else []:
        framework_id = framework.get("id")
        if framework_id:
            try:
                context.fc_server.set_trust_framework_enabled(framework_id, enabled=False)
            except Exception:  # noqa: BLE001
                pass

    # Restore any base-class-toggle states that were disabled during the scenario.
    # This runs unconditionally so that a failed assertion cannot leave a base class
    # disabled and poison subsequent scenarios (@domain.admin base-class-toggle tests).
    try:
        disabled_base_classes = list(context.disabled_base_classes)
    except AttributeError:
        disabled_base_classes = []
    for bundle_id, base_class_name in disabled_base_classes:
        try:
            context.fc_server.set_trust_framework_base_class_enabled(bundle_id, base_class_name, enabled=True)
        except Exception:  # noqa: BLE001
            pass
    try:
        context.disabled_base_classes = []
    except AttributeError:
        pass

    # Restore any schema-validation modules that were disabled during the scenario.
    # Same rationale as above — a mid-scenario failure must not leak a disabled module
    # into subsequent scenarios (recurring: SHACL/JSON_SCHEMA/XML_SCHEMA/OWL toggles).
    try:
        disabled_modules = list(context.disabled_schema_modules)
    except AttributeError:
        disabled_modules = []
    for module_type in disabled_modules:
        try:
            context.fc_server.set_schema_module_enabled(module_type, enabled=True)
        except Exception:  # noqa: BLE001
            pass
    try:
        context.disabled_schema_modules = []
    except AttributeError:
        pass

    # Clear any per-bundle config overrides applied during the scenario so a
    # mid-scenario failure cannot leave a bundle pointing at a stale compliance
    # endpoint and poison subsequent scenarios (CAT-FR-CO-03 bundle-config tests).
    try:
        overridden_bundles = list(context.overridden_bundles)
    except AttributeError:
        overridden_bundles = []
    for bundle_id in overridden_bundles:
        try:
            context.fc_server.delete_trust_framework_bundle_config(bundle_id)
        except Exception:  # noqa: BLE001
            pass
    try:
        context.overridden_bundles = []
    except AttributeError:
        pass
