local kube = import 'kube-ssa-compat.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.helmetica_framework;

local PlatformOpenShift4 = 'openshift4';
local PlatformTalos = 'talos';

local platform =
  local allowedPlatforms = [ PlatformTalos, PlatformOpenShift4 ];
  assert std.contains(allowedPlatforms, params.monitoring_stack.platform) : "Invalid platform '%s' specified for monitoring_stack. Allowed values: %s" % [ params.monitoring_stack.platform, std.join(', ', allowedPlatforms) ];
  params.monitoring_stack.platform;

{
  PlatformOpenShift4: PlatformOpenShift4,
  PlatformTalos: PlatformTalos,

  // The platform the monitoring stack is running on.
  platform: platform,
}
