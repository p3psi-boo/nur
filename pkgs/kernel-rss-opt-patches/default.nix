{ lib }:

# Linux kernel patches for RSS stat initialization/teardown optimization
# Author: Gabriel Krisman Bertazi <krisman@suse.de>
# Source: https://lore.kernel.org/lkml/20251127233635.4170047-1-krisman@suse.de/
#
# This patch series optimizes RSS (Resident Set Size) statistics initialization
# for single-threaded tasks by implementing a dual-mode counter mechanism:
# - Starts as a simple counter for single-threaded tasks
# - Upgrades to per-CPU counter when memory becomes shared (multi-threaded)
#
# Performance improvements (256-core system):
# - 11% system time reduction for fork-intensive workloads
# - 1.4% improvement in kernbench
# - 3.12% improvement in gitsource
#
# Use these patches with boot.kernelPatches in your NixOS configuration

{
  # Patch 1: Extract CPU hotplug watchlist helper
  percpu-counter-helper = {
    name = "lib-percpu_counter-helper";
    patch = ./patches/0001-lib-percpu_counter-helper.patch;
  };

  # Patch 2: Implement lazy per-CPU counter infrastructure
  lazy-percpu-counter = {
    name = "lazy-percpu-counter";
    patch = ./patches/0002-lazy-percpu-counter.patch;
  };

  # Patch 3: Apply lazy counters to MM RSS stats
  mm-counter-optimization = {
    name = "mm-counter-optimization";
    patch = ./patches/0003-mm-counter-optimization.patch;
  };

  # Patch 4: Split local/remote counter update paths
  mm-split-slow-path = {
    name = "mm-split-slow-path";
    patch = ./patches/0004-mm-split-slow-path.patch;
  };

  # Convenience: All patches as a list
  all = [
    {
      name = "lib-percpu_counter-helper";
      patch = ./patches/0001-lib-percpu_counter-helper.patch;
    }
    {
      name = "lazy-percpu-counter";
      patch = ./patches/0002-lazy-percpu-counter.patch;
    }
    {
      name = "mm-counter-optimization";
      patch = ./patches/0003-mm-counter-optimization.patch;
    }
    {
      name = "mm-split-slow-path";
      patch = ./patches/0004-mm-split-slow-path.patch;
    }
  ];

  # Metadata
  meta = {
    description = "Kernel patches for RSS stat lazy initialization optimization";
    homepage = "https://lore.kernel.org/lkml/20251127233635.4170047-1-krisman@suse.de/";
    author = "Gabriel Krisman Bertazi";
    license = lib.licenses.gpl2Only;

    # These patches are RFC (Request for Comments) for mainline kernel
    # They may need adjustments for specific kernel versions
    longDescription = ''
      This patch series optimizes per-CPU RSS stat initialization for
      single-threaded tasks. It introduces a dual-mode counter that starts
      as a simple counter and upgrades to a full per-CPU counter when the
      memory management structure becomes shared (e.g., when creating threads).

      On a 256-core system, this shows:
      - 6-15% wall-clock time improvement in fork-intensive benchmarks
      - 1.5% improvement in kernbench elapsed time
      - Addresses a 10% system time regression from per-CPU counter introduction

      Note: These are RFC patches targeting mainline kernel. Compatibility
      with custom kernels (like CachyOS) should be tested before deployment.
    '';
  };
}
