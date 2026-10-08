local kube = import 'kube-ssa-compat.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local prom = import 'common.libsonnet';
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

local platformSpecificConfig =
  if prom.platform == prom.PlatformTalos then
    {
      spec+: {
        securityContext+: {
          fsGroup: 2000,
          runAsNonRoot: true,
          runAsUser: 1000,
        },
      },
    }
  else if prom.platform == prom.PlatformOpenShift4 then
    {}
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
      name: 'alertmanager',
      namespace: params.monitoring_stack.namespace,
    },
  },
  {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'alertmanager',
      namespace: params.monitoring_stack.namespace,
    },
    spec: {
      ports: [
        {
          name: 'web',
          port: 9093,
          targetPort: 'web',
        },
        {
          name: 'reloader-web',
          port: 8080,
          targetPort: 'reloader-web',
        },
      ],
      selector: {
        'helmetica-monitoring-component': 'alertmanager',
      },
      sessionAffinity: 'ClientIP',
    },
  },
  {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'Alertmanager',
    metadata: {
      name: 'alertmanager',
      namespace: params.monitoring_stack.namespace,
      annotations: {
        'operator.prometheus.io/controller-id': '%s/prometheus-operator' % params.monitoring_stack.namespace,
      },
    },
    spec: {
      podMetadata: {
        labels: {
          'helmetica-monitoring-component': 'alertmanager',
        },
      },
      alertmanagerConfigNamespaceSelector: nsSelector,
      alertmanagerConfigSelector: {},
      image: '%s/%s:%s' % [
        params.images.alertmanager.registry,
        params.images.alertmanager.repository,
        params.images.alertmanager.tag,
      ],
      version: trimPrefix(params.images.alertmanager.tag, 'v'),
      portName: 'web',
      secrets: [],
      serviceAccountName: 'alertmanager',
      resources: params.monitoring_stack.alertmanager.resources,
      retention: params.monitoring_stack.alertmanager.retention,
      replicas: params.monitoring_stack.alertmanager.replicas,
    },
  } + platformSpecificConfig,
]
