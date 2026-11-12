Name:       veetpatched
Summary:    Small changes to Sailfish OS, on and off with a switch
Version:    0.2.2
Release:    1
License:    MIT
URL:        https://github.com/VeetAlat/VeetAlat
Source0:    %{name}-%{version}.tar.bz2

Requires:   sailfishsilica-qt5 >= 0.10.9
Requires:   systemd
Requires:   lipstick-jolla-home-qt5
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  desktop-file-utils

%description
VeetPatched puts small changes into Sailfish OS's own software and takes
them out again, with a switch for each. The app asks; a small root helper
(started by systemd) does the change, only for the patches that come with
VeetPatched, and keeps the original file to put back.

Patches: StatusBar, a black bar over the notch while an app is open, with
the time and status icons.
Made by Valatalo.

%prep
%setup -q -n %{name}-%{version}

%build
%qmake5
%make_build

%install
%qmake5_install
chmod 755 %{buildroot}/usr/libexec/veetpatched/veetpatched-helper
# No debugging symbols: a smaller package.
%{__strip} %{buildroot}%{_bindir}/%{name}
desktop-file-install --delete-original \
    --dir %{buildroot}%{_datadir}/applications \
    %{buildroot}%{_datadir}/applications/*.desktop

%post
# The watcher; the app makes its folder on its first start, and systemd
# follows the folders as they appear.
systemctl daemon-reload || :
systemctl enable veetpatched.path || :
systemctl start veetpatched.path || :

%preun
if [ $1 -eq 0 ]; then
    # Every patch out before the files go.
    /usr/libexec/veetpatched/veetpatched-helper unapply-all || :
    systemctl disable --now veetpatched.path || :
fi

%postun
systemctl daemon-reload || :

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
/usr/libexec/veetpatched
/usr/lib/systemd/system/veetpatched.path
/usr/lib/systemd/system/veetpatched.service

%changelog
* Thu Nov 12 2026 Valatalo - 0.2.2-1
- StatusBar: a compact battery, with the charge percentage inside a small
  battery instead of an icon with the percentage beside it, so the clock
  has room. Its fill shows the charge: green while charging, red when
  low, amber in power save. It replaces the home screen's battery in the
  bar only; if it can't load, the home screen's battery stays.

* Thu Nov 12 2026 Valatalo - 0.2.1-1
- StatusBar: the clock and the battery no longer overlap. The clock goes
  at the left edge with the home screen's left icons (battery, profile,
  do not disturb, alarm) right after it; if they don't fit before the
  notch they shrink to fit (to 60% at most), and so do the right icons.
  The home screen's journal gets one line on how it fitted.

* Thu Nov 12 2026 Valatalo - 0.2.0-1
- Proper logging. The helper logs every step with a level (INFO, WARN,
  ERROR), the files' sizes and checksums before and after, failing
  commands' own error output and the phone's Sailfish and home screen
  versions, to /var/lib/veetpatched/log (rotated past 256 kB) and the
  system journal (journalctl -t veetpatched); refused requests are logged
  without their contents. The app logs its requests, answers with their
  times, and timeouts. The Log page merges both, newest first, with
  problems marked and a "Problems only" view.

* Thu Nov 12 2026 Valatalo - 0.1.0-1
- First version: an app with a root helper (started by systemd) that
  applies and removes patches; first patch, StatusBar.
