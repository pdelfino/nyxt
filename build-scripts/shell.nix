{ pkgs ? import <nixpkgs> {} } :
with builtins;
let inherit (pkgs) stdenv; in
with pkgs;
stdenv.mkDerivation {
  name = "next-dev";

  nativeBuildInputs = [
    pkgs.libressl.out
    pkgs.webkitgtk
    pkgs.sbcl
  ];

  # ++ (with pkgs.lispPackages; [
  #   prove-asdf
  #   trivial-features
  #   alexandria
  #   bordeaux-threads
  #   cl-css
  #   cl-json
  #   cl-markup
  #   cl-ppcre
  #   cl-ppcre-unicode
  #   cl-prevalence
  #   closer-mop
  #   dexador
  #   enchant
  #   iolib
  #   local-time
  #   log4cl
  #   mk-string-metrics
  #   parenscript
  #   quri
  #   serapeum
  #   str
  #   plump
  #   swank
  #   trivia
  #   trivial-clipboard
  #   trivial-features
  #   trivial-types
  #   unix-opts
  #   usocket
  # ]);

  buildInputs = [
    pkgs.enchant.out
    pkgs.gsettings-desktop-schemas.out
    pkgs.glib-networking.out
    pkgs.pango.out
    pkgs.cairo.out
    pkgs.gtkd.out
    pkgs.gdk-pixbuf.out
    pkgs.gtk3.out
    pkgs.glib.out
    pkgs.libfixposix.out
    pkgs.webkitgtk
  ] ++
  (with gst_all_1; [
      gst-plugins-base
      gst-plugins-good
      gst-plugins-bad
      gst-plugins-ugly
      gst-libav
  ]);

  propogatedBuildInputs = [
    pkgs.enchant.out
    pkgs.gsettings-desktop-schemas.out
    pkgs.glib-networking.out
    pkgs.pango.out
    pkgs.cairo.out
    pkgs.gtkd.out
    pkgs.gdk-pixbuf.out
    pkgs.gtk3.out
    pkgs.glib.out
    pkgs.libfixposix.out
    pkgs.webkitgtk
  ];

  LD_LIBRARY_PATH = with stdenv.lib; "${makeLibraryPath [ pkgs.gsettings-desktop-schemas.out pkgs.enchant.out pkgs.glib-networking.out pkgs.webkitgtk pkgs.gtk3 pkgs.pango.out pkgs.cairo.out pkgs.gdk-pixbuf.out pkgs.gtkd.out pkgs.glib.out pkgs.libfixposix.out pkgs.libressl.out ]};";

  GIO_MODULE_DIR = "${pkgs.glib-networking.out}/lib/gio/modules/";
  GIO_EXTRA_MODULES = "${pkgs.glib-networking.out}/lib/gio/modules/";
}
