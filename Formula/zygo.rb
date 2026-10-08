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
  version "0.1.7"
  license "Apache-2.0"

  on_macos do
    on_arm do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.7/zygo-aarch64-apple-darwin.tar.gz"
      sha256 "8ae0863b7b2fe9c19d34e2d98da7806a139014e8afc52e05c9531c55680ff652"
    end
    on_intel do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.7/zygo-x86_64-apple-darwin.tar.gz"
      sha256 "997657ad43a66a3196b6d7ee4d51d9eab903c6419f1b88b291b380a3ecd5264a"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.7/zygo-aarch64-unknown-linux-musl.tar.gz"
      sha256 "e6533fa7c74d4fcf766fd151668339672dc6ea3984f9d3759079b71dc13b08a5"
    end
    on_intel do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.7/zygo-x86_64-unknown-linux-musl.tar.gz"
      sha256 "aa554aaea62234b4d15a3f8470f3e2a174d10fe1c99f18b50f48e26c0e4d18fa"
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
