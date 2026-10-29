# Overscroll Emit

Shows a macOS-style "end of scroll" edge glow on demand, from the command line.

```sh
./scripts/build.sh
build/OverscrollEmit.app/Contents/Helpers/overscroll-emit left
build/OverscrollEmit.app/Contents/Helpers/overscroll-emit right --display 2 --size large --density dark --flair flashy --color accent
build/OverscrollEmit.app/Contents/Helpers/overscroll-emit left --color rainbow
build/OverscrollEmit.app/Contents/Helpers/overscroll-emit left --color=#ff8800   # use = so the shell does not treat # as a comment
```

```
Usage:
  overscroll-emit left|right [options]   Show the edge glow on the left/right side
  overscroll-emit settings               Open the settings window
  overscroll-emit displays               List displays (indices for --display)
  overscroll-emit quit                   Quit the resident app
  overscroll-emit version
  overscroll-emit help

Options (* = default):
  --display  active*|primary|mouse|<n>
  --size     small|medium*|large|huge     (大きさ)
  --density  light|medium*|dark     (濃さ)
  --flair    calm|normal*|flashy     (派手さ)
  --speed    slow|normal*|fast
  --color    gray*|white|black|accent|blue|red|green|orange|purple|rainbow|#RRGGBB
```

The CLI starts OverscrollEmit.app in the background on first use. Opening OverscrollEmit.app directly shows its settings (launch at login, CLI path, a style preview). No permissions are needed.

Install: `INSTALL_DIR=/Applications BIN_DIR=/usr/local/bin ./scripts/install.sh`

License: [Unlicense](UNLICENSE) (public domain).
