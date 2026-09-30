Name:       roachrider
Summary:    The roach needs to ride its way through the neon grid
Version:    0.2.0
Release:    1
License:    MIT
URL:        https://github.com/VeetAlat/VeetAlat
Source0:    %{name}-%{version}.tar.bz2

Requires:   sailfishsilica-qt5 >= 0.10.9
# The first test build was called Neon Rider.
Obsoletes:  neonrider <= 0.1.0
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  desktop-file-utils

%description
The roach needs to ride its way through the neon grid! Use the arrows to
move lanes, including to the walls and ceiling! Circle is used to jump.
Don't hit the blocks, and don't fall into the ominous void!

%prep
%setup -q -n %{name}-%{version}

%build
%qmake5
%make_build

%install
%qmake5_install
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
* Wed Sep 30 2026 Valatalo - 0.2.0-1
- Now Roach Rider: the rider is a roach, rendered from a 3D model, with a
  new icon and start screen.
- Fixed: the game froze for seconds whenever a button was pressed.
- A Menu button after a crash and in the pause menu.
- Bike colours removed.

* Wed Sep 30 2026 Valatalo - 0.1.0-1
- First version: the tunnel, lane changes onto the walls and roof,
  jumping, holes and blocks, four bike colours, best distance.
