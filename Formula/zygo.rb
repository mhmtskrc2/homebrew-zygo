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
  version "0.1.5"
  license "Apache-2.0"

  on_macos do
    on_arm do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.5/zygo-aarch64-apple-darwin.tar.gz"
      sha256 "65c70da2aac7e4836a201e8792007df7f404e81df8ec003b4d74ac436979d92e"
    end
    on_intel do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.5/zygo-x86_64-apple-darwin.tar.gz"
      sha256 "30f228580d971bc4bbad982a611f012ac9e72086f046bae9294eedac01cf263d"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.5/zygo-aarch64-unknown-linux-musl.tar.gz"
      sha256 "84506d148f42ca4a9d1b19c6eb1b3bf12b43807e04156f3bad6a92b546475fbf"
    end
    on_intel do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.5/zygo-x86_64-unknown-linux-musl.tar.gz"
      sha256 "4644c172dd48fe3313964998687468dd383cac1ec8ee913d9a2df632e323437c"
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
      assert_predicate pkgshare/"zygo-linux-#{Hardware::CPU.arch}", :exist?,
                       "the Linux build the shim forwards into is missing"
    end
  end
end
