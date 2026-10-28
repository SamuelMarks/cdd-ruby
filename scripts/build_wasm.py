#!/usr/bin/env python3
"""Build and optimize the standalone WebAssembly (WASM/WASI) module for cdd-ruby."""

import glob
import os
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from typing import Dict, List, Optional, Set, Tuple

PREBUILT_RUBY_WASM_URL: str = (
    "https://github.com/ruby/ruby.wasm/releases/download/2.10.1/"
    "ruby-3.4-wasm32-unknown-wasip1-full.tar.gz"
)
PREBUILT_EXTRACT_DIR: str = "ruby-3.4-wasm32-unknown-wasip1-full"

# Only the stdlib items needed by cdd-ruby at runtime in WASI.
STDLIB_KEEP_ITEMS: Tuple[str, ...] = (
    "English.rb",
    "date.rb",
    "delegate.rb",
    "digest",
    "digest.rb",
    "erb",
    "erb.rb",
    "fileutils.rb",
    "find.rb",
    "forwardable",
    "forwardable.rb",
    "json",
    "json.rb",
    "logger",
    "logger.rb",
    "monitor.rb",
    "open3",
    "open3.rb",
    "optparse",
    "optparse.rb",
    "ostruct.rb",
    "pathname.rb",
    "pp.rb",
    "prettyprint.rb",
    "random",
    "ripper",
    "ripper.rb",
    "securerandom.rb",
    "set",
    "set.rb",
    "shellwords.rb",
    "singleton.rb",
    "strscan",
    "tempfile.rb",
    "time.rb",
    "timeout.rb",
    "tmpdir.rb",
    "tsort.rb",
    "uri",
    "uri.rb",
    "wasm32-wasi",
)

# Startup prelude stubs to bypass loading rubygems/bundler/did_you_mean in WASI.
PRELUDE_STUBS: Tuple[str, ...] = (
    "rubygems.rb",
    "bundled_gems.rb",
    "error_highlight.rb",
    "did_you_mean.rb",
    "syntax_suggest/core_ext.rb",
)

# Unused statically-linked C extensions & C libraries (OpenSSL, Psych/libyaml,
# Zlib, and non-UTF CJK transcoders) whose function bodies can be stubbed out.
UNUSED_FUNC_RANGES: Tuple[Tuple[str, str], ...] = (
    ("ossl_x509_ary2sk0", "ossl_x509store_free"),
    ("Init_psych", "Init_psych_yaml_tree"),
    ("Init_zlib", "zlib_gzip_end_rescue"),
    ("Init_trans_big5", "from_utf8_mac_finish"),
    ("ssl_sort_cipher_list", "zcfree"),
)


def extend_ruby_path() -> None:
    """Prepend candidate Ruby and Gem binary directories to PATH."""
    candidate_dirs: List[str] = [
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

    ruby_bin: Optional[str] = shutil.which("ruby")
    if ruby_bin:
        try:
            out: str = subprocess.check_output(
                [
                    ruby_bin,
                    "-e",
                    "puts Gem.bindir; puts File.join(Gem.user_dir, 'bin')",
                ],
                text=True,
                stderr=subprocess.DEVNULL,
            )
            for line in out.splitlines():
                gem_bin: str = line.strip()
                if gem_bin and os.path.isdir(gem_bin):
                    os.environ["PATH"] = (
                        f"{gem_bin}{os.pathsep}{os.environ.get('PATH', '')}"
                    )
        except Exception:
            pass


def build_pruned_usr_dir(source_usr_dir: str, target_usr_dir: str) -> str:
    """Create a minimal /usr directory containing only required Ruby stdlib files.

    Removes ~36 MB of static C archives (libruby-static.a), C headers, manpages,
    cached .gem packages, rdoc/irb/bundler/rubygems/prism trees, and installs
    no-op stubs for Ruby's startup gem_prelude files.
    """
    src_stdlib: str = os.path.join(source_usr_dir, "local", "lib", "ruby", "3.4.0")
    if not os.path.isdir(src_stdlib):
        return source_usr_dir

    dst_stdlib: str = os.path.join(target_usr_dir, "local", "lib", "ruby", "3.4.0")
    os.makedirs(dst_stdlib, exist_ok=True)

    for item in STDLIB_KEEP_ITEMS:
        src_path: str = os.path.join(src_stdlib, item)
        dst_path: str = os.path.join(dst_stdlib, item)
        if not os.path.exists(src_path):
            continue
        if os.path.isdir(src_path):
            shutil.copytree(src_path, dst_path)
        else:
            shutil.copy2(src_path, dst_path)

    for stub_rel in PRELUDE_STUBS:
        stub_path: str = os.path.join(dst_stdlib, stub_rel)
        os.makedirs(os.path.dirname(stub_path), exist_ok=True)
        with open(stub_path, "w", encoding="utf-8") as stub_file:
            stub_file.write("# frozen_string_literal: true" + chr(10))

    return target_usr_dir


def _read_u32_leb128(buf: bytes, pos: int) -> Tuple[int, int]:
    """Decode an unsigned LEB128 integer from buf starting at pos."""
    val: int = 0
    shift: int = 0
    while True:
        byte: int = buf[pos]
        pos += 1
        val |= (byte & 0x7F) << shift
        if (byte & 0x80) == 0:
            break
        shift += 7
    return val, pos


def _read_s32_leb128(buf: bytes, pos: int) -> Tuple[int, int]:
    """Decode a signed LEB128 integer from buf starting at pos."""
    val: int = 0
    shift: int = 0
    while True:
        byte: int = buf[pos]
        pos += 1
        val |= (byte & 0x7F) << shift
        shift += 7
        if (byte & 0x80) == 0:
            if byte & 0x40:
                val -= 1 << shift
            break
    return val, pos


def _encode_u32_leb128(val: int) -> bytes:
    """Encode an unsigned integer as LEB128 bytes."""
    out = bytearray()
    while True:
        byte: int = val & 0x7F
        val >>= 7
        if val == 0:
            out.append(byte)
            break
        out.append(byte | 0x80)
    return bytes(out)


def _first_i32_const(body: bytes) -> Optional[int]:
    """Extract the first static data pointer i32.const from a WASM function body."""
    for idx in range(len(body) - 1):
        if body[idx] == 0x41:
            try:
                val, _ = _read_s32_leb128(body, idx + 1)
                if val > 65536:
                    return val
            except IndexError:
                pass
    return None


def optimize_wasm_binary(wasm_path: str) -> None:
    """Shrink the packed WASM binary via pure-Python section pruning and wasm-opt.

    1. Strips all custom sections (.debug_*, name, producers) (~17.8 MB).
    2. Stubs unused C extension functions (OpenSSL/libcrypto/libssl, Psych/libyaml,
       Zlib/libz, non-UTF CJK transcoders) (~4.8 MB).
    3. Drops unused static CJK transcoding lookup table data segments (~2.5 MB).
    4. Runs `wasm-opt -Oz` if Binaryen's `wasm-opt` is available in PATH (~0.6 MB).
    """
    with open(wasm_path, "rb") as wasm_file:
        data: bytes = wasm_file.read()

    if len(data) < 8 or data[:4] != b"\x00asm":
        return

    pos: int = 8
    num_imported: int = 0
    func_names: Dict[int, str] = {}
    code_bodies: Dict[int, bytes] = {}
    data_by_addr: Dict[int, bytes] = {}

    while pos < len(data):
        sec_id: int = data[pos]
        pos += 1
        size, pos = _read_u32_leb128(data, pos)
        sec_end: int = pos + size
        if sec_id == 2:
            count, ptr = _read_u32_leb128(data, pos)
            for _ in range(count):
                mlen, ptr = _read_u32_leb128(data, ptr)
                ptr += mlen
                nlen, ptr = _read_u32_leb128(data, ptr)
                ptr += nlen
                kind: int = data[ptr]
                ptr += 1
                if kind == 0:
                    _, ptr = _read_u32_leb128(data, ptr)
                    num_imported += 1
                elif kind == 1:
                    ptr += 1
                    flags, ptr = _read_u32_leb128(data, ptr)
                    _, ptr = _read_u32_leb128(data, ptr)
                    if flags & 1:
                        _, ptr = _read_u32_leb128(data, ptr)
                elif kind == 2:
                    flags, ptr = _read_u32_leb128(data, ptr)
                    _, ptr = _read_u32_leb128(data, ptr)
                    if flags & 1:
                        _, ptr = _read_u32_leb128(data, ptr)
                elif kind == 3:
                    ptr += 2
        elif sec_id == 10:
            count, ptr = _read_u32_leb128(data, pos)
            for idx in range(count):
                fsize, ptr = _read_u32_leb128(data, ptr)
                code_bodies[idx + num_imported] = data[ptr : ptr + fsize]
                ptr += fsize
        elif sec_id == 11:
            count, ptr = _read_u32_leb128(data, pos)
            for _ in range(count):
                mode, ptr = _read_u32_leb128(data, ptr)
                addr: int = -1
                if mode == 0 and data[ptr] == 0x41:
                    ptr += 1
                    addr, ptr = _read_s32_leb128(data, ptr)
                    ptr += 1
                dlen, ptr = _read_u32_leb128(data, ptr)
                if addr >= 0 and dlen >= 16:
                    data_by_addr[addr] = data[ptr : ptr + 16]
                ptr += dlen
        elif sec_id == 0:
            nlen, ptr = _read_u32_leb128(data, pos)
            sname: str = data[ptr : ptr + nlen].decode("utf-8", errors="replace")
            ptr += nlen
            if sname == "name":
                while ptr < sec_end:
                    sub_id: int = data[ptr]
                    ptr += 1
                    sub_sz, ptr = _read_u32_leb128(data, ptr)
                    sub_end: int = ptr + sub_sz
                    if sub_id == 1:
                        fcount, ptr = _read_u32_leb128(data, ptr)
                        for _ in range(fcount):
                            fidx, ptr = _read_u32_leb128(data, ptr)
                            fnlen, ptr = _read_u32_leb128(data, ptr)
                            fname: str = data[ptr : ptr + fnlen].decode(
                                "utf-8", errors="replace"
                            )
                            ptr += fnlen
                            func_names[fidx] = fname
                    ptr = sub_end
        pos = sec_end

    name_to_idx: Dict[str, int] = {v: k for k, v in func_names.items()}
    stub_set: Set[int] = set()
    for start_name, end_name in UNUSED_FUNC_RANGES:
        if start_name in name_to_idx and end_name in name_to_idx:
            s_idx: int = name_to_idx[start_name]
            e_idx: int = name_to_idx[end_name]
            if s_idx <= e_idx:
                stub_set.update(range(s_idx, e_idx + 1))

    trans_range: Optional[Tuple[int, int]] = None
    if "Init_trans_big5" in name_to_idx and "Init_trans_utf_16_32" in name_to_idx:
        big5_struct = _first_i32_const(code_bodies[name_to_idx["Init_trans_big5"]])
        utf16_struct = _first_i32_const(
            code_bodies[name_to_idx["Init_trans_utf_16_32"]]
        )
        if (
            big5_struct in data_by_addr
            and utf16_struct in data_by_addr
        ):
            t_start: int = struct.unpack_from("<I", data_by_addr[big5_struct], 12)[0]
            t_end: int = struct.unpack_from("<I", data_by_addr[utf16_struct], 12)[0]
            if 0 < t_start < t_end:
                trans_range = (t_start, t_end)

    stub_body: bytes = b"\x00\x00\x0b"
    out = bytearray(data[:8])
    pos = 8
    while pos < len(data):
        sec_start: int = pos
        sec_id = data[pos]
        pos += 1
        size, pos = _read_u32_leb128(data, pos)
        sec_end = pos + size

        if sec_id in (0, 12):
            pos = sec_end
            continue

        if sec_id == 10 and stub_set:
            count, ptr = _read_u32_leb128(data, pos)
            new_code = bytearray(_encode_u32_leb128(count))
            for idx in range(count):
                fsize, ptr = _read_u32_leb128(data, ptr)
                fidx = idx + num_imported
                if fidx in stub_set:
                    new_code.extend(_encode_u32_leb128(len(stub_body)))
                    new_code.extend(stub_body)
                else:
                    new_code.extend(_encode_u32_leb128(fsize))
                    new_code.extend(data[ptr : ptr + fsize])
                ptr += fsize
            out.append(10)
            out.extend(_encode_u32_leb128(len(new_code)))
            out.extend(new_code)
        elif sec_id == 11 and trans_range is not None:
            t_lo, t_hi = trans_range
            count, ptr = _read_u32_leb128(data, pos)
            kept_segs: List[bytes] = []
            for _ in range(count):
                seg_start: int = ptr
                mode, ptr = _read_u32_leb128(data, ptr)
                addr = -1
                if mode == 0 and data[ptr] == 0x41:
                    ptr += 1
                    addr, ptr = _read_s32_leb128(data, ptr)
                    ptr += 1
                dlen, ptr = _read_u32_leb128(data, ptr)
                seg_end: int = ptr + dlen
                if not (t_lo <= addr and addr + dlen <= t_hi):
                    kept_segs.append(data[seg_start:seg_end])
                ptr = seg_end
            new_data = bytearray(_encode_u32_leb128(len(kept_segs)))
            for seg_bytes in kept_segs:
                new_data.extend(seg_bytes)
            out.append(11)
            out.extend(_encode_u32_leb128(len(new_data)))
            out.extend(new_data)
        else:
            out.extend(data[sec_start:sec_end])

        pos = sec_end

    with open(wasm_path, "wb") as wasm_file:
        wasm_file.write(out)

    wasm_opt_bin: Optional[str] = shutil.which("wasm-opt")
    if wasm_opt_bin:
        opt_tmp: str = f"{wasm_path}.opt"
        res = subprocess.run(
            [
                wasm_opt_bin,
                "-Oz",
                "--enable-bulk-memory",
                "--enable-nontrapping-float-to-int",
                "--enable-sign-ext",
                "--enable-mutable-globals",
                wasm_path,
                "-o",
                opt_tmp,
            ],
            check=False,
        )
        if res.returncode == 0 and os.path.isfile(opt_tmp):
            shutil.move(opt_tmp, wasm_path)
        elif os.path.exists(opt_tmp):
            os.remove(opt_tmp)


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
        pruned_usr_dir = build_pruned_usr_dir(
            prebuilt_usr_dir, os.path.join(tmp_dir, "pruned_usr")
        )
        pack_cmd = [
            "rbwasm",
            "pack",
            prebuilt_ruby_wasm,
            "--dir",
            f"{pruned_usr_dir}::/usr",
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

    optimize_wasm_binary(cdd_ruby_wasm_path)
