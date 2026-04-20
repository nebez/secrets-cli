<h1><img src="logo.svg" width="48" valign="middle">&nbsp;&nbsp;secrets</h1>

A tiny CLI for storing and retrieving secrets using the macOS Keychain. Secrets are stored under a dedicated service name so they don't clutter your login keychain, and retrievals go through `LAContext` so macOS will prompt Touch ID (or your password) before handing anything back.

All output except the secret itself goes to stderr, so it plays nicely with pipes.

## Install

```
make install
```

This compiles the Swift source, ad-hoc code signs it, and drops the binary into `~/.local/bin/`. Make sure that's on your `PATH`.

## Usage

```bash
secrets set my-api-key              # prompts for value (hidden input)
secrets set my-api-key sk-abc123    # inline value

secrets get my-api-key              # Touch ID prompt, prints value to stdout
secrets get my-api-key | pbcopy     # straight to clipboard

secrets list                        # show all stored key names
secrets delete my-api-key           # remove from keychain
```

## How it works

Secrets are stored as generic passwords in the macOS Keychain under the service `com.nebez.secrets`. Each key maps to a `kSecAttrAccount` entry. Nothing is written to disk — the Keychain handles storage and encryption.

Every `get` call triggers a fresh Touch ID prompt via `LAContext` with no authentication caching — you'll always need your fingerprint to retrieve a secret.

## Uninstall

```
make uninstall
```

Your secrets stay in the Keychain. To remove them too, `secrets delete` each key first, or use Keychain Access.app.
