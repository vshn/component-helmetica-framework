local alembic = import 'alembic/lib/alembic.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local params = kap.inventory().parameters.helmetica_framework;

alembic.monitoring(params)
