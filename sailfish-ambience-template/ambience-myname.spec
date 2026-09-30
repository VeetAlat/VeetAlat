# Rename "ambience-myname" everywhere (this file, the .ambience file, the
# paths inside it) to your own ambience name. Keep the "ambience-" prefix.
Name:       ambience-myname
Version:    1.0.0
Release:    1
Summary:    My Ambience for Sailfish OS
License:    CC-BY-SA-4.0
BuildArch:  noarch
URL:        https://github.com/VeetAlat/VeetAlat
Requires:   ambienced

%description
A Sailfish OS ambience with a custom wallpaper, highlight colour and sounds.

%prep
# Nothing to unpack: files are taken straight from ./ambience

%build
# Nothing to build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{_datadir}/ambience/%{name}/images
mkdir -p %{buildroot}%{_datadir}/ambience/%{name}/sounds
install -m 644 %{_sourcedir}/ambience/%{name}.ambience %{buildroot}%{_datadir}/ambience/%{name}/
install -m 644 %{_sourcedir}/ambience/images/*.jpg %{buildroot}%{_datadir}/ambience/%{name}/images/
# Sounds are optional; skip quietly if the folder is empty
find %{_sourcedir}/ambience/sounds -maxdepth 1 -type f \( -name '*.ogg' -o -name '*.wav' -o -name '*.mp3' \) \
    -exec install -m 644 {} %{buildroot}%{_datadir}/ambience/%{name}/sounds/ \;

%files
%defattr(-,root,root,-)
%{_datadir}/ambience/%{name}

%post
# Make ambienced pick up the new ambience right away
systemctl-user restart ambienced.service >/dev/null 2>&1 || :

%postun
systemctl-user restart ambienced.service >/dev/null 2>&1 || :

%changelog
* Wed Sep 30 2026 VeetAlat <alatalonveeti@gmail.com> - 1.0.0-1
- First release
