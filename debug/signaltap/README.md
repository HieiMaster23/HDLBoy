# SignalTap Debug Area

SignalTap II files are local debug artifacts for hardware bring-up. Keep active
captures and temporary `.stp` files out of the main Quartus project flow and out
of version control.

Current convention:

- Put local SignalTap files under `debug/signaltap/local/`.
- Document useful probe groups in Markdown under `docs/`.
- Remove SignalTap instrumentation from the synthesis flow before tagging a
  milestone release.

The M3 CPU probe notes live in `docs/m3_signaltap_debug.md`.
