# The Homebrew formula, as a template: the digests are of archives that do not
# exist until a release is built, so `packaging/homebrew/render.sh` fills them
# in from what the release workflow just produced. A formula in the repository
# with placeholder hashes in it is a formula nobody can install.
#
# What makes this different from an ordinary Rust formula is the second file.
# On a Mac, `zygo` is a shim: every sandbox command is forwarded into a Linux
# VM that Zygo starts and manages, because sandboxes are Linux. The shim looks
# for the Linux build at `../share/zygo/zygo-linux-<arch>` relative to itself
# (`shim::linux_binary`), so the bottle has to carry one — installing the Mac
# binary alone installs something that cannot run a sandbox.
class Zygo < Formula
  desc "Daemonless, rootless warm sandbox runtime with Docker's ergonomics"
  homepage "https://github.com/mhmtskrc2/zygo"
  version "0.1.0"
  license "Apache-2.0"

  on_macos do
    on_arm do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.0/zygo-aarch64-apple-darwin.tar.gz"
      sha256 "ac3c675066442b5ad75550f406a2a835b92f9c4b67215141275c4d365bd23355"
    end
    on_intel do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.0/zygo-x86_64-apple-darwin.tar.gz"
      sha256 "eef2bea328ec31c564bb39b968fc4202ffe4b89f929b842b587272a3424d62cb"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.0/zygo-aarch64-unknown-linux-musl.tar.gz"
      sha256 "ca24d94e0a6dc27be52f93247a65643709f2e3e2c39bfea83c5938b57162a512"
    end
    on_intel do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.0/zygo-x86_64-unknown-linux-musl.tar.gz"
      sha256 "30f2ec12a42169d29699c28a19780d76413330c7661712c9ad4fdbb9fd9544cf"
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
      # `share/zygo`, which is the path `shim::linux_binary` builds from
      # `current_exe()/../share/zygo/zygo-linux-<arch>`.
      pkgshare.install Dir["share/zygo/zygo-linux-*"]
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
      into it costs ~100 ms per command, which hides the warm path from a Mac
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
      assert_predicate pkgshare/"zygo-linux-#{Hardware::CPU.arch}", :exist?,
                       "the Linux build the shim forwards into is missing"
    end
  end
end
