# Building the Hypothesis Client + Browser Extension

This project consists of two repos that work together:

- **hypothesis-client-with-ai** (this repo) — The annotation client UI: sidebar, annotator overlay, and boot script.
- **hypothesis-browser-extension-with-AI** — The Chrome extension wrapper that loads the client into web pages.

The extension depends on the client. When you change client code, you need to rebuild both.

## Prerequisites

- Node.js
- Yarn (v3.6+)
- Make

## Directory Layout

Both repos should be sibling directories:

```
your-projects/
  hypothesis-client-with-ai/                (this repo)
  hypothesis-browser-extension-with-AI/     (extension repo)
```

## First-Time Setup

Run the setup script from this repo:

```bash
./build-extension.sh --setup
```

This does three things:

1. Updates the extension's `package.json` so its `hypothesis` dependency resolves to your local client repo (via Yarn's `portal:` protocol).
2. Runs `yarn install` in the client repo.
3. Runs `yarn install` in the extension repo.

If the extension repo isn't found as a sibling directory, the script will prompt you for its path.

## Building

### Full Build (Client + Extension)

```bash
./build-extension.sh
```

This runs `make build` in the client, then `make build` in the extension. The output is a ready-to-load unpacked extension at `../hypothesis-browser-extension-with-AI/build/`.

### Extension Only

If you've already built the client and only need to re-package the extension:

```bash
./build-extension.sh --ext
```

### Watch Mode

For rapid iteration on client code:

```bash
./build-extension.sh --watch
```

This starts Gulp in watch mode — CSS, JS, and the boot script rebuild automatically when source files change. When you're ready to test in Chrome, stop the watcher (Ctrl+C) and run `./build-extension.sh --ext` to package the extension.

## Loading the Extension in Chrome

1. Go to `chrome://extensions/`
2. Enable **Developer mode** (toggle in the top right)
3. Click **Load unpacked**
4. Select the `../hypothesis-browser-extension-with-AI/build/` directory

After each rebuild, click the **reload** icon on the extension card in `chrome://extensions/` to pick up changes.

## Manual Build Commands

You can also build each repo independently:

| Command | Where | What it does |
|---|---|---|
| `make build` | client repo | Production build of client into `build/` |
| `make dev` | client repo | Watch mode with dev server (port 3001) |
| `make build` | extension repo | Builds extension into `build/` |
| `make dev` | extension repo | Watch mode for extension |
| `make lint` | either repo | Run linter + type checker |
| `make test` | either repo | Run unit tests |
| `make sure` | either repo | Run formatter, linter, and tests |

## How the Build Works

1. **Client build** (`make build` in this repo): Gulp + Rollup bundle the TypeScript/Preact source into JS bundles, compile SCSS/Tailwind into CSS, copy fonts, and generate a `build/manifest.json` mapping asset names to cache-busted filenames.

2. **Extension build** (`make build` in the extension repo): Copies the client's `build/` output into `build/client/`, renders the boot script with Chrome extension URLs, bundles the background service worker via Rollup, and generates `manifest.json` from a Mustache template.

3. **The link between them**: The extension's `package.json` has a Yarn `resolutions` entry that maps the `hypothesis` package to this local client repo via `portal:`. This means `node_modules/hypothesis/build/` points to the client's build output. The `--setup` flag configures this automatically.
