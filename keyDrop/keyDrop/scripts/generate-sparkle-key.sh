#!/bin/bash
# generate-sparkle-key.sh
# One-time script to generate EdDSA signing key for Sparkle updates.
# Run this ONCE, then store the private key securely outside the repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
KEYS_DIR="$HOME/.keydrop-keys"

echo "[*] Sparkle EdDSA Key Generator"
echo "[*] Keys will be stored in: $KEYS_DIR"
echo ""

# Create keys directory if it doesn't exist
mkdir -p "$KEYS_DIR"
chmod 700 "$KEYS_DIR"

# Check if key already exists
if [[ -f "$KEYS_DIR/sparkle_eddsa_key.pem" ]]; then
    echo "[!] Key already exists at $KEYS_DIR/sparkle_eddsa_key.pem"
    echo "[!] Delete it first if you want to regenerate."
    exit 1
fi

# Find Sparkle's generate_keys tool from SPM build
SPARKLE_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "generate_keys" -path "*/Sparkle.framework/*" 2>/dev/null | head -1)

if [[ -z "$SPARKLE_PATH" ]]; then
    echo "[!] Sparkle generate_keys not found in DerivedData."
    echo "[!] Build the project first with: xcodebuild -scheme keyDrop build"
    echo ""
    echo "[?] Alternatively, generate manually with openssl:"
    echo "    openssl genpkey -algorithm ed25519 -out $KEYS_DIR/sparkle_eddsa_key.pem"
    echo "    openssl pkey -in $KEYS_DIR/sparkle_eddsa_key.pem -pubout -out $KEYS_DIR/sparkle_eddsa_key.pub"
    exit 1
fi

echo "[*] Found Sparkle tools at: $(dirname "$SPARKLE_PATH")"
echo "[*] Generating EdDSA key pair..."

# Generate the key using Sparkle's tool
cd "$(dirname "$SPARKLE_PATH")"
./generate_keys -p > "$KEYS_DIR/sparkle_eddsa_key.txt" 2>&1

# Extract the public key for Info.plist
PUBLIC_KEY=$(grep "Public Key:" "$KEYS_DIR/sparkle_eddsa_key.txt" | cut -d: -f2 | tr -d ' ')

echo ""
echo "[+] Key generated successfully!"
echo ""
echo "================================================"
echo "PUBLIC KEY (add to Info.plist as SUPublicEDKey):"
echo "================================================"
echo "$PUBLIC_KEY"
echo ""
echo "[!] IMPORTANT: The private key is stored in Keychain by Sparkle."
echo "[!] Back up your Keychain or export the key for CI/CD use."
echo ""
echo "[*] To export for CI, run:"
echo "    $(dirname "$SPARKLE_PATH")/generate_keys -x > $KEYS_DIR/sparkle_private_key_export.txt"
echo ""
echo "[*] Add this to your Config/Direct.xcconfig or Info-Direct.plist:"
echo "    SUPublicEDKey = $PUBLIC_KEY"
