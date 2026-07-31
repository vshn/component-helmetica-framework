// main template for helmetica-framework
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.helmetica_framework;

local removeUpstreamNamespace(name) = std.manifestJson({
  '$patch': 'delete',
  apiVersion: 'v1',
  kind: 'Namespace',
  metadata: {
    name: name,
  },
});

local flux = com.Kustomization(
  params.flux.kustomize.manifest,
  params.flux.kustomize.version,
  {
    'ghcr.io/fluxcd/source-controller': {
      newTag: params.images['flux-source-controller'].tag,
      newName: '%(registry)s/%(repository)s' % params.images['flux-source-controller'],
    },
    'ghcr.io/fluxcd/image-reflector-controller': {
      newTag: params.images['flux-image-reflector-controller'].tag,
      newName: '%(registry)s/%(repository)s' % params.images['flux-image-reflector-controller'],
    },
    'ghcr.io/fluxcd/helm-controller': {
      newTag: params.images['flux-helm-controller'].tag,
      newName: '%(registry)s/%(repository)s' % params.images['flux-helm-controller'],
    },
  },
  {
    patchesStrategicMerge: [ removeUpstreamNamespace('chrysopoeia-flux-system') ],
  } + com.makeMergeable(params.flux.kustomize.input),
);

local crds = com.Kustomization(
  params.chrysopoeia_crds.kustomize.manifest,
  params.chrysopoeia_crds.kustomize.version,
  {
  },
  {} + com.makeMergeable(params.chrysopoeia_crds.kustomize.input),
);

local controller = com.Kustomization(
  params.chrysopoeia_controller.kustomize.manifest,
  params.chrysopoeia_controller.kustomize.version,
  {
    'ghcr.io/helmetica-framework/chrysopoeia': {
      newTag: params.images.chrysopoeia.tag,
      newName: '%(registry)s/%(repository)s' % params.images.chrysopoeia,
    },
  },
  {
    patchesStrategicMerge: [ removeUpstreamNamespace('system') ],
    patches: [
      {
        target: {
          kind: 'Deployment',
        },
        patch: std.manifestJson([
          {
            op: 'test',
            path: '/spec/template/spec/containers/0/name',
            value: 'manager',
          },
          {
            op: 'add',
            path: '/spec/template/spec/containers/0/args/-',
            value: '--image-reflector-controller-hostname=image-reflector-controller-tags:8090',
          },
        ]),
      },
    ],
  } + com.makeMergeable(params.chrysopoeia_controller.kustomize.input),
);

local proxy = com.Kustomization(
  params.chrysopoeia_proxy.kustomize.manifest,
  params.chrysopoeia_proxy.kustomize.version,
  {
    'ghcr.io/helmetica-framework/chrysopoeia': {
      newTag: params.images.chrysopoeia.tag,
      newName: '%(registry)s/%(repository)s' % params.images.chrysopoeia,
    },
  },
  {
    patchesStrategicMerge: [
      removeUpstreamNamespace('proxy-system'),
      std.manifestJson({
        '$patch': 'delete',
        apiVersion: 'cert-manager.io/v1',
        kind: 'Issuer',
        metadata: {
          name: 'chrysopoeia-selfsigned-issuer',
          namespace: 'chrysopoeia-proxy-system',
        },
      }),
    ],
  } + com.makeMergeable(params.chrysopoeia_proxy.kustomize.input),
);


{
  '07_chrysopoeia_crds/kustomization': crds.kustomization,
  '17_flux/kustomization': flux.kustomization,
  '18_chrysopoeia_controller/kustomization': controller.kustomization,
  '19_chrysopoeia_proxy/kustomization': proxy.kustomization,
  kustomization: {
    resources: [
      '07_chrysopoeia_crds',
      '17_flux',
      '18_chrysopoeia_controller',
      '19_chrysopoeia_proxy',
    ],
    patches: [
      {
        target: {
          kind: 'MutatingAdmissionPolicy',
        },
        patch: std.manifestJson({
          '$patch': 'delete',
          apiVersion: 'admissionregistration.k8s.io/v1',
          kind: 'MutatingAdmissionPolicy',
          metadata: {
            name: 'chrysopoeia-instances-namespaced-requires-labels',
            namespace: 'syn-helmetica-framework',
          },
        }),
      },
      {
        target: {
          kind: 'MutatingAdmissionPolicyBinding',
        },
        patch: std.manifestJson({
          '$patch': 'delete',
          apiVersion: 'admissionregistration.k8s.io/v1',
          kind: 'MutatingAdmissionPolicyBinding',
          metadata: {
            name: 'chrysopoeia-instances-namespaced-requires-labels',
            namespace: 'syn-helmetica-framework',
          },
        }),
      },
    ],
  },
}
