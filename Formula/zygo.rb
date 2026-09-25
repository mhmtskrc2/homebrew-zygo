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
  version "0.1.1"
  license "Apache-2.0"

  on_macos do
    on_arm do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.1/zygo-aarch64-apple-darwin.tar.gz"
      sha256 "e90a40e1d23926513ce57b1c7ba87f2b20d4d5ceb50a29a410525537b867b19e"
    end
    on_intel do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.1/zygo-x86_64-apple-darwin.tar.gz"
      sha256 "9e192c68955ff8cef12795ef0eb40a345075f9f230680967ab7565e8cd306192"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.1/zygo-aarch64-unknown-linux-musl.tar.gz"
      sha256 "f250188432747ef9a6ad6649bcfff8283d43e838527459e4d3571dd0edc7b6c9"
    end
    on_intel do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.1/zygo-x86_64-unknown-linux-musl.tar.gz"
      sha256 "56586c2cdde85cc886932314abf715e27c787f7b76d55fa2570ab0c051741d51"
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
