local kube = import 'kube-ssa-compat.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.helmetica_framework;

if params.monitoring_stack.enabled then
  {
    '00_namespace': kube.Namespace(params.monitoring_stack.namespace) {
      metadata+: com.makeMergeable(params.monitoring_stack.namespaceMetadata),
    },
    '05_operator': import './prometheus/operator.jsonnet',
    '15_stack': import './prometheus/stack.jsonnet',
    '25_kubernetes': import './prometheus/kubernetes.jsonnet',
  }
else
  {}
