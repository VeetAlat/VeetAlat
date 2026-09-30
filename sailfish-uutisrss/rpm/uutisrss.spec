Name:       uutisrss
Summary:    Unofficial app for Yle's news headlines
Version:    1.0.0
Release:    1
License:    MIT
URL:        https://github.com/VeetAlat/VeetAlat
Source0:    %{name}-%{version}.tar.bz2

Requires:   sailfishsilica-qt5 >= 0.10.9
# Replaces the test builds, packaged under earlier names.
Obsoletes:  harbour-uutisrss <= 1.1.0
Obsoletes:  harbour-yleisuutiset
Obsoletes:  harbour-ynews
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  desktop-file-utils

%description
The latest headlines from Yle, the Finnish public broadcaster, from Yle's
public RSS feeds: the front page's top stories and each news category.
Tapping a headline opens the story on yle.fi. Follows Yle's RSS terms:
headlines only, no photos, free and without ads. Runs only on the device,
with no tracking. Unofficial, not affiliated with Yle. Made by Valatalo.

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
* Wed Sep 30 2026 Valatalo - 1.0.0-1
- First release: Yle's news headlines by category, following Yle's RSS
  terms (headlines only, each opens on yle.fi), works offline, cover
  with the latest headlines and their times.
