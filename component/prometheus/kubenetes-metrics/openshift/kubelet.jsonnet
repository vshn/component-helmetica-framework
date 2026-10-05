local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.helmetica_framework;

[
  {
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
      scrapeClass: 'tls-client-certificate-auth',
      selector: {
        matchLabels: {
          'k8s-app': 'kubelet',
        },
      },
      serviceDiscoveryRole: 'EndpointSlice',
    },
  },
  {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: 'copy-metrics-secret',
      namespace: params.monitoring_stack.namespace,
    },
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'Role',
    metadata: {
      name: 'copy-metrics-secret',
      namespace: params.monitoring_stack.namespace,
    },
    rules: [
      {
        apiGroups: [
          '',
        ],
        resources: [
          'secrets',
        ],
        verbs: [
          'get',
          'list',
          'watch',
          'create',
          'patch',
        ],
      },
    ],
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'RoleBinding',
    metadata: {
      name: 'copy-metrics-secret',
      namespace: params.monitoring_stack.namespace,
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Role',
      name: 'copy-metrics-secret',
    },
    subjects: [
      {
        kind: 'ServiceAccount',
        name: 'copy-metrics-secret',
        namespace: params.monitoring_stack.namespace,
      },
    ],
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'Role',
    metadata: {
      name: '%s:copy-metrics-secret' % params.monitoring_stack.namespace,
      namespace: 'openshift-monitoring',
    },
    rules: [
      {
        apiGroups: [
          '',
        ],
        resources: [
          'secrets',
        ],
        verbs: [
          'get',
          'list',
          'watch',
        ],
      },
    ],
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'RoleBinding',
    metadata: {
      name: '%s:copy-metrics-secret' % params.monitoring_stack.namespace,
      namespace: 'openshift-monitoring',
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Role',
      name: '%s:copy-metrics-secret' % params.monitoring_stack.namespace,
    },
    subjects: [
      {
        kind: 'ServiceAccount',
        name: 'copy-metrics-secret',
        namespace: params.monitoring_stack.namespace,
      },
    ],
  },
  {
    apiVersion: 'espejote.io/v1alpha1',
    kind: 'ManagedResource',
    metadata: {
      annotations: {
        'syn.tools/description': 'TODO',
      },
      name: 'copy-metrics-secret',
      namespace: params.monitoring_stack.namespace,
    },
    spec: {
      applyOptions: {
        force: true,
      },
      context: [
        {
          name: 'source_secret',
          resource: {
            apiVersion: 'v1',
            kind: 'Secret',
            name: 'metrics-client-certs',
            namespace: 'openshift-monitoring',
          },
        },
      ],
      serviceAccountRef: {
        name: 'copy-metrics-secret',
      },
      template: "local esp = import 'espejote.libsonnet';\n\nlocal source = esp.context().source_secret;\nassert\n  std.length(source) == 1\n  : 'Expected source context to have exactly 1 element';\n\nlocal sourceSecret = source[0];\n\n{\n  apiVersion: sourceSecret.apiVersion,\n  kind: sourceSecret.kind,\n  metadata: {\n    name: 'ocp-metrics-client-certs',\n    labels: {\n      'app.kubernetes.io/managed-by': 'espejote',\n      'app.kubernetes.io/part-of': 'helmetica',\n      'app.kubernetes.io/component': 'helmetica-framework',\n    },\n  },\n  type: sourceSecret.type,\n  data: sourceSecret.data,\n}\n",
      triggers: [
        {
          name: 'watch-source-tls-secret',
          watchContextResource: {
            name: 'source_secret',
          },
        },
        {
          name: 'watch-target-tls-secret',
          watchResource: {
            apiVersion: 'v1',
            kind: 'Secret',
            name: 'ocp-metrics-client-certs',
          },
        },
      ],
    },
  },
]
