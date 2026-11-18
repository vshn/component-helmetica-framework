local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.helmetica_framework;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('helmetica-framework', params.namespace) + {
  metadata+: {
    annotations+: {
      'argocd.argoproj.io/compare-options': 'ServerSideDiff=true',
    },
  },
  spec+: {
    syncPolicy+: {
      [if std.length(params.namespaceMetadata) != 0 then 'managedNamespaceMetadata']+: params.namespaceMetadata,
      retry: {
        limit: 5,
        backoff: {
          duration: '10s',
          factor: 2,
          maxDuration: '3m',
        },
      },
      syncOptions+: [
        'ServerSideApply=true',
        'CreateNamespace=true',
      ],
    },
  },
};

local appPath =
  local project = std.get(std.get(app, 'spec', {}), 'project', 'syn');
  if project == 'syn' then 'apps' else 'apps-%s' % project;

{
  ['%s/helmetica-framework' % appPath]: app,
}
