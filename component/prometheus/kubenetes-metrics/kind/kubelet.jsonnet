local kubelet = import '../kubelet.libsonnet';

[
  // The scrape class is defined on the Prometheus, see prometheus.jsonnet.
  kubelet.serviceMonitor('kubelet-serviceaccount-auth'),
]
