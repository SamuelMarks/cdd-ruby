#!/usr/bin/env python3
import glob
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

PREBUILT_RUBY_WASM_URL = (
    "https://github.com/ruby/ruby.wasm/releases/download/2.10.1/"
    "ruby-3.4-wasm32-unknown-wasip1-full.tar.gz"
)
PREBUILT_EXTRACT_DIR = "ruby-3.4-wasm32-unknown-wasip1-full"


def extend_ruby_path():
    candidate_dirs = [
        "/opt/homebrew/opt/ruby/bin",
        "/usr/local/opt/ruby/bin",
        *sorted(glob.glob("/opt/homebrew/lib/ruby/gems/*/bin"), reverse=True),
        *sorted(glob.glob("/usr/local/lib/ruby/gems/*/bin"), reverse=True),
        *sorted(
            glob.glob(os.path.expanduser("~/.gem/ruby/*/bin")), reverse=True
        ),
        *sorted(
            glob.glob(os.path.expanduser("~/.local/share/gem/ruby/*/bin")),
            reverse=True,
        ),
    ]
    for path_dir in candidate_dirs:
        if os.path.isdir(path_dir):
            os.environ["PATH"] = (
                f"{path_dir}{os.pathsep}{os.environ.get('PATH', '')}"
            )

    ruby_bin = shutil.which("ruby")
    if ruby_bin:
        try:
            out = subprocess.check_output(
                [
                    ruby_bin,
                    "-e",
                    "puts Gem.bindir; puts File.join(Gem.user_dir, 'bin')",
                ],
                text=True,
                stderr=subprocess.DEVNULL,
            )
            for line in out.splitlines():
                gem_bin = line.strip()
                if gem_bin and os.path.isdir(gem_bin):
                    os.environ["PATH"] = (
                        f"{gem_bin}{os.pathsep}{os.environ.get('PATH', '')}"
                    )
        except Exception:
            pass


extend_ruby_path()

if shutil.which("rbwasm") is None:
    gem_bin = shutil.which("gem")
    if gem_bin is not None:
        print("rbwasm not found in PATH; attempting `gem install ruby_wasm`...")
        subprocess.run(
            [gem_bin, "install", "ruby_wasm", "--no-document"], check=False
        )
        extend_ruby_path()

if shutil.which("rbwasm") is None:
    print("rbwasm not found in PATH; skipping WASM build.")
    sys.exit(0)

bin_dir = os.environ.get("BIN_DIR", "dist")
os.makedirs(bin_dir, exist_ok=True)
cdd_ruby_wasm_path = os.path.join(bin_dir, "cdd-ruby.wasm")

print("Building WASM via ruby-wasm. It requires ruby.wasm packager.")

with tempfile.TemporaryDirectory() as tmp_dir:
    tarball_path = os.path.join(tmp_dir, "ruby-wasm.tar.gz")
    prebuilt_ready = False
    try:
        print(f"Downloading prebuilt ruby.wasm from {PREBUILT_RUBY_WASM_URL}...")
        urllib.request.urlretrieve(PREBUILT_RUBY_WASM_URL, tarball_path)
        with tarfile.open(tarball_path, "r:gz") as tar:
            tar.extractall(path=tmp_dir)
        extracted_root = os.path.join(tmp_dir, PREBUILT_EXTRACT_DIR)
        extracted_ruby_bin = os.path.join(
            extracted_root, "usr", "local", "bin", "ruby"
        )
        prebuilt_ruby_wasm = os.path.join(tmp_dir, "ruby.wasm")
        prebuilt_usr_dir = os.path.join(extracted_root, "usr")
        if os.path.isfile(extracted_ruby_bin) and os.path.isdir(
            prebuilt_usr_dir
        ):
            shutil.move(extracted_ruby_bin, prebuilt_ruby_wasm)
            prebuilt_ready = True
    except Exception as exc:
        print(
            f"Prebuilt ruby.wasm download failed ({exc}); falling back to rbwasm build."
        )

    if prebuilt_ready:
        pack_cmd = [
            "rbwasm",
            "pack",
            prebuilt_ruby_wasm,
            "--dir",
            f"{prebuilt_usr_dir}::/usr",
            "--dir",
            "src::/src",
            "--dir",
            "bin::/bin",
            "-o",
            cdd_ruby_wasm_path,
        ]
        if subprocess.run(pack_cmd).returncode != 0:
            print("Failed to pack wasm")
            sys.exit(1)
    else:
        ruby_wasm_path = os.path.join(tmp_dir, "ruby.wasm")
        if (
            subprocess.run(
                ["rbwasm", "build", "-o", ruby_wasm_path, "--disable-gems"]
            ).returncode
            != 0
        ):
            print("Failed to build ruby.wasm")
            sys.exit(1)

        if (
            subprocess.run(
                [
                    "rbwasm",
                    "pack",
                    ruby_wasm_path,
                    "--dir",
                    "src::/src",
                    "--dir",
                    "bin::/bin",
                    "-o",
                    cdd_ruby_wasm_path,
                ]
            ).returncode
            != 0
        ):
            print("Failed to pack wasm")
            sys.exit(1)
