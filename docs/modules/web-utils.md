# web-utils module

**Location:** `modules/web-utils/flake.nix`  
**Pack name:** `web-utils`  
**Options namespace:** `services.webUtils`

---

## Why this module exists

Browser configuration on NixOS is fragmented by default: the browser package is installed, but MIME associations, the `$BROWSER` environment variable, and search engine preferences are all separate concerns that each need to be wired up individually. On a fresh install they are frequently wrong or missing. This module handles all of them in one place.

---

## What the module does

### zen-browser

[Zen Browser](https://github.com/0xc000022070/zen-browser-flake) is a Firefox-based browser focused on privacy and a minimal UI. It is not in nixpkgs so it is sourced from the community flake `0xc000022070/zen-browser-flake`, which tracks upstream GitHub releases.

### Default browser wiring

Setting a default browser on NixOS requires three independent things to be correct simultaneously:

| Mechanism | What reads it | How this module sets it |
|---|---|---|
| XDG MIME defaults | `xdg-open`, file managers, most apps | `xdg.mime.defaultApplications` for `text/html`, `x-scheme-handler/http`, `x-scheme-handler/https`, and related types |
| `$BROWSER` env var | Terminal apps, scripts, some GUI apps | `environment.sessionVariables.BROWSER = "zen"` |

Without all three, some apps open links in the right browser and others fall back to whatever they find first.

### DuckDuckGo search engine

Zen Browser (like Firefox) can be configured via an [enterprise policy](https://mozilla.github.io/policy-templates/) JSON file. This module writes `/etc/zen/policies/policies.json` with:

```json
{
  "policies": {
    "DefaultSearchProviderEnabled": true,
    "DefaultSearchProviderName": "DuckDuckGo",
    "DefaultSearchProviderSearchURL": "https://duckduckgo.com/?q={searchTerms}",
    "DefaultSearchProviderSuggestURL": "https://ac.duckduckgo.com/ac/?q={searchTerms}&type=list"
  }
}
```

This is intentional: the policy file is owned by the system (not the user profile), so it survives profile resets and new user creation. Individual users can still override the search engine in their browser settings — enterprise policies in Firefox/Zen set the *default*, they don't lock it unless a separate `Locked` key is added.

---

## Options reference

```nix
services.webUtils = {
  enable = true;  # master switch

  zenBrowser = {
    enable     = true;   # install zen-browser
    setDefault = true;   # wire MIME + $BROWSER
    duckDuckGo = true;   # write enterprise policy for DDG
  };
};
```

All options default to `true`. Adding `web-utils` to a machine's `modules` in `inventory/machines.json` is all that is needed.

---

## Notes

- The zen-browser flake pins its own nixpkgs but is told to `follow` the root flake's nixpkgs via `inputs.nixpkgs.follows` to avoid a duplicate nixpkgs in the closure.
- Zen's `.desktop` entry is `zen.desktop` — this is what the MIME default entries reference. If this ever changes upstream the MIME entries will silently stop working; check with `xdg-mime query default text/html` after a browser update.
