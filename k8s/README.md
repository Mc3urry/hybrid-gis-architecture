# Kubernetes manifests (illustrative)

Docker Compose is the reference deployment. These manifests demonstrate the
scaling story that matters for an outage map: Martin is stateless -> Deployment
with replicas (scale it when the storm hits); PostGIS is stateful ->
StatefulSet with a PVC.

Apply order: postgis.yaml, then martin.yaml. Secrets are inline for
readability; in a real cluster they come from a Secret manager (see ADR-005).
