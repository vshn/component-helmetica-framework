local alembic = import 'alembic/lib/alembic.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local params = kap.inventory().parameters.helmetica_framework;

// The driver creates the bucket classes, so its values are the fallback. An
// explicit ampulla value wins.
local ampullaDefault(key) =
  local value = std.get(params.ampulla, key, null);
  if value != null then value
  else if params.aludel_cloudscale.deployed then std.get(params.aludel_cloudscale, key, null)
  else null;

alembic.framework(params {
  createNamespace: false,
  libra: params.libra {
    bucketSecretName: params.libra.bucket.name,
  },
  cosi: {
    enabled: params.aludel_cloudscale.deployed,
  },
  aludel_cloudscale: {
    enabled: params.aludel_cloudscale.deployed,
  },
  ampulla+: {
    default_bucket_class: ampullaDefault('default_bucket_class'),
    default_bucket_access_class: ampullaDefault('default_bucket_access_class'),
  },
})
