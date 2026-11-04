local kube = import 'kube-ssa-compat.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.helmetica_framework;

local services = com.getValueOrDefault(params, 'services', {});

local imageRepository(name, svc) =
  kube._Object('image.toolkit.fluxcd.io/v1', 'ImageRepository', name) {
    metadata+: { namespace: params.namespace },
    spec: {
      image: svc.registry,
      interval: '1h',
      provider: 'generic',
      exclusionList: [
        '^.*\\.sig$',
        '^sha256-.+$',
      ],
    },
  };

local ociRepository(name, svc, version) =
  kube._Object('source.toolkit.fluxcd.io/v1', 'OCIRepository', '%s-%s' % [ name, version ]) {
    metadata+: { namespace: params.namespace },
    spec: {
      url: 'oci://%s' % svc.registry,
      interval: '1h',
      provider: 'generic',
      ref: {
        semver: svc.versions[version].semver,
      },
    },
  };

local claimDefinition(name, svc, version) =
  kube._Object('chrysopoeia.helmetica.io/v1', 'ClaimDefinition', '%s.%s' % [ version, name ]) {
    metadata+: { namespace: params.namespace },
    spec: {
      crdNames: svc.crdNames,
      reference: {
        apiVersion: 'source.toolkit.fluxcd.io/v1',
        kind: 'OCIRepository',
        name: '%s-%s' % [ name, version ],
      },
      versionDiscovery: {
        reference: {
          apiVersion: 'image.toolkit.fluxcd.io/v1',
          kind: 'ImageRepository',
          name: name,
        },
      },
    } + {
      [field]: [
        { dependencyGroup: { name: group } }
        for group in svc[field]
      ]
      for field in [ 'provides', 'manages', 'requires' ]
      if std.length(com.getValueOrDefault(svc, field, [])) > 0
    },
  };

local dependencyGroup(name) =
  kube._Object('chrysopoeia.helmetica.io/v1', 'DependencyGroup', name);

local claim(name) = {
  metadata: {
    name: name,
    namespace: params.namespace,
  },
};

local serviceObjects(name, svc) =
  local versions = [
    v
    for v in std.objectFields(svc.versions)
    if svc.versions[v] != null
  ];
  [ imageRepository(name, svc) ] +
  [ ociRepository(name, svc, v) for v in versions ] +
  [ claimDefinition(name, svc, v) for v in versions ];

{
  '10_services': std.flattenArrays([
    serviceObjects(name, services[name])
    for name in std.objectFields(services)
    if services[name] != null
  ]),
  '11_dependency_groups': com.generateResources(
    com.getValueOrDefault(params, 'dependency_groups', {}),
    dependencyGroup,
  ),
  '20_claims': com.generateResources(
    com.getValueOrDefault(params, 'claims', {}),
    claim,
  ),
}
