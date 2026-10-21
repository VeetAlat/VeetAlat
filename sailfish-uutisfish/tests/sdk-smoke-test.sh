#!/bin/sh
#
# End-to-end smoke test in the Sailfish SDK (Docker), against Sailfish's
# own Qt 5.6 and Silica. Serves tests/fixtures over HTTP, builds a copy of
# the app with tests/SmokeTest.qml injected, runs it twice without a
# window (the SDK has no GPU), and fails on any failed check or QML warning.
#
# Each run ends with "Exit reason and status: signal 11". That's Silica's
# cover machinery without the phone's home screen: the smallest possible
# Silica app with one CoverAction crashes the same way on quit here, and
# the same app without cover actions exits cleanly. Runs are therefore
# counted by their "SMOKE DONE" line, not the exit status.

set -eu

SDK_VERSION=4.6.0.13
TARGET=SailfishOS-$SDK_VERSION-i486
PORT=${PORT:-8765}
HERE=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)

# Serve the fixtures (each source's feeds and example story pages) with
# picture addresses pointing at this server, and a real picture file for
# each, so loading a story's photos shows up in the server log.
mkdir -p "$WORK/www"
cp -r "$HERE/tests/fixtures/." "$WORK/www/"
find "$WORK/www" -type f -exec sed -i -e "s|https://kuvat.example/|http://127.0.0.1:$PORT/|g" \
    -e "s|https://images.cdn.yle.fi/|http://127.0.0.1:$PORT/|g" {} +
grep -h -o "http://127.0.0.1:$PORT/[^\"<]*\.jpg" "$WORK/www" -r | sort -u | while read -r url; do
    file="$WORK/www/${url#http://127.0.0.1:"$PORT"/}"
    mkdir -p "$(dirname "$file")"
    cp "$HERE/icons/172x172/uutisfish.png" "$file" # Qt reads the format from the content
done

# Like "python3 -m http.server", but a page with a <name>.status file next
# to it is answered with that status (a site's browser check is a 403).
cat > "$WORK/serve.py" <<'SERVE'
import functools, http.server, os, sys

class Handler(http.server.SimpleHTTPRequestHandler):
    def send_response(self, code, message=None):
        path = self.translate_path(self.path)
        if code == 200 and os.path.isfile(path + ".status"):
            code = int(open(path + ".status").read())
        super().send_response(code, message)

http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])),
    functools.partial(Handler, directory=sys.argv[2])).serve_forever()
SERVE
python3 "$WORK/serve.py" "$PORT" "$WORK/www" > "$WORK/http.log" 2>&1 &
SERVER=$!
trap 'kill $SERVER 2> /dev/null; rm -rf "$WORK"' EXIT

cp -r "$HERE" "$WORK/app"
rm -rf "$WORK/app/RPMS" "$WORK/app/Makefile" "$WORK/app"/*.o "$WORK/app"/moc_*
cp "$HERE/tests/SmokeTest.qml" "$WORK/app/qml/SmokeTest.qml"
python3 - "$WORK/app/qml/uutisfish.qml" <<'EOF'
import sys
path = sys.argv[1]
s = open(path).read().rstrip()
assert s.endswith("}")
s = s[:-1] + "\n    SmokeTest { testedWindow: app; testedNews: newsStore }\n}\n"
open(path, "w").write(s)
EOF
chmod -R a+rwX "$WORK"

docker run --rm --network host -v "$WORK/app:/home/mersdk/src" -w /home/mersdk/src \
    "coderus/sailfishos-platform-sdk:$SDK_VERSION" bash -c "
        mb2 -t $TARGET build > build.log 2>&1 || { tail -30 build.log; exit 1; }
        sb2 -t $TARGET -m sdk-install -R rpm -i --nodeps --force RPMS/*.i486.rpm > /dev/null 2>&1
        for run in 1 2; do
            UUTISFISH_NO_WINDOW=1 UUTISFISH_FEED_BASE=http://127.0.0.1:$PORT/ \
            UUTISFISH_ARTICLE_BASE=http://127.0.0.1:$PORT/ \
            QT_LOGGING_TO_CONSOLE=1 QT_QPA_PLATFORM=minimal timeout 30 \
                sb2 -t $TARGET /usr/bin/uutisfish 2>&1 |
                grep -v -E 'dconf|pixel ratio|DPI|^\$' || true
        done" > "$WORK/out.log" 2>&1

cat "$WORK/out.log"
echo
passes=$(grep -c "SMOKE PASS" "$WORK/out.log" || true)
fails=$(grep -c "SMOKE FAIL" "$WORK/out.log" || true)
runs=$(grep -c "SMOKE DONE" "$WORK/out.log" || true)
# Silica's cover window needs the phone's home screen (lipstick) for its
# Config object, so it complains when there's no window; that one file is
# Sailfish's, not ours, and is left out. Everything else counts.
warnings=$(grep -v "SMOKE" "$WORK/out.log" | grep -v "Sailfish/Silica/private/CoverWindow.qml" |
    grep -c -E "qml|Error|Warning|warning|unavailable|Binding loop" || true)
fetches=$(grep -c "GET /" "$WORK/http.log" || true)
# Opening the story must load its photos.
photos=$(grep -c -E "GET /[^ ]*\.(jpg|jpeg|png)" "$WORK/http.log" || true)

echo "passed: $passes, failed: $fails, runs completed: $runs/2, QML warnings: $warnings," \
     "HTTP requests served: $fetches, photos downloaded: $photos"
[ "$fails" -eq 0 ] && [ "$runs" -eq 2 ] && [ "$warnings" -eq 0 ] && [ "$passes" -gt 0 ] && [ "$photos" -gt 0 ]
