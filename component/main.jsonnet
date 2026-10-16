// main template for helmetica-framework
local kube = import 'kube-ssa-compat.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.helmetica_framework;

local monitoringCR = {
  apiVersion: 'rbac.authorization.k8s.io/v1',
  kind: 'ClusterRole',
  metadata: {
    name: 'helmetica:monitoring-edit',
    labels: {
      'rbac.authorization.k8s.io/aggregate-to-admin': 'true',
    },
  },
  rules: [
    {
      apiGroups: [
        'monitoring.coreos.com',
      ],
      resources: [
        'alertmanagerconfigs',
        'servicemonitors',
        'podmonitors',
        'prometheusrules',
      ],
      verbs: [
        '*',
      ],
    },
  ],
};

{
  '10_secrets': com.generateResources(params.secrets, function(name) kube.Secret(name) {
    metadata+: { namespace: params.namespace },
  }),
  '11_secrets_monitoring': com.generateResources(params.monitoring_stack.secrets, function(name) kube.Secret(name) {
    metadata+: { namespace: params.monitoring_stack.namespace },
  }),
  '12_monitoring_clusterrole': monitoringCR,
}
