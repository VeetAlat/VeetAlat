# Sailvisor

Virtual machines on Sailfish OS, using the MediaTek **GenieZone** hypervisor (`/dev/gzvm`) found on the
2026 Jolla Phone (Dimensity 7100). There is no KVM on that phone, so Sailvisor bundles
[crosvm](https://github.com/google/crosvm), which has a GenieZone backend.

**Status: 0.1.0, first test build.** GenieZone VM creation is confirmed on a Jolla Phone. Booting a
guest has not been tried there yet; that is what the self-test is for.

## Install

Copy `sailvisor-0.1.0-1.aarch64.rpm` to the phone, then in the Terminal (developer mode):

```bash
devel-su pkcon install-local ~/Downloads/sailvisor-0.1.0-1.aarch64.rpm
# if the RPM was downloaded by an Android app (e.g. the Claude app), it is in ~/android_storage/Download/
```

If pkcon cannot resolve a dependency, install PyOtherSide yourself and skip the dependency check:

```bash
devel-su pkcon install pyotherside-qml-plugin-python3-qt5
devel-su rpm -ivh --nodeps sailvisor-0.1.0-1.aarch64.rpm
```

## First run: does a VM boot?

No root is needed: `/dev/gzvm` is world-writable on the Jolla Phone.

```bash
sailvisor-cli doctor              # device, CPU, GenieZone, crosvm, test guest
sailvisor-cli -v selftest         # boots the bundled guest, prints a banner, powers off
```

A passing self-test shows `Hello from inside GenieZone on a Jolla!` and `SELF-TEST PASSED`.
The same is available in the app under **Diagnostics → Run boot self-test**.

If it fails, run `sailvisor-cli report` and send the file it prints (`~/Documents/Sailvisor/...`).

## Using it

App: pull down for *New test VM*, *New VM*, *Import ISO* and *Diagnostics*. Tap a VM for start / stop /
force kill, a live console (with input), VM logs and runtime details.

CLI:

```bash
sailvisor-cli create-test --mode heartbeat    # or: shell, poweroff
sailvisor-cli start test-guest -f             # start and follow the console (Ctrl+C detaches)
sailvisor-cli send test-guest uname -a        # type into the guest console (mode=shell)
sailvisor-cli stop test-guest                 # graceful: crosvm stop, then SIGTERM, then SIGKILL
sailvisor-cli kill test-guest
sailvisor-cli log test-guest -f               # crosvm + supervisor log
sailvisor-cli set test-guest log_level=debug memory_mb=512
sailvisor-cli run test-guest                  # crosvm in the foreground on this terminal (raw debugging)
sailvisor-cli show test-guest                 # config, state and the exact crosvm command
sailvisor-cli probe                           # low-level GenieZone ioctl probe
sailvisor-cli import-iso ~/Downloads/alpine-virt-3.22-aarch64.iso   # experimental
```

## Where things are

| What | Where |
|---|---|
| VM definitions and logs | `~/.local/share/sailvisor/vms/<id>/` (`vm.json`, `state.json`, `vm.log`, `console.log`, previous runs as `*.1`) |
| App log | `~/.local/share/sailvisor/logs/sailvisor.log` (`SAILVISOR_DEBUG=1` for debug level) |
| Debug reports | `~/Documents/Sailvisor/` |
| crosvm | `/usr/libexec/sailvisor/crosvm` (static aarch64, GenieZone backend) |
| Test guest | `/usr/share/sailvisor/guest/` (Ubuntu 6.8 arm64 kernel + busybox initramfs) |

## How it works

```
QML (Silica) ──PyOtherSide──> sailvisor.bridge ─┐
sailvisor-cli ──────────────────────────────────┼─> control.start() ─> supervisor (detached, one per VM)
                                                │                         ├─ runs crosvm --hypervisor geniezone
                                                │                         ├─ console.sock  <- guest serial (crosvm connects)
                                                │                         ├─ console.in    -> guest serial (FIFO)
                                                │                         └─ state.json / vm.log / console.log
```

- VMs keep running when the app is closed. The supervisor records exit codes and reasons
  (crosvm `--extended-status`: reset, crash, guest panic, watchdog...).
- crosvm boots kernels directly, without UEFI. "Booting an ISO" therefore means extracting the
  kernel and initrd from it (Ubuntu, Debian live, Alpine, Fedora live, generic) and attaching the
  ISO as a read-only disk.
- crosvm's GenieZone backend is single-vCPU for now (multi-core is on its backlog).

## Building

On Ubuntu 24.04 x86_64:

```bash
./build-rpm.sh                     # builds crosvm, the test guest and the RPM into ./build
tests/test_backend.sh              # backend lifecycle tests with a fake crosvm
tests/ui/run_ui_test.sh            # real QML + Python bridge against stub Silica components
```

Bundled third-party components: crosvm and minijail (BSD-3-Clause), Linux kernel and busybox from
Ubuntu (GPL-2.0).
