# The Homebrew formula, as a template: the digests are of archives that do not
# exist until a release is built, so `packaging/homebrew/render.sh` fills them
# in from what the release workflow just produced. A formula in the repository
# with placeholder hashes in it is a formula nobody can install.
#
# What makes this different from an ordinary Rust formula is the two other
# files. On a Mac, `zygo` is a shim: every sandbox command is forwarded into a
# Linux VM that Zygo starts and manages, because sandboxes are Linux. The shim
# looks beside itself, in `../share/zygo/`, for the Linux build it runs there
# (`zygo-linux-<arch>`, `shim::linux_binary`) and for the Lima template the VM
# is created from (`lima.yaml`, `shim::template_path`), so the bottle has to
# carry both — installing the Mac binary alone installs something that cannot
# run a sandbox.
class Zygo < Formula
  desc "Daemonless, rootless warm sandbox runtime with Docker's ergonomics"
  homepage "https://github.com/mhmtskrc2/zygo"
  version "0.1.9"
  license "Apache-2.0"

  on_macos do
    on_arm do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.9/zygo-aarch64-apple-darwin.tar.gz"
      sha256 "189c4f89fd84e52e50f730163b12faab82bef6c3b1c83ed5aef8aaa3efe78fb5"
    end
    on_intel do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.9/zygo-x86_64-apple-darwin.tar.gz"
      sha256 "f9f0089b6d64c72c8e63fb2d9fcf40d159055d2ab69e6d948e3a16e5d594602e"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.9/zygo-aarch64-unknown-linux-musl.tar.gz"
      sha256 "5f01d92f16b027095fcb304cfd7926b871efe749bb884124179816c8090f9125"
    end
    on_intel do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.9/zygo-x86_64-unknown-linux-musl.tar.gz"
      sha256 "9b56cabf99f7034e7e521b65ae4f29b72d2c677b51e9b2672b2f6eeb571db58a"
    end
  end

  # What starts the VM. A dependency rather than a suggestion: without it the
  # first sandbox command on a Mac fails, and the only thing it can say is
  # "brew install lima".
  on_macos do
    depends_on "lima"
  end

  def install
    if OS.mac?
      bin.install "bin/zygo"
      # Beside the binary, where the shim looks. `pkgshare` is
      # `share/zygo`, which is the path `shim::linux_binary` and
      # `shim::template_path` build from `current_exe()/../share/zygo/`.
      pkgshare.install Dir["share/zygo/zygo-linux-*"], "share/zygo/lima.yaml"
    else
      bin.install "zygo"
    end
    generate_completions_from_executable(bin/"zygo", "completion", shells: [:bash, :zsh, :fish])
  end

  def caveats
    return unless OS.mac?

    <<~EOS
      Sandboxes are Linux. Every sandbox command is forwarded into a Linux VM
      that Zygo starts and manages on first use; the Linux build it runs there
      was installed alongside this one.

        zygo doctor        what this host can do, and the fix for what it cannot
        zygo run python:3.12-slim python3 -c 'print("hello")'

      The first command takes about a minute while the VM is created. Crossing
      into it costs about 22 ms per command, which hides the warm path from a Mac
      shell; it is still there through `zygo api` and the SDKs.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/zygo --version")

    # `doctor` exits non-zero on a host that cannot run sandboxes, which a
    # build machine usually cannot, so what is asserted is that it probed —
    # not that the answer was yes.
    output = shell_output("#{bin}/zygo doctor 2>&1", 1)
    assert_match(/kernel|namespace|cgroup|Lima|VM/i, output)

    if OS.mac?
      # Named as Rust names the architecture, which is what the shim asks for:
      # Homebrew calls Apple silicon `arm64`, the file says `aarch64`.
      arch = Hardware::CPU.arm? ? "aarch64" : "x86_64"
      assert_predicate pkgshare/"zygo-linux-#{arch}", :exist?,
                       "the Linux build the shim forwards into is missing"
      assert_predicate pkgshare/"lima.yaml", :exist?,
                       "the template the shim creates the Linux VM from is missing"
    end
  end
end
