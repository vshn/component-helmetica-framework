local kube = import 'kube-ssa-compat.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local prom = import 'common.libsonnet';
// The hiera parameters for the component
local params = inv.parameters.helmetica_framework;

if prom.platform == prom.PlatformOpenShift4 then
  import './kubenetes-metrics/openshift/kubelet.jsonnet'
else
  []
