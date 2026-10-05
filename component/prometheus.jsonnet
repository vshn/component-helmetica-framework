local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.helmetica_framework;

if params.monitoring_stack.enabled then
  {
    '05_operator': import './prometheus/operator.jsonnet',
    '15_stack': import './prometheus/stack.jsonnet',
    '25_kubelet': import './prometheus/kubenetes-metrics/openshift/kubelet.jsonnet',
  }
else
  {}
