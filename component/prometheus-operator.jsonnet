local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.helmetica_framework;

local operator =
  std.parseJson(kap.yaml_load_stream(inv.parameters._base_directory + '/dependencies/helmetica-framework/manifests/prometheus-operator/%s/bundle/bundle.yaml' % params.monitoring_stack.version));

{
  operator: std.filter(
    function(obj) obj != null && obj.kind != 'CustomResourceDefinition',
    operator
  ),
}
