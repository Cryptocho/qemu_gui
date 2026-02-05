pkgname=qemu_gui
pkgver=0.1.2
pkgrel=1
pkgdesc="A Flutter-based qemu manager"
arch=('x86_64')
url="https://github.com/Cryptocho/${pkgname}"
license=('MIT')
depends=('gtk3' 'libadwaita' 'glibc' 'qemu-full')
makedepends=('tar' 'xz')
source=("${pkgname}-${pkgver}.tar.xz::${url}/releases/download/${pkgver}/linux_x64.tar.xz")
sha256sums=('SKIP')  

package() {
  install -d "${pkgdir}/opt/${pkgname}"
  cp -r "${srcdir}/"* "${pkgdir}/opt/${pkgname}/"
  chmod +x "${pkgdir}/opt/${pkgname}/${pkgname}"
  install -d "${pkgdir}/usr/bin"
  cat > "${pkgdir}/usr/bin/${pkgname}" << EOF
#!/bin/bash
exec "/opt/${pkgname}/${pkgname}" "\$@"
EOF
  chmod +x "${pkgdir}/usr/bin/${pkgname}"

  install -d "${pkgdir}/usr/share/applications"
  echo "[Desktop Entry]
Version=0.1.2
Name=QEMU GUI
Comment=Flutter-based QEMU manager
Exec=/usr/bin/${pkgname} %U
Terminal=false
Type=Application
Categories=Utility;System;
MimeType=application/x-qemu;" > "${pkgdir}/usr/share/applications/qemu_gui.desktop"
}