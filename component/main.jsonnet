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

// The driver reads its cloudscale.ch API token from this secret, see
// config/manager/deployment.yaml in aludel-cloudscale.
local aludelCredentials = kube.Secret('aludel-cloudscale-credentials') {
  metadata+: { namespace: params.namespace },
  stringData: {
    token: params.aludel_cloudscale.api_token,
  },
};

local bucketClasses = com.generateResources(
  params.aludel_cloudscale.bucket_classes,
  function(name) {
    apiVersion: 'objectstorage.k8s.io/v1alpha2',
    kind: 'BucketClass',
    metadata: {
      name: name,
      annotations: {
        // The COSI CRDs are synced by this same app.
        'argocd.argoproj.io/sync-options': 'SkipDryRunOnMissingResource=true',
      },
    },
    spec: {
      driverName: params.aludel_cloudscale.driver_name,
      deletionPolicy: 'Retain',
    },
  }
);

local bucketAccessClasses = com.generateResources(
  params.aludel_cloudscale.bucket_access_classes,
  function(name) {
    apiVersion: 'objectstorage.k8s.io/v1alpha2',
    kind: 'BucketAccessClass',
    metadata: {
      name: name,
      annotations: {
        // The COSI CRDs are synced by this same app.
        'argocd.argoproj.io/sync-options': 'SkipDryRunOnMissingResource=true',
      },
    },
    spec: {
      driverName: params.aludel_cloudscale.driver_name,
      // cloudscale.ch has no IAM, so Key is the only type the driver accepts.
      authenticationType: 'Key',
    },
  }
);

{
  '10_secrets': com.generateResources(params.secrets, function(name) kube.Secret(name) {
    metadata+: { namespace: params.namespace },
  }),
  '11_secrets_monitoring': com.generateResources(params.monitoring_stack.secrets, function(name) kube.Secret(name) {
    metadata+: { namespace: params.monitoring_stack.namespace },
  }),
  '12_monitoring_clusterrole': monitoringCR,
  [if params.aludel_cloudscale.deployed then '13_aludel_cloudscale_credentials']: aludelCredentials,
  [if params.aludel_cloudscale.deployed then '14_aludel_cloudscale_classes']: bucketClasses + bucketAccessClasses,
}
