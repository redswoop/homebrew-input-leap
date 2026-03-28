class InputLeap < Formula
  desc "Open-source KVM software for sharing mouse & keyboard"
  homepage "https://github.com/input-leap/input-leap"
  url "https://github.com/input-leap/input-leap/archive/refs/tags/v3.0.3.tar.gz"
  sha256 "fbbf6e3f99abccfc3592939a039daf13f0e003dd33764c7c591d354b1a6c07eb"
  license "GPL-2.0-only"

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "openssl"
  depends_on :macos

  def install
    # Use Qt 6.6.3 (downloaded via aqtinstall) instead of Homebrew's Qt.
    # Homebrew's Qt 6.11+ causes input lag due to framework changes.
    qt_dir = buildpath/"qt-6.6.3"
    system "pip3", "install", "--quiet", "aqtinstall"
    system "python3", "-m", "aqt", "install-qt", "mac", "desktop", "6.6.3",
           "clang_64", "--outputdir", qt_dir
    qt_prefix = qt_dir/"6.6.3/macos"

    # Remove AGL framework references from Qt 6.6.3 — AGL is deprecated
    # and removed from modern macOS SDKs but Qt 6.6.3's prl files reference it.
    Dir[qt_prefix/"lib/**/*.prl"].each do |prl|
      inreplace prl, / -framework AGL/, ""
      inreplace prl, /;-framework;AGL/, ""
    end
    inreplace qt_prefix/"lib/cmake/Qt6/FindWrapOpenGL.cmake",
      /^\s*find_library\(WrapOpenGL_AGL.*?endif\(\)/m,
      "        # AGL removed — deprecated on modern macOS\n" \
      "        target_link_libraries(WrapOpenGL::WrapOpenGL INTERFACE ${__opengl_fw_path})"

    # Patch the bundle script to skip DMG generation
    inreplace "dist/macos/bundle/build_dist.sh.in",
      /^# Use macdeployqt.*^fi$/m,
      <<~SH.chomp
        info "Building app bundle"
        "$DEPLOYQT" InputLeap.app \\
        -executable="$B_INPUTLEAPC" \\
        -executable="$B_INPUTLEAPS" || exit 1
        success "Bundle created successfully"
      SH

    # Use macOS 15 SDK if available — the macOS 26 SDK has a CoreGraphics
    # regression that causes severe mouse input lag.
    sdk15 = "/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
    sdk15 = "/Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk" unless File.exist?(sdk15)

    args = std_cmake_args + %W[
      -G Ninja
      -DCMAKE_BUILD_TYPE=Release
      -DCMAKE_UNITY_BUILD=1
      -DCMAKE_PREFIX_PATH=#{qt_prefix}
      -DOPENSSL_ROOT_DIR=#{Formula["openssl"].opt_prefix}
      -DCMAKE_OSX_DEPLOYMENT_TARGET=14
      -DQT_DEFAULT_MAJOR_VERSION=6
      -DINPUTLEAP_BUILD_TESTS=OFF
      -DINPUTLEAP_BUILD_X11=OFF
      -DINPUTLEAP_BUILD_GULRAK_FILESYSTEM=0
    ]
    args << "-DCMAKE_OSX_SYSROOT=#{sdk15}" if File.exist?(sdk15)

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
