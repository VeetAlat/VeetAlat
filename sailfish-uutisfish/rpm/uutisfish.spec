Name:       uutisfish
Summary:    Yle, MTV Uutiset and AP News, whole stories and photos, in one app
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
Three news sources in one Sailfish app: Yle, MTV Uutiset and AP News,
each with its headlines by category, and each whole story, text and
photos, read right in the app. A private app for personal use, not for
publishing. Unofficial, not affiliated with Yle, MTV or the AP.
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
* Wed Oct 21 2026 Valatalo - 0.1.0-1
- First version: YleFish and MTVFish in one app, with AP News added, and
  a home page with a tile for each source.
