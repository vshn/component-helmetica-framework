local kube = import 'kube-ssa-compat.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.helmetica_framework;

local services = com.getValueOrDefault(params, 'services', {});

local syncWave(wave) = {
  metadata+: {
    annotations+: {
      'argocd.argoproj.io/sync-wave': std.toString(wave),
    },
  },
};

// Claim CRDs are created by chrysopoeia from the ClaimDefinitions at runtime.
local skipDryRun = {
  metadata+: {
    annotations+: {
      'argocd.argoproj.io/sync-options': 'SkipDryRunOnMissingResource=true',
    },
  },
};

local imageRepository(name, svc) =
  kube._Object('image.toolkit.fluxcd.io/v1', 'ImageRepository', name) + syncWave(1) {
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
  kube._Object('source.toolkit.fluxcd.io/v1', 'OCIRepository', '%s-%s' % [ name, version ]) + syncWave(1) {
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

local crdNames(name, svc, version) =
  if std.objectHas(svc, 'crdNames') then
    error "service '%s': crdNames must be set per version, not on the service" % name
  else if !std.objectHas(svc.versions[version], 'crdNames') then
    error "service '%s': version '%s' has no crdNames" % [ name, version ]
  else
    svc.versions[version].crdNames;

local crdNameValues(names) =
  [
    names[f]
    for f in [ 'kind', 'plural', 'singular', 'listKind' ]
    if std.objectHas(names, f)
  ] + com.getValueOrDefault(names, 'shortNames', []);

local checkCrdNames(name, versions) =
  local used = std.flattenArrays([
    [ { value: v, version: version } for v in crdNameValues(names) ]
    for version in std.objectFields(versions)
    for names in [ versions[version] ]
  ]);
  local clashes = [
    value
    for value in std.set([ u.value for u in used ])
    if std.length([ u for u in used if u.value == value ]) > 1
  ];
  if std.length(clashes) > 0 then
    error "service '%s': crdNames clash between versions: %s" % [
      name,
      std.join(', ', [
        '%s (%s)' % [ c, std.join(', ', [ u.version for u in used if u.value == c ]) ]
        for c in clashes
      ]),
    ]
  else
    true;

local claimDefinition(name, svc, version) =
  kube._Object('chrysopoeia.helmetica.io/v1', 'ClaimDefinition', '%s.%s' % [ version, name ]) + syncWave(2) {
    metadata+: { namespace: params.namespace },
    spec: {
      crdNames: crdNames(name, svc, version),
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
  kube._Object('chrysopoeia.helmetica.io/v1', 'DependencyGroup', name) + syncWave(1);

local claim(name) = syncWave(3) + skipDryRun + {
  metadata+: {
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
  assert checkCrdNames(name, { [v]: crdNames(name, svc, v) for v in versions });
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
