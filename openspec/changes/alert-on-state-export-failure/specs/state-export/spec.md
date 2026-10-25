# Spec Delta

## ADDED Requirements

### Requirement: A stale export raises an alert
An alert SHALL fire through the cluster's Alertmanager when no export run has succeeded for 12 hours. A run succeeds when it pushed, or when it found nothing to push. Missing export metrics SHALL count as no success.

#### Scenario: Secret scan keeps blocking
- **WHEN** every export run for 12 hours is blocked by a secret-scan finding
- **THEN** an alert fires that names the failure as a scan finding

#### Scenario: Push keeps failing
- **WHEN** every export run for 12 hours fails to push, for example because the deploy key was revoked
- **THEN** an alert fires

#### Scenario: Metrics disappear
- **WHEN** Prometheus has had no export metrics from the sidecar for 12 hours
- **THEN** an alert fires

#### Scenario: Exports recover
- **WHEN** a run succeeds after the alert fired
- **THEN** the alert resolves

#### Scenario: Healthy export with nothing to push
- **WHEN** runs keep succeeding without changes for more than 12 hours
- **THEN** no alert fires

### Requirement: Failure logs carry the real exit code
When an export run fails, the sidecar's log line SHALL report that run's exit code.

#### Scenario: Run fails
- **WHEN** an export run exits with a non-zero code
- **THEN** the log line names that code
