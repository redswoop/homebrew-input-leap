class InputLeap < Formula
  desc "Open-source KVM software for sharing mouse & keyboard"
  homepage "https://github.com/input-leap/input-leap"
  url "https://github.com/input-leap/input-leap/archive/refs/tags/v3.0.3.tar.gz"
  sha256 "fbbf6e3f99abccfc3592939a039daf13f0e003dd33764c7c591d354b1a6c07eb"
  license "GPL-2.0-only"

  depends_on "cmake" => :build
  depends_on "pkg-config" => :build
  depends_on "qt"
  depends_on "openssl"
  depends_on :macos

  def install
    # Replace the entire DMG/debug conditional with a simple bundle build.
    # The original script has a Release branch (builds dmg) and else branch
    # (builds debug bundle). We just want a plain macdeployqt call.
    bundle_script = "dist/macos/bundle/build_dist.sh.in"
    inreplace bundle_script,
      /^# Use macdeployqt.*^fi$/m,
      <<~SH.chomp
        info "Building app bundle"
        "$DEPLOYQT" InputLeap.app \\
        -executable="$B_INPUTLEAPC" \\
        -executable="$B_INPUTLEAPS" || exit 1
        success "Bundle created successfully"
      SH

    args = std_cmake_args + %W[
      -DINPUTLEAP_BUILD_TESTS=OFF
      -DINPUTLEAP_BUILD_X11=OFF
      -DCMAKE_BUILD_TYPE=Release
      -DCMAKE_PREFIX_PATH=#{Formula["qt"].opt_prefix}
      -DOPENSSL_ROOT_DIR=#{Formula["openssl"].opt_prefix}
    ]

    system "cmake", "-S", ".", "-B", "build", *args
    system "cmake", "--build", "build"
    system "codesign", "--force", "--deep", "--sign", "-",
           "build/bundle/InputLeap.app"

    prefix.install "build/bundle/InputLeap.app"
    bin.install_symlink prefix/"InputLeap.app/Contents/MacOS/input-leapc"
    bin.install_symlink prefix/"InputLeap.app/Contents/MacOS/input-leaps"
  end

  def caveats
    <<~EOS
      InputLeap.app requires Accessibility permissions.
      Open the app once to register permissions:
        open #{prefix}/InputLeap.app

      If permissions get stuck, reset with:
        tccutil reset Accessibility input-leap
    EOS
  end
end
