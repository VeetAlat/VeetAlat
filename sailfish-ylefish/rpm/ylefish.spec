Name:       ylefish
Summary:    Yle's news, whole stories and photos, in one app
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
Yle's news on Sailfish OS: the headlines from Yle's RSS feeds by
category, and each whole story, text and photos, read right in the app.
A private app for personal use: Yle's RSS terms only allow published apps
to show headlines linking to yle.fi. Unofficial, not affiliated with Yle.
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
- First version, from UutisRSS: tapping a story opens it in the app, with
  its whole text and photos.
