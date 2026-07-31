local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.helmetica_framework;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('helmetica-framework', params.namespace) + std.prune({
  spec+: {
    syncPolicy+: {
      managedNamespaceMetadata+: params.namespaceMetadata,
      syncOptions+: [
        'ServerSideApply=true',
        'CreateNamespace=true',
      ],
    },
  },
});

local appPath =
  local project = std.get(std.get(app, 'spec', {}), 'project', 'syn');
  if project == 'syn' then 'apps' else 'apps-%s' % project;

{
  ['%s/helmetica-framework' % appPath]: app,
}
