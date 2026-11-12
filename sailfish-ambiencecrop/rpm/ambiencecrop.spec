Name:       ambiencecrop
Summary:    Frame a photo for an ambience, with a blur around it
Version:    0.1.0
Release:    1
License:    MIT
URL:        https://github.com/VeetAlat/VeetAlat
Source0:    %{name}-%{version}.tar.bz2

Requires:   sailfishsilica-qt5 >= 0.10.9
Requires:   sailfish-components-pickers-qt5
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(Qt5Gui)
BuildRequires:  pkgconfig(Qt5DBus)
BuildRequires:  pkgconfig(Qt5Concurrent)
BuildRequires:  desktop-file-utils

%description
Sailfish ambiences use a square picture and show only its middle. Place
a photo on that square yourself, see exactly what the phone shows upright
and sideways, and fill the rest with a blur of the photo (or its colour,
or black). Saves a 2048 x 2048 picture and makes the ambience.
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
* Thu Nov 12 2026 Valatalo - 0.1.0-1
- First version: place a photo on the ambience's square, with guides for
  the upright and sideways screens and a blur around it; save it and
  make the ambience.
