// main template for helmetica-framework
local kube = import 'kube-ssa-compat.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
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

local chrysopoeiaCRDs = com.Kustomization(
  params.chrysopoeia_crds.kustomize.manifest,
  params.chrysopoeia_crds.kustomize.version,
  {
  },
  {} + com.makeMergeable(params.chrysopoeia_crds.kustomize.input),
);

local chrysopoeiaController = com.Kustomization(
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
          // The harness proxy runs in the component's namespace, not in the upstream
          // chrysopoeia-proxy-system the flags default to.
          {
            op: 'add',
            path: '/spec/template/spec/containers/0/args/-',
            value: '--harness-proxy-host=chrysopoeia-proxy.%s.svc' % params.namespace,
          },
          {
            op: 'add',
            path: '/spec/template/spec/containers/0/args/-',
            value: '--harness-proxy-ca-secret-namespace=%s' % params.namespace,
          },
        ]),
      },
      {
        target: {
          group: 'cert-manager.io',
          version: 'v1',
          kind: 'Certificate',
          name: 'chrysopoeia-metrics-certs',
        },
        patch: std.manifestJson([
          {
            op: 'replace',
            path: '/spec/dnsNames',
            value: [
              'chrysopoeia-controller-manager-metrics-service.%s.svc' % params.namespace,
              'chrysopoeia-controller-manager-metrics-service.%s.svc.cluster.local' % params.namespace,
            ],
          },
        ]),
      },
      {
        // Serves the pod mutating webhook of the OperatorHarness proxy injection.
        target: {
          group: 'cert-manager.io',
          version: 'v1',
          kind: 'Certificate',
          name: 'chrysopoeia-serving-cert',
        },
        patch: std.manifestJson([
          {
            op: 'replace',
            path: '/spec/dnsNames',
            value: [
              'chrysopoeia-webhook-service.%s.svc' % params.namespace,
              'chrysopoeia-webhook-service.%s.svc.cluster.local' % params.namespace,
            ],
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
    patches: [
      {
        target: {
          group: 'cert-manager.io',
          version: 'v1',
          kind: 'Certificate',
          name: 'chrysopoeia-proxy-serving-cert',
        },
        patch: std.manifestJson([
          {
            op: 'replace',
            path: '/spec/dnsNames',
            value: [
              'chrysopoeia-proxy.%s.svc' % params.namespace,
              'chrysopoeia-proxy.%s.svc.cluster.local' % params.namespace,
            ],
          },
        ]),
      },
    ],
  } + com.makeMergeable(params.chrysopoeia_proxy.kustomize.input),
);

local custosCRDs = com.Kustomization(
  params.custos_crds.kustomize.manifest,
  params.custos_crds.kustomize.version,
  {
  },
  {} + com.makeMergeable(params.custos_crds.kustomize.input),
);

local custosController = com.Kustomization(
  params.custos_controller.kustomize.manifest,
  params.custos_controller.kustomize.version,
  {
    'ghcr.io/helmetica-framework/custos': {
      newTag: params.images.custos.tag,
      newName: '%(registry)s/%(repository)s' % params.images.custos,
    },
  },
  {
    patchesStrategicMerge: [ removeUpstreamNamespace('system') ],
    patches: [],
  } + com.makeMergeable(params.custos_controller.kustomize.input),
);

local ampullaCRDs = com.Kustomization(
  params.ampulla_crds.kustomize.manifest,
  params.ampulla_crds.kustomize.version,
  {
  },
  {} + com.makeMergeable(params.ampulla_crds.kustomize.input),
);

local ampullaController = com.Kustomization(
  params.ampulla_controller.kustomize.manifest,
  params.ampulla_controller.kustomize.version,
  {
    'ghcr.io/helmetica-framework/ampulla': {
      newTag: params.images.ampulla.tag,
      newName: '%(registry)s/%(repository)s' % params.images.ampulla,
    },
  },
  {
    patchesStrategicMerge: [ removeUpstreamNamespace('system') ],
    patches: [
      {
        target: {
          group: 'cert-manager.io',
          version: 'v1',
          kind: 'Certificate',
          name: 'ampulla-metrics-certs',
        },
        patch: std.manifestJson([
          {
            op: 'replace',
            path: '/spec/dnsNames',
            value: [
              'ampulla-controller-manager-metrics-service.%s.svc' % params.namespace,
              'ampulla-controller-manager-metrics-service.%s.svc.cluster.local' % params.namespace,
            ],
          },
        ]),
      },
    ],
  } + com.makeMergeable(params.ampulla_controller.kustomize.input),
);

local adeptCRDs = com.Kustomization(
  params.adept_crds.kustomize.manifest,
  params.adept_crds.kustomize.version,
  {
  },
  {} + com.makeMergeable(params.adept_crds.kustomize.input),
);

local adeptController = com.Kustomization(
  params.adept_controller.kustomize.manifest,
  params.adept_controller.kustomize.version,
  {
    'ghcr.io/helmetica-framework/adept': {
      newTag: params.images.adept.tag,
      newName: '%(registry)s/%(repository)s' % params.images.adept,
    },
  },
  {
    patchesStrategicMerge: [ removeUpstreamNamespace('system') ],
    patches: [
      {
        target: {
          group: 'cert-manager.io',
          version: 'v1',
          kind: 'Certificate',
          name: 'adept-metrics-certs',
        },
        patch: std.manifestJson([
          {
            op: 'replace',
            path: '/spec/dnsNames',
            value: [
              'adept-controller-manager-metrics-service.%s.svc' % params.namespace,
              'adept-controller-manager-metrics-service.%s.svc.cluster.local' % params.namespace,
            ],
          },
        ]),
      },
      {
        // Serves the pod mutating webhook of the OperatorHarness proxy injection.
        target: {
          group: 'cert-manager.io',
          version: 'v1',
          kind: 'Certificate',
          name: 'adept-serving-cert',
        },
        patch: std.manifestJson([
          {
            op: 'replace',
            path: '/spec/dnsNames',
            value: [
              'adept-webhook-service.%s.svc' % params.namespace,
              'adept-webhook-service.%s.svc.cluster.local' % params.namespace,
            ],
          },
        ]),
      },
    ],
  } + com.makeMergeable(params.adept_controller.kustomize.input),
);

local sigillumCRDs = com.Kustomization(
  params.sigillum_crds.kustomize.manifest,
  params.sigillum_crds.kustomize.version,
  {
  },
  {} + com.makeMergeable(params.sigillum_crds.kustomize.input),
);

local sigillumController = com.Kustomization(
  params.sigillum_controller.kustomize.manifest,
  params.sigillum_controller.kustomize.version,
  {
    'ghcr.io/helmetica-framework/sigillum': {
      newTag: params.images.sigillum.tag,
      newName: '%(registry)s/%(repository)s' % params.images.sigillum,
    },
  },
  {
    patchesStrategicMerge: [ removeUpstreamNamespace('system') ],
    patches: [],
  } + com.makeMergeable(params.sigillum_controller.kustomize.input),
);

{
  '07_chrysopoeia_crds/kustomization': chrysopoeiaCRDs.kustomization,
  '17_flux/kustomization': flux.kustomization,
  '18_chrysopoeia_controller/kustomization': chrysopoeiaController.kustomization,
  '19_chrysopoeia_proxy/kustomization': proxy.kustomization,
  '51_custos_crds/kustomization': custosCRDs.kustomization,
  '52_custos_controller/kustomization': custosController.kustomization,
  '53_ampulla_crds/kustomization': ampullaCRDs.kustomization,
  '54_ampulla_controller/kustomization': ampullaController.kustomization,
  '55_adept_crds/kustomization': adeptCRDs.kustomization,
  '56_adept_controller/kustomization': adeptController.kustomization,
  '57_sigillum_crds/kustomization': sigillumCRDs.kustomization,
  '58_sigillum_controller/kustomization': sigillumController.kustomization,

  kustomization: {
    resources: [
      'https://raw.githubusercontent.com/helmetica-framework/chrysopoeia/%(version)s/config/proxy/permission-label-map-espejote.yaml' % {
        version: params.chrysopoeia_proxy.kustomize.version,
      },
      '07_chrysopoeia_crds',
      '17_flux',
      '18_chrysopoeia_controller',
      '19_chrysopoeia_proxy',
      '51_custos_crds',
      '52_custos_controller',
      '53_ampulla_crds',
      '54_ampulla_controller',
      '55_adept_crds',
      '56_adept_controller',
      '57_sigillum_crds',
      '58_sigillum_controller',
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
