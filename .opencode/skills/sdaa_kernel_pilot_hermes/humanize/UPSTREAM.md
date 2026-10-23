# Humanize upstream relationship

The Humanize runtime is vendored from PolyArch Humanize. KernelPilot-specific
patches add the Hermes kernel loop, strict-success startup, the native teco-ops
test skill, and exclusive `teco-ops-wiki` installation.

When updating the vendored runtime, preserve these KernelPilot additions and run
the complete test suite.
