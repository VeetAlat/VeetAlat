Name:       codesysfish
Summary:    Write Structured Text (IEC 61131-3) and run it like a PLC
Version:    0.1.0
Release:    1
License:    MIT
URL:        https://github.com/VeetAlat/VeetAlat
Source0:    %{name}-%{version}.tar.bz2

Requires:   sailfishsilica-qt5 >= 0.10.9
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(Qt5Gui)
BuildRequires:  desktop-file-utils

%description
Write IEC 61131-3 Structured Text on your phone, the way CODESYS writes
it, and run it like a PLC: a compiler with clear errors, an editor with
syntax highlighting, and an online view that shows every variable live
and lets you write values. Programs, functions, function blocks, arrays,
structs, enums, timers and counters. Not affiliated with CODESYS GmbH.
Made by Valatalo.

%prep
%setup -q -n %{name}-%{version}

%build
%qmake5
%make_build

%install
%qmake5_install
# No debugging symbols: a smaller package.
%{__strip} %{buildroot}%{_bindir}/%{name}
desktop-file-install --delete-original \
    --dir %{buildroot}%{_datadir}/applications \
    %{buildroot}%{_datadir}/applications/*.desktop

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png

%changelog
* Thu Oct 22 2026 Valatalo - 0.1.0-1
- First version: a Structured Text compiler and PLC runtime, an editor
  with syntax highlighting, an online view, examples and a reference.
