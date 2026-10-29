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

local libraBucket = params.libra_controller.bucket;

local libraBucketClaim = {
  apiVersion: 'objectstorage.k8s.io/v1alpha2',
  kind: 'BucketClaim',
  metadata: {
    name: libraBucket.name,
    namespace: params.namespace,
  },
  spec: {
    bucketClassName: libraBucket.bucketClassName,
    protocols: [ 'S3' ],
  },
};

local libraBucketAccess = {
  apiVersion: 'objectstorage.k8s.io/v1alpha2',
  kind: 'BucketAccess',
  metadata: {
    name: libraBucket.name,
    namespace: params.namespace,
  },
  spec: {
    bucketAccessClassName: libraBucket.bucketAccessClassName,
    protocol: 'S3',
    bucketClaims: [
      {
        bucketClaimName: libraBucket.name,
        accessMode: 'ReadWrite',
        accessSecretName: libraBucket.name,
      },
    ],
  },
};

local platformCluster = kube.ConfigMap('platform-cluster') {
  metadata+: {
    namespace: params.namespace,
    annotations: {
      'chrysopoeia.io/platform-values': '0',
    },
  },
  data: {
    'values.json': std.manifestJson({
      'io.vshn.cluster/v1alpha1': {
        name: inv.parameters.cluster.name,
      },
    }),
  },
};

{
  '10_secrets': com.generateResources(params.secrets, function(name) kube.Secret(name) {
    metadata+: { namespace: params.namespace },
  }),
  '11_secrets_monitoring': com.generateResources(params.monitoring_stack.secrets, function(name) kube.Secret(name) {
    metadata+: { namespace: params.monitoring_stack.namespace },
  }),
  '12_monitoring_clusterrole': monitoringCR,
  '13_libra_bucket': [ libraBucketClaim, libraBucketAccess ],
  '14_platform_cluster': platformCluster,
}
