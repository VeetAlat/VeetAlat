Name:       mtvfish
Summary:    MTV Uutiset's news, whole stories and photos, in one app
Version:    0.1.1
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
MTV Uutiset's news on Sailfish OS: the headlines from MTV Uutiset's RSS
feeds, and each whole story, text and photos, read right in the app.
A private app for personal use, not for publishing. Unofficial, not
affiliated with MTV.
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
* Wed Oct 21 2026 Valatalo - 0.1.1-1
- Reads stories from pages built with JavaScript (the data embedded in the
  page) and from stories with other stories nested inside them.
- "Copy page report" in a story's pull-down menu when its text isn't found.

* Wed Oct 21 2026 Valatalo - 0.1.0-1
- First version, from YleFish: MTV Uutiset's news, with each whole story
  and its photos read in the app.
