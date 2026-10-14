local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.helmetica_framework;

// Scrapes the kubelet for the metrics of the instance namespaces. scrapeClass is the
// Prometheus scrape class that holds the platform's kubelet credentials.
local serviceMonitor(scrapeClass) = {
  apiVersion: 'monitoring.coreos.com/v1',
  kind: 'ServiceMonitor',
  metadata: {
    name: 'kubelet',
    namespace: params.monitoring_stack.namespace,
  },
  spec: {
    attachMetadata: {
      node: true,
    },
    endpoints: [
      {
        honorLabels: true,
        honorTimestamps: true,
        interval: '30s',
        metricRelabelings: [
          {
            action: 'keep',
            regex: 'container_memory_working_set_bytes',
            sourceLabels: [
              '__name__',
            ],
          },
          {
            action: 'keep',
            regex: '(hel|)x-.+',
            sourceLabels: [
              'namespace',
            ],
          },
        ],
        path: '/metrics/cadvisor',
        port: 'https-metrics',
        relabelings: [
          {
            action: 'replace',
            sourceLabels: [
              '__metrics_path__',
            ],
            targetLabel: 'metrics_path',
          },
        ],
        scheme: 'https',
        scrapeTimeout: '30s',
        trackTimestampsStaleness: true,
      },
      {
        honorLabels: true,
        interval: '30s',
        metricRelabelings: [
          {
            action: 'keep',
            regex: '(kubelet_volume_stats_.+)',
            sourceLabels: [
              '__name__',
            ],
          },
          {
            action: 'keep',
            regex: '(hel|)x-.+',
            sourceLabels: [
              'namespace',
            ],
          },
        ],
        port: 'https-metrics',
        relabelings: [
          {
            action: 'replace',
            sourceLabels: [
              '__metrics_path__',
            ],
            targetLabel: 'metrics_path',
          },
        ],
        scheme: 'https',
        scrapeTimeout: '30s',
      },
    ],
    jobLabel: 'k8s-app',
    namespaceSelector: {
      matchNames: [
        'kube-system',
      ],
    },
    scrapeClass: scrapeClass,
    selector: {
      matchLabels: {
        'k8s-app': 'kubelet',
      },
    },
    serviceDiscoveryRole: 'EndpointSlice',
  },
};

{
  serviceMonitor: serviceMonitor,
}
