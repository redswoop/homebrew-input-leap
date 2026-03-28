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

  # Skip DMG generation in the macOS bundle script
  patch :DATA

  def install
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

__END__
diff --git a/dist/macos/bundle/build_dist.sh.in b/dist/macos/bundle/build_dist.sh.in
--- a/dist/macos/bundle/build_dist.sh.in
+++ b/dist/macos/bundle/build_dist.sh.in
@@ -36,16 +36,8 @@
 DEPLOYQT=@QT_DEPLOY_TOOL@

 # Use macdeployqt to include libraries and create dmg
-if [ "$B_BUILDTYPE" = "Release" ]; then
-    info "Building Release disk image (dmg)"
-    "$DEPLOYQT" InputLeap.app -dmg \
-    -executable="$B_INPUTLEAPC" \
-    -executable="$B_INPUTLEAPS" || exit 1
-    mv "InputLeap.dmg" "InputLeap-$B_VERSION.dmg" || exit 1
-    success "Created InputLeap-$B_VERSION.dmg"
-else
-    warn "Disk image (dmg) only created for Release builds"
-    info "Building debug bundle"
-    "$DEPLOYQT" InputLeap.app -no-strip \
-    -executable="$B_INPUTLEAPC" \
-    -executable="$B_INPUTLEAPS" || exit 1
-    success "Bundle created successfully"
-fi
+info "Building app bundle"
+"$DEPLOYQT" InputLeap.app \
+-executable="$B_INPUTLEAPC" \
+-executable="$B_INPUTLEAPS" || exit 1
+success "Bundle created successfully"
