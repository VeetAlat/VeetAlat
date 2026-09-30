Name:       neonrider
Summary:    Ride a neon bike through a tunnel, on the floor, walls and roof
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
BuildRequires:  desktop-file-utils

%description
A neon bike races down a square tunnel with a glowing grid for a floor,
walls and roof. Move left and right from lane to lane, up the walls and
onto the roof when the floor runs out, and jump over gaps and blocks.
It gets faster the further you go.

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
* Wed Sep 30 2026 Valatalo - 0.1.0-1
- First version: the tunnel, lane changes onto the walls and roof,
  jumping, holes and blocks, four bike colours, best distance.
