# Neon Rider for Sailfish OS

A neon bike races down a square tunnel whose floor, walls and roof are all
a glowing grid. When the floor runs out, ride up the walls or onto the roof;
jump over gaps and blocks. It gets faster the further you go.

Made by Valatalo.

## How to play

Three buttons along the bottom:

- **◀ and ▶** (left side, for one thumb) move one lane. There are 3 lanes
  on each side of the tunnel, 12 all round. Past the edge of the floor you
  ride up the wall, and the view turns so the side you're on is always
  at the bottom.
- **●** (right side, for the other thumb) jumps. A jump pressed just before
  landing still counts.

Holes are black with an orange edge. Blocks are magenta boxes. Fall into a
hole or hit a block and the ride is over. Your best distance and bike
colour (red, blue, green or yellow) are kept. The game pauses when you
leave it, and there's a pause button in the top right.

## How it's built

- `src/gamecore.*`: the whole game with no Qt: the track, the bike and the
  rules. The track is built as you ride, one obstacle at a time: a side of
  the tunnel gone, a gap all the way round, a row of blocks, or stripes of
  holes. Each is followed by a plain stretch longer than a jump, so there's
  always time to land and get ready.
- `src/game.*`: the game as QML sees it: the game loop, the buttons, the
  best distance.
- `src/tunnelview.*`: draws everything in perspective as one list of
  coloured triangles on the GPU, one draw call per frame. Lines are
  drawn as soft glowing strips, so there's no need for antialiasing.
- `qml/`: the game page, the controls (a multi-touch area, so steering and
  jumping work at the same time), the menus, cover and About page.

## Tests

```sh
tests/run-tests.sh          # rules and track, on the build machine's Qt
tests/render-screens.sh     # screenshots of the renderer (needs Xvfb)
tests/sdk-smoke-test.sh     # the whole app in the Sailfish SDK (Docker)
```

- `run-tests.sh` checks lane changes and riding up the walls, falling into
  holes, jumping gaps and blocks, and saving the best distance. A bot
  with perfect reactions also rides 2500 rows of 12 different tracks, which
  shows every track the game builds can be ridden.
- `sdk-smoke-test.sh` runs the app twice on Sailfish's own Qt 5.6 and
  Silica. It plays a game through the page's buttons (moving, jumping,
  pausing, riding until the end) and checks the best distance and colour
  are still there after a restart. The SDK has no GPU, so its copy of the
  app never shows its window; the screenshots cover the drawing.

## Building and installing

```sh
python3 icons/make-icon.py  # only if the icon changes; then make the PNGs
./build-rpm.sh aarch64      # Docker; RPM lands in RPMS/ (armv7hl for 32-bit)
devel-su pkcon install-local ~/Downloads/neonrider-0.1.0-1.aarch64.rpm
```

## Privacy

Runs only on the phone, with no network permission at all. Only the best
distance and bike colour are saved, in
`~/.local/share/org.veetalat/neonrider/`.

## Made with AI-assisted tools

Neon Rider was made with the help of AI-assisted tools (Claude Code).
