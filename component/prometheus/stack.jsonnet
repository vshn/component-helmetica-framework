local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.helmetica_framework;

local nsSelector = {
  matchExpressions: [
    {
      key: 'helmetica.io/monitoring',
      operator: 'Exists',
    },
  ],
};

local platform =
  local allowedPlatforms = [ 'talos', 'openshift4' ];
  assert std.contains(allowedPlatforms, params.monitoring_stack.platform) : "Invalid platform '%s' specified for monitoring_stack. Allowed values: %s" % [ params.monitoring_stack.platform, std.join(', ', allowedPlatforms) ];
  params.monitoring_stack.platform;

local platformSpecificConfig =
  if platform == 'talos' then
    {}
  else if platform == 'openshift4' then
    {
      spec+: {
        scrapeClasses+: [
          {
            name: 'tls-client-certificate-auth',
            tlsConfig: {
              ca: {},
              cert: {},
              certFile: '/etc/prometheus/secrets/ocp-metrics-client-certs/tls.crt',
              insecureSkipVerify: true,
              keyFile: '/etc/prometheus/secrets/ocp-metrics-client-certs/tls.key',
            },
          },
        ],
        secrets+: [
          'ocp-metrics-client-certs',
        ],
      },
    }
  else
    {};

local trimPrefix(str, prefix) =
  if std.startsWith(str, prefix) then
    std.substr(str, std.length(prefix), std.length(str) - std.length(prefix))
  else
    str;

[
  {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: 'prometheus-stack',
      namespace: params.monitoring_stack.namespace,
    },
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRole',
    metadata: {
      name: '%s:prometheus-stack' % params.monitoring_stack.namespace,
    },
    rules: [
      {
        apiGroups: [
          '',
        ],
        resources: [
          'services',
          'nodes',
          'endpoints',
          'pods',
        ],
        verbs: [
          'get',
          'list',
          'watch',
        ],
      },
      {
        apiGroups: [
          'discovery.k8s.io',
        ],
        resources: [
          'endpointslices',
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
    kind: 'ClusterRoleBinding',
    metadata: {
      name: '%s:helmetica-prometheus-stack' % params.monitoring_stack.namespace,
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: '%s:helmetica-prometheus-stack' % params.monitoring_stack.namespace,
    },
    subjects: [
      {
        kind: 'ServiceAccount',
        name: 'prometheus-stack',
        namespace: params.monitoring_stack.namespace,
      },
    ],
  },
  {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'Prometheus',
    metadata: {
      name: 'stack',
      namespace: params.monitoring_stack.namespace,
      annotations: {
        'operator.prometheus.io/controller-id': '%s/prometheus-operator' % params.monitoring_stack.namespace,
      },
    },
    spec: {
      serviceAccountName: 'prometheus-stack',
      replicas: 1,
      resources: params.monitoring_stack.resources,
      retention: params.monitoring_stack.retention,
      rules: {
        alert: {},
      },
      scrapeInterval: '30s',
      enforcedNamespaceLabel: 'namespace',
      excludedFromEnforcement: [
        {
          namespace: params.monitoring_stack.namespace,
          resource: 'servicemonitors',
        },
      ],
      // TODO(bastjan)
      // We probably want to enforce empty selectors for instance namespaces.
      // We need it to allow kubelet monitoring without having to add a label to the kube-system namespace.
      ignoreNamespaceSelectors: false,
      podMonitorNamespaceSelector: nsSelector,
      probeNamespaceSelector: nsSelector,
      ruleNamespaceSelector: nsSelector,
      scrapeConfigNamespaceSelector: nsSelector,
      serviceMonitorNamespaceSelector: nsSelector,
      serviceMonitorSelector: {},
      podMonitorSelector: {},
      ruleSelector: {},
      shards: 1,
      storage: {
        volumeClaimTemplate: {
          metadata: {},
          spec: {
            resources: {
              requests: {
                storage: '10Gi',
              },
            },
          },
          status: {},
        },
      },
      image: '%s/%s:%s' % [
        params.images.prometheus.registry,
        params.images.prometheus.repository,
        params.images.prometheus.tag,
      ],
      version: trimPrefix(params.images.prometheus.tag, 'v'),
      web: {
        httpConfig: {
          headers: {
            contentSecurityPolicy: "frame-ancestors 'none'",
          },
        },
      },
    },
  } + platformSpecificConfig,
]
