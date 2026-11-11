---
title: The build sandbox
description: How otok isolates the builds of libraries on macOS, Linux and Windows, and why on Windows it injects a DLL of its own into the processes of a build.
sidebar:
  order: 2
---

Building a library runs code you did not write: configure scripts, CMake files, code generators, compilers' plugins.
otok runs each build of a library in a sandbox, so that this code cannot reach anything but the build:

- **no network:** everything a build needs is downloaded before it starts and checked against its hash, so a build can
  neither fetch anything else nor send anything away;
- **no access to your files:** a build reads its source, its recipe, the toolchain and the libraries it depends on, and
  writes only into its own work directory.

The sandbox needs no administrator rights. Each system has its own mechanism:

| System | Mechanism |
| --- | --- |
| macOS | Seatbelt (`sandbox-exec`), the sandbox of macOS itself, with a profile otok writes for each build |
| Linux | [bubblewrap](https://github.com/containers/bubblewrap) (`bwrap`): the system read-only, a private home, no network |
| Windows | an AppContainer, the sandbox of Windows, with `otok-sandbox.dll` in every process of the build |

Where the sandbox cannot be made, otok does not build unisolated on its own: it stops and says why. `--no-sandbox` (or
`sandbox = false` in [`config.toml`](/reference/config/)) builds without it when you ask, with a warning at every
build.

The rest of this page is about Windows, where the sandbox needs more explaining.

## Windows: an AppContainer

An AppContainer is the isolation Windows gives to Store apps: a process in one has its own identity, and the kernel
lets it open only what is granted to that identity. otok makes one container for your account with Windows' own API,
`otok.build`, with no capabilities: no network, not even the loopback. It grants the container access to
exactly two places, both in otok's cache: read access to the cache (sources, toolchains built by recipes, the
libraries a build depends on) and full access to the work directory of the build. Everything else the container may
read is what Windows itself opens to all containers, such as `C:\Windows`, `Program Files` and the Windows SDK. Your
profile, your projects and your other drives stay closed to it.

These are entries in the access lists of otok's own directories, and of `otok.exe` and `otok-sandbox.dll`, which the
container must be able to load. otok writes no others: it never changes the permissions of your files, of your
toolchains or of the system. (One exception, rare: when the path of `otok-sandbox.dll` cannot be written in the
system's code page, as with a user name in another script, otok puts a copy of the DLL in
`%ProgramData%\otok\<version>\`, a directory of its own.)

The other ways to isolate a process on Windows did not do the job:

- a separate user account and a firewall rule, Windows Sandbox or a Hyper-V container all need an administrator to set
  up, and some need an optional feature of Windows;
- a restricted token (what some coding agents use) needs no administrator, but leaves the network open and lets the
  build read whatever the Users group may read;
- other sandboxes that run tools in an AppContainer make it work by changing the permissions of `\Device\Null` as an
  administrator, again after every boot.

## Why a DLL

Build tools were written for processes that may open anything their user may. In an AppContainer many of them fail on
things that are harmless but closed to containers, before they build anything:

- CMake, Ninja, Python and `cmd` open the null device `NUL`, which Windows does not open to containers;
- the Cygwin runtime under MSYS2's `sh` and `make` (configure scripts need them) makes named objects and pipes in places
  a container cannot, and its `fork` changes permissions in ways the container refuses;
- MSVC's compiler writes debug information through a server process (`mspdbsrv`) that it asks to be you, which a server
  in the container never is, and starts a telemetry program that waits for a network it does not have.

Each of these could be fixed in the tool, but there are dozens of tools and versions, most not otok's to change, and a
recipe should build with the tools as their authors ship them. So otok fixes them in one place: `otok-sandbox.dll`
answers these requests inside the processes of the build, and the tools run unchanged.

otok starts each process of a build suspended in the container, loads the DLL into it with
[Microsoft Detours](https://github.com/microsoft/Detours), Microsoft's own library for this, and resumes it. The DLL
passes itself on to every process that process starts, so the whole build has it.

## What the DLL does, and what it never does

The DLL only ever **grants**: it gives a process of the build what the container is refused but builds need, and never
takes a check away. Every access still goes through the kernel's check of the container's identity. What the DLL hands
out, otok opened beforehand, outside the container, with the least access that works, and gave to the process as a
handle; the DLL cannot open anything the process could not have been given. A program that goes around the DLL, with
direct system calls, gains nothing: it only loses the fixes and fails as it would without them. The sandbox is the
AppContainer; the DLL is what lets build tools live in it.

What it answers, one finding of the tests each:

| What a tool does | What the DLL does |
| --- | --- |
| opens `NUL` | gives a handle to the null device, opened by otok |
| opens or makes a named pipe, a named object or an object directory | uses the container's own namespace for it, where a container may |
| makes an object with a security descriptor that leaves the container out | adds the container, beside you and SYSTEM |
| Cygwin's `fork` and its process links | gives the container the access to its own processes that Cygwin sets for you |
| asks which devices the drive letters are, or the attributes of a drive's root | answers from a table and handles otok made outside |
| `mkdir -p` passing through the directories above the work directory | gives handles that let it pass through exactly those, without listing or reading them |
| MSVC's compiler connects to `mspdbsrv` | asks for the server as you in this container, and only for the container's own servers |
| MSVC starts its telemetry (`VCTIP.EXE`) | does not start it: without the network it stalls the compiler for seconds |
| uses otok's jobserver, which shares the cores among the builds | finds it where otok made it |
| reads `TEMP`, `TMP` and `LOCALAPPDATA`, which Windows rewrites for a container | sets back the values otok gave, inside the work directory |

The DLL never:

- loads into any program but those otok starts for a build and the processes they start; your editor, your shell and
  the rest of the system never see it;
- installs anything: no driver, no service, no system-wide hook, nothing that runs once otok has exited;
- needs or uses administrator rights;
- reaches the network, or sends anything anywhere.

Two more things live in the DLL, with the sandbox and without it. Windows' build tools fail on paths longer than 260
characters, so builds see the cache and their work directories through short drive letters that only otok and the
processes of its builds have (see [Install](/start/install/#windows)); the DLL gives these to every new process and
writes paths back through them. And where otok runs without a desktop (a service, SSH, a CI runner installed as a
service), otok makes a window station and a desktop of its own for the container, since Windows opens the service's
one to none.

## Checking it yourself

- The DLL's source is one file, [`src/otok-sandbox/sandbox_dll.cpp`](https://github.com/otok-dev/otok/blob/main/src/otok-sandbox/sandbox_dll.cpp),
  with each hook explained where it is made. The release binaries are built from the tagged source by the
  repository's own [workflow](https://github.com/otok-dev/otok/actions), in public.
- What the container was refused during a build is logged in `sandbox.log` of the build's work directory;
  `--keep-build-dirs` keeps the work directories, of a failed build in the cache's `failed/` directory.
- `--no-sandbox` builds without the container; the DLL then only gives the drive letters, which
  `--no-virtual-paths` turns off too.

## Limits

- **Antivirus programs.** Loading a DLL into other processes is also what some malware does, and otok's binaries are
  not signed yet. Microsoft Defender has found nothing in our tests, but the machine-learning models of some antivirus
  programs may flag `otok-sandbox.dll`. If yours quarantines it, builds stop with an error naming it; please report it
  to the vendor as a false positive, and to us.
- **No loopback.** A build cannot reach `localhost` either, so a test suite that talks to a local server cannot run in
  the sandbox.
- **What exists outside.** A build can tell whether a path it guesses exists outside the sandbox, as the kernel answers
  "not found" and "access denied" differently, but it can neither list a directory nor read a file there. (Seatbelt on
  macOS shows such metadata too.)
- **64-bit processes.** A 32-bit program in a build runs in the container without the DLL's fixes.
- **Cost.** Ending a process in an AppContainer costs the kernel a little more; builds take about a tenth longer than
  without the sandbox. Rarely, after long uptime, Windows gets into a state where it costs far more: otok measures it
  before the first build, and warns that builds will be slow and a reboot usually clears it.
