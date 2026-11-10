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
  version "0.1.10"
  license "Apache-2.0"

  on_macos do
    on_arm do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.10/zygo-aarch64-apple-darwin.tar.gz"
      sha256 "b427b153f7646d5230cfbfbad8b3c9bf727a5e6e029e5a4d89a56c919b124c3e"
    end
    on_intel do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.10/zygo-x86_64-apple-darwin.tar.gz"
      sha256 "35648d4a37424dd8655238b23f955fcf88e7b6dd2e5536ca5975df8c33c76951"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.10/zygo-aarch64-unknown-linux-musl.tar.gz"
      sha256 "2960857000c9489762c45e418e94a2dda33e175e34c89466ee2e395527ab5556"
    end
    on_intel do
      url "https://github.com/mhmtskrc2/zygo/releases/download/v0.1.10/zygo-x86_64-unknown-linux-musl.tar.gz"
      sha256 "6064042f6dd6c7c8c2bfe86a9ff60ec2336b8b305da607aad21a6f22beab9475"
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
