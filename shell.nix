{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    swift
    xcodegen
  ];

  shellHook = ''
    echo "MuxCore iOS dev shell"
    echo "  xcodegen generate   # on Mac, produces MuxCore.xcodeproj"
    echo "  swift test          # Linux/macOS: MuxCoreKit unit tests"
  '';
}
