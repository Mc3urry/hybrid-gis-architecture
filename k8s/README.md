# Kubernetes manifests (illustrative)

Docker Compose is the reference deployment. These manifests demonstrate the
scaling story that matters for an outage map: Martin is stateless -> Deployment
with replicas (scale it when the storm hits); PostGIS is stateful ->
StatefulSet with a PVC.

Apply order (from the repository root):

1. `kubectl create configmap db-init --from-file=db/init/` — the schema,
   synthetic data, and public views, delivered the Kubernetes way. Compose
   mounts this directory directly; Kubernetes packages it as a ConfigMap.
2. `kubectl apply -f k8s/postgis.yaml` — wait for the pod to be Ready
   (the init SQL runs on first boot, as in compose).
3. `kubectl apply -f k8s/martin.yaml` — three replicas behind a
   LoadBalancer on port 80.

Verify: http://localhost:80/catalog lists both public views (the same
catalog-first check as always). The scaling demonstration:
`kubectl scale deployment martin --replicas=5`, then delete one pod and
watch the Deployment replace it — the storm-response property of a
stateless tier, observed rather than asserted.

Secrets are inline for readability; in a real cluster they come from a
Secret manager (see ADR-005).
