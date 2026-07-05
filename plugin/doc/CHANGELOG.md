# Changelog

## 0.1.0

First release. Carries a `tun.ko` cross-built against the Snapmaker U1's exact kernel (Linux 6.1.99
aarch64, `vermagic 6.1.99 SMP preempt mod_unload aarch64`) and loads it at boot, giving the printer a
working `/dev/net/tun`. This is the base the ZeroTier and Tailscale plugins build their mesh network
on. Loads before the services that need it (`s05` before `s65`); unloads cleanly on uninstall; a
failed load deactivates the plugin so the printer is never left broken.
