# 基线按底层组件分类

完整逐包/CVE/当前版/修复版/有无修复与官方来源见 findings.csv；重复数只用于解释，阻断扫描不去重或过滤。

| 镜像 | 类别 | 源组件 | 二进制包 | 发现条数 | 唯一ID | 无修复条数 |
|---|---|---|---|---|---|---|
| api | debian | util-linux | bsdutils, libblkid1, liblastlog2-2, libmount1, libsmartcols1, libuuid1, login, mount, util-linux | 36 | 4 | 36 |
| api | debian | acl | libacl1 | 1 | 1 | 1 |
| api | debian | ncurses | libncursesw6, libtinfo6, ncurses-base, ncurses-bin | 4 | 1 | 4 |
| api | debian | sqlite3 | libsqlite3-0 | 3 | 3 | 3 |
| api | debian | systemd | libsystemd0, libudev1 | 2 | 1 | 2 |
| api | debian | perl | perl-base | 1 | 1 | 1 |
| api | debian | zlib | zlib1g | 1 | 1 | 0 |
| api | python-pkg | cryptography | cryptography | 3 | 3 | 0 |
| web | alpine | brotli | brotli-libs | 1 | 1 | 0 |
| web | alpine | c-ares | c-ares | 1 | 1 | 0 |
| web | alpine | curl | curl, libcurl | 22 | 11 | 0 |
| web | alpine | openssl | libcrypto3, libssl3 | 14 | 7 | 0 |
| web | alpine | expat | libexpat | 11 | 11 | 0 |
| web | alpine | util-linux | libuuid | 6 | 6 | 0 |
| web | alpine | libxml2 | libxml2 | 1 | 1 | 0 |
| web | alpine | libxslt | libxslt | 3 | 3 | 0 |
| web | alpine | musl | musl, musl-utils | 4 | 2 | 0 |
| web | alpine | nghttp2 | nghttp2-libs | 1 | 1 | 0 |
| web | alpine | nginx | nginx | 14 | 14 | 0 |
| web | alpine | pcre2 | pcre2 | 4 | 4 | 0 |
| web | alpine | tiff | tiff | 1 | 1 | 0 |
| web | alpine | zlib | zlib | 2 | 2 | 0 |
