# 第三方源码与许可证来源

核验日期：2026-11-23。版本来自本项目的 `requirements-lock.txt`；包信息和源码下载地址来自 PyPI 官方版本 JSON 接口。以下许可证列只转录上游元数据声明，不替代源码包中的完整许可证、例外条款或版权声明。

## 范围与保留方式

- 本项目自有源码使用 `GPL-3.0-or-later`，完整文本见 [`LICENSE`](../LICENSE)。第三方组件保留各自条款。
- 此清单覆盖锁定的 Python 构建环境。哪些包实际进入某次可执行产物，以该产物及 `Contents/Resources/Licenses` 为准。
- 分发 App 时保留随包许可证、`THIRD_PARTY_NOTICES.txt` 和此版本的源码来源说明；分发对应项目源码时保留 `requirements-lock.txt` 与构建脚本。
- 许可证元数据未明确识别时，明确标为“以上游随附许可证为准”，不推定为某一种许可证。

## CPython 与坐标转换

本次已有 macOS 运行包使用 Python **3.14.7**。项目未修改 CPython 源码；PyInstaller 负责选择和打包运行模块，并可能调整二进制装载路径。重新构建使用其他 Python 版本时，应携带该版本对应的许可证。

- CPython 官方版本源码：[v3.14.7](https://github.com/python/cpython/tree/v3.14.7)。
- 该 tag 的完整许可证：[官方 LICENSE](https://raw.githubusercontent.com/python/cpython/v3.14.7/LICENSE)，原样副本见 [`Licenses/Python-3.14.7-LICENSE.txt`](../Licenses/Python-3.14.7-LICENSE.txt)。
- 所携带许可证文件 SHA-256：`b0e25a78cffb43f4d92de8b61ccfa1f1f98ecbc22330b54b5251e7b6ba010231`。
- GCJ-02/WGS84 转换公式参考 [googollee/eviltransform](https://github.com/googollee/eviltransform)。原始适配未记录上游 commit；随附 BSD-2-Clause 版权及免责文本见 [`Licenses/eviltransform.txt`](../Licenses/eviltransform.txt)。

## GPL/LGPL 元数据声明的组件与对应版本源码

下列条目根据官方版本元数据筛选，包括 PyInstaller 的特殊例外声明。许可证范围和例外应阅读每个源代码包里的原文。下载地址来自该版本的 `sdist` 记录；校验值也来自同一 PyPI 官方记录。

### ipsw-parser 1.9.2

上游元数据声明：**GNU General Public License v3 or later (GPLv3+)**。来源字段：`classifiers`；[核验元数据](https://pypi.org/pypi/ipsw-parser/1.9.2/json)。

- 源码包：[ipsw_parser-1.9.2.tar.gz](https://files.pythonhosted.org/packages/2c/7f/6785979fc22745f6c5f5ee552ef3d0d76a8344cf8129e97d6f6c390f38fb/ipsw_parser-1.9.2.tar.gz)
- SHA-256：`b9b6bcaab2b49691f6ff90aa6703a4e2be7e8ff8f85534e7ba65bb8565dd0db9`

### opack2 0.2.0

上游元数据声明：**GNU General Public License v3 or later (GPLv3+)**。来源字段：`classifiers`；[核验元数据](https://pypi.org/pypi/opack2/0.2.0/json)。

- 源码包：[opack2-0.2.0.tar.gz](https://files.pythonhosted.org/packages/22/02/f79f07f275aadb157361cc977629975ee936572140ce3a33715dbd6fc08e/opack2-0.2.0.tar.gz)
- SHA-256：`997ab3fe4540610f10c8072a34fa69246c229b5e2bbf3f383cbe6f2884cbf1a4`

### pmd-net-addr 0.0.3

上游元数据声明：**GPL-3.0-or-later**。来源字段：`license_expression`；[核验元数据](https://pypi.org/pypi/pmd-net-addr/0.0.3/json)。

- 源码包：[pmd_net_addr-0.0.3.tar.gz](https://files.pythonhosted.org/packages/ce/bb/e24ffb9af4243050b54fbaf08393879456f1bd98996b66c6df509106ad2b/pmd_net_addr-0.0.3.tar.gz)
- SHA-256：`1b0fcb3b77f30076237360eb4cf0243483278a2650fd4a194985cc69b1de07e5`

### pmd-net-proto 0.0.3

上游元数据声明：**GPL-3.0-or-later**。来源字段：`license_expression`；[核验元数据](https://pypi.org/pypi/pmd-net-proto/0.0.3/json)。

- 源码包：[pmd_net_proto-0.0.3.tar.gz](https://files.pythonhosted.org/packages/59/ec/eed1b9570cec3e30b993dee84fa5d16be3399189ffce8c0b46373727d20e/pmd_net_proto-0.0.3.tar.gz)
- SHA-256：`e23d7d68cd13399ff2bf0613f9756e221ead6fd54010cf85186c2ab650631cd7`

### pmd-pytcp 0.3.9

上游元数据声明：**GPL-3.0-or-later**。来源字段：`license_expression`；[核验元数据](https://pypi.org/pypi/pmd-pytcp/0.3.9/json)。

- 源码包：[pmd_pytcp-0.3.9.tar.gz](https://files.pythonhosted.org/packages/f0/2f/829508adca9d96ccb07030dbeb661b5748a1e234e0873b365341067fa83b/pmd_pytcp-0.3.9.tar.gz)
- SHA-256：`6429509ac8ba45ba17dee12e14c3d06d7bbadd5c12f0d6d4a961bf4bafe19ca5`

### pygnuutils 0.1.1

上游元数据声明：**GNU General Public License v3 or later (GPLv3+)**。来源字段：`classifiers`；[核验元数据](https://pypi.org/pypi/pygnuutils/0.1.1/json)。

- 源码包：[pygnuutils-0.1.1.tar.gz](https://files.pythonhosted.org/packages/03/20/6a828fe03d6586241b824ee06c7da854ea351716006a62fd2548eaa5710b/pygnuutils-0.1.1.tar.gz)
- SHA-256：`51ab4f27deb59102b7a04192f7585ff2b3a9de03739982f0b19d3cd4d16bea76`

### pyinstaller 6.22.3

上游元数据声明：**GPLv2-or-later with a special exception which allows to use PyInstaller to build and distribute non-free programs (including commercial ones)**。来源字段：`license`；[核验元数据](https://pypi.org/pypi/pyinstaller/6.22.3/json)。

- 源码包：[pyinstaller-6.22.3.tar.gz](https://files.pythonhosted.org/packages/63/41/f90302845945abd4ed647933ff5ee7c6ac93983187be67f897b6cb613331/pyinstaller-6.22.3.tar.gz)
- SHA-256：`05eb2f5615503e72939a7224d68b4aff572c6b0438ee4a17d0a4b481f399362d`

### pyinstaller-hooks-contrib 2026.10

上游元数据声明：**Apache Software License; GNU General Public License v2 (GPLv2)**。来源字段：`classifiers`；[核验元数据](https://pypi.org/pypi/pyinstaller-hooks-contrib/2026.10/json)。

- 源码包：[pyinstaller_hooks_contrib-2026.10.tar.gz](https://files.pythonhosted.org/packages/45/87/9a32062fb1296b43e866ec78313f887e12b09e6bc344c694647856bcd907/pyinstaller_hooks_contrib-2026.10.tar.gz)
- SHA-256：`7e906c659522e592a1680f30f709ffb6333277141a695926aa7190592205c5e3`

### pyiosbackup 0.2.4

上游元数据声明：**GNU General Public License v3 or later (GPLv3+)**。来源字段：`classifiers`；[核验元数据](https://pypi.org/pypi/pyiosbackup/0.2.4/json)。

- 源码包：[pyiosbackup-0.2.4.tar.gz](https://files.pythonhosted.org/packages/46/ab/c7c3caf6785ced43d02c8c37be3c84720c40d6a9b237eb2ff560af4114e1/pyiosbackup-0.2.4.tar.gz)
- SHA-256：`10b4d2a11c9bedc93a5467cad3addbe18bc2dc434156920e7223226ed4d0beb7`

### pylzss 0.3.9

上游元数据声明：**LGPL-3.0-only**。来源字段：`license`；[核验元数据](https://pypi.org/pypi/pylzss/0.3.9/json)。

- 源码包：[pylzss-0.3.9.tar.gz](https://files.pythonhosted.org/packages/95/fa/3f003112e5e183c70304e2c15fe4517621026d3b71e61088d4ed38ecdce4/pylzss-0.3.9.tar.gz)
- SHA-256：`4a8c9922deceab516c4139627690dbffa59aa7b336c9a7364a8c48154790e86b`

### pymobiledevice3 11.63.1

上游元数据声明：**GPL-3.0-or-later**。来源字段：`license_expression`；[核验元数据](https://pypi.org/pypi/pymobiledevice3/11.63.1/json)。

- 源码包：[pymobiledevice3-11.63.1.tar.gz](https://files.pythonhosted.org/packages/f4/d1/64fdff98419fadf520fcdcea2a84ccd57968db247cd915213da87e5a1743/pymobiledevice3-11.63.1.tar.gz)
- SHA-256：`b0202ed2511146e5feb189fac6949d5adc394e62b7ac225f11fcaf10e347bb09`

### pytun-pmd3 3.0.3

上游元数据声明：**GNU General Public License v3 or later (GPLv3+)**。来源字段：`classifiers`；[核验元数据](https://pypi.org/pypi/pytun-pmd3/3.0.3/json)。

- 源码包：[pytun_pmd3-3.0.3.tar.gz](https://files.pythonhosted.org/packages/5e/8a/6e73c70ddf5fdf9cf359cdc458f38cf795c4a653c870a4a49c8768e5db86/pytun_pmd3-3.0.3.tar.gz)
- SHA-256：`7fa822092139b4b77e08fad9233dbd4a6fcca2cf2423b0775db962ca5e87a017`

### remotezip2 0.0.2

上游元数据声明：**GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007**。来源字段：`license`；[核验元数据](https://pypi.org/pypi/remotezip2/0.0.2/json)。

- 源码包：[remotezip2-0.0.2.tar.gz](https://files.pythonhosted.org/packages/3f/47/94335875a4d5339f64943c1a68900f59a91ad987ab8fcd8e5201839e7cc5/remotezip2-0.0.2.tar.gz)
- SHA-256：`db38fb14d0c297af6da8756808bb25f9d3b2c23c7639a14f7a74794b2fc9a261`

## 完整锁定环境的来源索引

全部 **96** 个锁定版本均已从 PyPI 官方元数据核验，且都有该版本的源码分发包（sdist）。以下简表保留元数据入口，方便核对完整项目描述、主页和许可证声明。

| 包 | 版本 | 上游许可证元数据声明 | 版本元数据 | 对应版本源码 |
| --- | --- | --- | --- | --- |
| aiofiles | 25.1.0 | Apache-2.0 | [PyPI JSON](https://pypi.org/pypi/aiofiles/25.1.0/json) | [aiofiles-25.1.0.tar.gz](https://files.pythonhosted.org/packages/41/c3/534eac40372d8ee36ef40df62ec129bee4fdb5ad9706e58a29be53b2c970/aiofiles-25.1.0.tar.gz) |
| altgraph | 0.17.5 | MIT | [PyPI JSON](https://pypi.org/pypi/altgraph/0.17.5/json) | [altgraph-0.17.5.tar.gz](https://files.pythonhosted.org/packages/7e/f8/97fdf103f38fed6792a1601dbc16cc8aac56e7459a9fff08c812d8ae177a/altgraph-0.17.5.tar.gz) |
| annotated-doc | 0.0.7 | MIT | [PyPI JSON](https://pypi.org/pypi/annotated-doc/0.0.7/json) | [annotated_doc-0.0.7.tar.gz](https://files.pythonhosted.org/packages/0b/7d/bdbf3062e5dae31da8b3de1e3269110beb93d268df4a7f6d22b167c6cee0/annotated_doc-0.0.7.tar.gz) |
| annotated-types | 0.8.0 | MIT | [PyPI JSON](https://pypi.org/pypi/annotated-types/0.8.0/json) | [annotated_types-0.8.0.tar.gz](https://files.pythonhosted.org/packages/5f/56/a8120250d128bed162cd73c76d45f6ef9991f3e068f62a8ee060afa3104a/annotated_types-0.8.0.tar.gz) |
| ansilogs | 1.2.0 | MIT License | [PyPI JSON](https://pypi.org/pypi/ansilogs/1.2.0/json) | [ansilogs-1.2.0.tar.gz](https://files.pythonhosted.org/packages/57/22/bd196aa83bca307de047b0cc96fb66ebf946bbaec3052dddedea28449cd6/ansilogs-1.2.0.tar.gz) |
| anyio | 4.16.0 | MIT | [PyPI JSON](https://pypi.org/pypi/anyio/4.16.0/json) | [anyio-4.16.0.tar.gz](https://files.pythonhosted.org/packages/a1/98/7e457a3b014976887a050561955c0b76e1e7e2d6e27b78ecef2ef80518f2/anyio-4.16.0.tar.gz) |
| apple-compress | 0.2.3 | 未明确识别；以上游随附许可证为准 | [PyPI JSON](https://pypi.org/pypi/apple-compress/0.2.3/json) | [apple_compress-0.2.3.tar.gz](https://files.pythonhosted.org/packages/91/14/cdb0bdb6147a019d2d8a1e144910c6a8d257d0e58f63bbd105bda0fce7dc/apple_compress-0.2.3.tar.gz) |
| apple-symbols | 0.0.2 | MIT | [PyPI JSON](https://pypi.org/pypi/apple-symbols/0.0.2/json) | [apple_symbols-0.0.2.tar.gz](https://files.pythonhosted.org/packages/e2/2d/34dad6a661ffc823f8528e61d515eafc6b0f0047a1dfb86a03c74baf755b/apple_symbols-0.0.2.tar.gz) |
| arrow | 1.4.0 | Apache Software License | [PyPI JSON](https://pypi.org/pypi/arrow/1.4.0/json) | [arrow-1.4.0.tar.gz](https://files.pythonhosted.org/packages/b9/33/032cdc44182491aa708d06a68b62434140d8c50820a087fac7af37703357/arrow-1.4.0.tar.gz) |
| ASGIMiddlewareStaticFile | 0.7.0 | 未明确识别；以上游随附许可证为准 | [PyPI JSON](https://pypi.org/pypi/ASGIMiddlewareStaticFile/0.7.0/json) | [asgimiddlewarestaticfile-0.7.0.tar.gz](https://files.pythonhosted.org/packages/d7/25/14ec3488ee466dd2b3c63e3cdb1f9b032d90c0c9d65ca68d25c59b74bc22/asgimiddlewarestaticfile-0.7.0.tar.gz) |
| asgiref | 3.13.0 | BSD-3-Clause | [PyPI JSON](https://pypi.org/pypi/asgiref/3.13.0/json) | [asgiref-3.13.0.tar.gz](https://files.pythonhosted.org/packages/6b/90/f5fce14e95fccf53b58e8e2c47cd84d40d105d64073ae1ac75166db150e0/asgiref-3.13.0.tar.gz) |
| ASGIWebDAV | 2.3.0 | 未明确识别；以上游随附许可证为准 | [PyPI JSON](https://pypi.org/pypi/ASGIWebDAV/2.3.0/json) | [asgiwebdav-2.3.0.tar.gz](https://files.pythonhosted.org/packages/5b/34/41bbfc7357641127da20ea11d1e2f919b64f28a3ba126db87ffbcfea32b6/asgiwebdav-2.3.0.tar.gz) |
| asn1 | 2.8.0 | BSD | [PyPI JSON](https://pypi.org/pypi/asn1/2.8.0/json) | [asn1-2.8.0.tar.gz](https://files.pythonhosted.org/packages/00/35/9d0709bf09340ddb1796dfc52d1b1ef2f18e690b5cbf32b7be02c702532c/asn1-2.8.0.tar.gz) |
| asttokens | 3.0.2 | Apache 2.0 | [PyPI JSON](https://pypi.org/pypi/asttokens/3.0.2/json) | [asttokens-3.0.2.tar.gz](https://files.pythonhosted.org/packages/25/1e/faf0f247f6f881b98fc4d6d07e14085cb89d13665084e6d6ac1dc2c03d0b/asttokens-3.0.2.tar.gz) |
| bpylist2 | 4.1.1 | MIT | [PyPI JSON](https://pypi.org/pypi/bpylist2/4.1.1/json) | [bpylist2-4.1.1.tar.gz](https://files.pythonhosted.org/packages/ca/34/eb90ff6be953f6e4df08d4e8c0b761bea144242b6d711e922113411cc631/bpylist2-4.1.1.tar.gz) |
| bytestruct | 0.2.0 | MIT | [PyPI JSON](https://pypi.org/pypi/bytestruct/0.2.0/json) | [bytestruct-0.2.0.tar.gz](https://files.pythonhosted.org/packages/1b/e4/37acaf4c2217e117c42163159204d749a318cb11dd58a5c39e37c482e720/bytestruct-0.2.0.tar.gz) |
| certifi | 2026.11.20 | MPL-2.0 | [PyPI JSON](https://pypi.org/pypi/certifi/2026.11.20/json) | [certifi-2026.11.20.tar.gz](https://files.pythonhosted.org/packages/51/33/4cd27639502f010084bcef7a2036391dd637439901341ce1a530f36f6e51/certifi-2026.11.20.tar.gz) |
| cffi | 2.1.1 | MIT-0 | [PyPI JSON](https://pypi.org/pypi/cffi/2.1.1/json) | [cffi-2.1.1.tar.gz](https://files.pythonhosted.org/packages/9e/ef/008a1939e372c06329a3fce4279c02f328488f3526744906eeec3da7ad5f/cffi-2.1.1.tar.gz) |
| chardet | 7.7.0 | 0BSD | [PyPI JSON](https://pypi.org/pypi/chardet/7.7.0/json) | [chardet-7.7.0.tar.gz](https://files.pythonhosted.org/packages/47/92/3d893ac5d338b9a9af34c5b517d77492dcea8a10254254eead4215a96f3f/chardet-7.7.0.tar.gz) |
| charset-normalizer | 3.5.3 | MIT | [PyPI JSON](https://pypi.org/pypi/charset-normalizer/3.5.3/json) | [charset_normalizer-3.5.3.tar.gz](https://files.pythonhosted.org/packages/c2/c3/cae6d3bdefd96a941ffc247c714ac4babc488a69012e11c058f6c17c6c47/charset_normalizer-3.5.3.tar.gz) |
| click | 8.5.1 | BSD-3-Clause | [PyPI JSON](https://pypi.org/pypi/click/8.5.1/json) | [click-8.5.1.tar.gz](https://files.pythonhosted.org/packages/45/37/edbf1b0707709013c0cf2e8317e03d97ed29bf4cac709fe328904ae92a38/click-8.5.1.tar.gz) |
| construct | 2.10.70 | MIT | [PyPI JSON](https://pypi.org/pypi/construct/2.10.70/json) | [construct-2.10.70.tar.gz](https://files.pythonhosted.org/packages/02/77/8c84b98eca70d245a2a956452f21d57930d22ab88cbeed9290ca630cf03f/construct-2.10.70.tar.gz) |
| cryptography | 50.0.2 | Apache-2.0 OR BSD-3-Clause | [PyPI JSON](https://pypi.org/pypi/cryptography/50.0.2/json) | [cryptography-50.0.2.tar.gz](https://files.pythonhosted.org/packages/9d/af/182eb91b0df3fe75c4d9f26fe70684569566745f6ba7e5c9c73a862c5252/cryptography-50.0.2.tar.gz) |
| daemonize | 2.5.0 | MIT | [PyPI JSON](https://pypi.org/pypi/daemonize/2.5.0/json) | [daemonize-2.5.0.tar.gz](https://files.pythonhosted.org/packages/8c/20/96f7dbc23812cfe4cf479c87af3e4305d0d115fd1fffec32ddeee7b9c82b/daemonize-2.5.0.tar.gz) |
| dataclass-wizard | 1.0.0 | Apache Software License | [PyPI JSON](https://pypi.org/pypi/dataclass-wizard/1.0.0/json) | [dataclass_wizard-1.0.0.tar.gz](https://files.pythonhosted.org/packages/b1/9d/465deff762411b97cc37fdd475402484724f695af042fa89ff221f725172/dataclass_wizard-1.0.0.tar.gz) |
| defusedxml | 0.7.1 | PSFL | [PyPI JSON](https://pypi.org/pypi/defusedxml/0.7.1/json) | [defusedxml-0.7.1.tar.gz](https://files.pythonhosted.org/packages/0f/d5/c66da9b79e5bdb124974bfe172b4daf3c984ebd9c2a06e2b8a4dc7331c72/defusedxml-0.7.1.tar.gz) |
| developer-disk-image | 0.3.1 | MIT | [PyPI JSON](https://pypi.org/pypi/developer_disk_image/0.3.1/json) | [developer_disk_image-0.3.1.tar.gz](https://files.pythonhosted.org/packages/4b/99/a4f7eefa2cd6fb57b2a467ea3097120e5ffd56a0108c62d56796a58fa593/developer_disk_image-0.3.1.tar.gz) |
| enum-compat | 0.0.3 | MIT | [PyPI JSON](https://pypi.org/pypi/enum-compat/0.0.3/json) | [enum-compat-0.0.3.tar.gz](https://files.pythonhosted.org/packages/41/46/8ed2368976d934652d8f33f1fdd86f5580fab45e890c90a848e83097a093/enum-compat-0.0.3.tar.gz) |
| executing | 2.3.0 | MIT | [PyPI JSON](https://pypi.org/pypi/executing/2.3.0/json) | [executing-2.3.0.tar.gz](https://files.pythonhosted.org/packages/52/92/8a611141e42930c0f194f7504063ab87dfe970cf1a5af28e7703df448734/executing-2.3.0.tar.gz) |
| fastapi | 0.165.0 | MIT | [PyPI JSON](https://pypi.org/pypi/fastapi/0.165.0/json) | [fastapi-0.165.0.tar.gz](https://files.pythonhosted.org/packages/27/f9/e7820ef181026fea100bde02d811445bf8e883362d7092b6928767147056/fastapi-0.165.0.tar.gz) |
| h11 | 0.16.0 | MIT | [PyPI JSON](https://pypi.org/pypi/h11/0.16.0/json) | [h11-0.16.0.tar.gz](https://files.pythonhosted.org/packages/01/ee/02a2c011bdab74c6fb3c75474d40b3052059d95df7e73351460c8588d963/h11-0.16.0.tar.gz) |
| hyperframe | 6.1.0 | MIT License | [PyPI JSON](https://pypi.org/pypi/hyperframe/6.1.0/json) | [hyperframe-6.1.0.tar.gz](https://files.pythonhosted.org/packages/02/e7/94f8232d4a74cc99514c13a9f995811485a6903d48e5d952771ef6322e30/hyperframe-6.1.0.tar.gz) |
| idna | 3.20 | BSD-3-Clause | [PyPI JSON](https://pypi.org/pypi/idna/3.20/json) | [idna-3.20.tar.gz](https://files.pythonhosted.org/packages/f5/08/8eea9d4b8302028f3abb2c0813953f7aec26d33b7a8960ed760e65ff29fa/idna-3.20.tar.gz) |
| ifaddr | 0.2.0 | MIT | [PyPI JSON](https://pypi.org/pypi/ifaddr/0.2.0/json) | [ifaddr-0.2.0.tar.gz](https://files.pythonhosted.org/packages/e8/ac/fb4c578f4a3256561548cd825646680edcadb9440f3f68add95ade1eb791/ifaddr-0.2.0.tar.gz) |
| ioregistry | 0.0.7 | MIT | [PyPI JSON](https://pypi.org/pypi/ioregistry/0.0.7/json) | [ioregistry-0.0.7.tar.gz](https://files.pythonhosted.org/packages/08/eb/f15fca903def10fc5e5930b53fd4739c450db9eef75451b51c94d59f6355/ioregistry-0.0.7.tar.gz) |
| ipsw-parser | 1.9.2 | GNU General Public License v3 or later (GPLv3+) | [PyPI JSON](https://pypi.org/pypi/ipsw-parser/1.9.2/json) | [ipsw_parser-1.9.2.tar.gz](https://files.pythonhosted.org/packages/2c/7f/6785979fc22745f6c5f5ee552ef3d0d76a8344cf8129e97d6f6c390f38fb/ipsw_parser-1.9.2.tar.gz) |
| ipython | 9.18.1 | BSD-3-Clause | [PyPI JSON](https://pypi.org/pypi/ipython/9.18.1/json) | [ipython-9.18.1.tar.gz](https://files.pythonhosted.org/packages/38/04/0d945c72d5b77527273ecb4c66aa2436de7a3b3bbe3da345bf053232b886/ipython-9.18.1.tar.gz) |
| ipython-pygments-lexers | 1.1.1 | BSD License | [PyPI JSON](https://pypi.org/pypi/ipython_pygments_lexers/1.1.1/json) | [ipython_pygments_lexers-1.1.1.tar.gz](https://files.pythonhosted.org/packages/ef/4c/5dd1d8af08107f88c7f741ead7a40854b8ac24ddf9ae850afbcf698aa552/ipython_pygments_lexers-1.1.1.tar.gz) |
| jedi | 0.20.1 | MIT | [PyPI JSON](https://pypi.org/pypi/jedi/0.20.1/json) | [jedi-0.20.1.tar.gz](https://files.pythonhosted.org/packages/a3/a4/4692ecd7fa700ac1066b1c1f6cadef60aa2e01e5e364710235137d823e0a/jedi-0.20.1.tar.gz) |
| loguru | 0.7.3 | MIT License | [PyPI JSON](https://pypi.org/pypi/loguru/0.7.3/json) | [loguru-0.7.3.tar.gz](https://files.pythonhosted.org/packages/3a/05/a1dae3dffd1116099471c643b8924f5aa6524411dc6c63fdae648c4f1aca/loguru-0.7.3.tar.gz) |
| macholib | 1.16.4 | MIT | [PyPI JSON](https://pypi.org/pypi/macholib/1.16.4/json) | [macholib-1.16.4.tar.gz](https://files.pythonhosted.org/packages/10/2f/97589876ea967487978071c9042518d28b958d87b17dceb7cdc1d881f963/macholib-1.16.4.tar.gz) |
| markdown-it-py | 4.3.0 | MIT License | [PyPI JSON](https://pypi.org/pypi/markdown-it-py/4.3.0/json) | [markdown_it_py-4.3.0.tar.gz](https://files.pythonhosted.org/packages/16/fc/cee2c45553c9a9bf77d8b0c391560c556d7ed756b1f0bb35eb5d48db09ea/markdown_it_py-4.3.0.tar.gz) |
| matplotlib-inline | 0.2.2 | BSD-3-Clause | [PyPI JSON](https://pypi.org/pypi/matplotlib-inline/0.2.2/json) | [matplotlib_inline-0.2.2.tar.gz](https://files.pythonhosted.org/packages/bd/c0/9f7c9a46090390368a4d7bcb76bb87a4a36c421e4c0792cdb53486ffac7a/matplotlib_inline-0.2.2.tar.gz) |
| mdurl | 0.1.2 | MIT License | [PyPI JSON](https://pypi.org/pypi/mdurl/0.1.2/json) | [mdurl-0.1.2.tar.gz](https://files.pythonhosted.org/packages/d6/54/cfe61301667036ec958cb99bd3efefba235e65cdeb9c84d24a8293ba1d90/mdurl-0.1.2.tar.gz) |
| opack2 | 0.2.0 | GNU General Public License v3 or later (GPLv3+) | [PyPI JSON](https://pypi.org/pypi/opack2/0.2.0/json) | [opack2-0.2.0.tar.gz](https://files.pythonhosted.org/packages/22/02/f79f07f275aadb157361cc977629975ee936572140ce3a33715dbd6fc08e/opack2-0.2.0.tar.gz) |
| opentelemetry-api | 1.45.2 | Apache-2.0 | [PyPI JSON](https://pypi.org/pypi/opentelemetry-api/1.45.2/json) | [opentelemetry_api-1.45.2.tar.gz](https://files.pythonhosted.org/packages/19/14/cf3a6b6448849656e1e5f4e2101f3988dc6789724050096aba1bc5ccf592/opentelemetry_api-1.45.2.tar.gz) |
| packaging | 26.3 | Apache-2.0 OR BSD-2-Clause | [PyPI JSON](https://pypi.org/pypi/packaging/26.3/json) | [packaging-26.3.tar.gz](https://files.pythonhosted.org/packages/7d/fa/3944b40b07da9ce895c0e6303a5ab7d53da063554f534556b134a54d6093/packaging-26.3.tar.gz) |
| parso | 0.8.7 | MIT | [PyPI JSON](https://pypi.org/pypi/parso/0.8.7/json) | [parso-0.8.7.tar.gz](https://files.pythonhosted.org/packages/30/4b/90c937815137d43ce71ba043cd3566221e9df6b9c805f24b5d138c9d40a7/parso-0.8.7.tar.gz) |
| pexpect | 4.9.0 | ISC license | [PyPI JSON](https://pypi.org/pypi/pexpect/4.9.0/json) | [pexpect-4.9.0.tar.gz](https://files.pythonhosted.org/packages/42/92/cc564bf6381ff43ce1f4d06852fc19a2f11d180f23dc32d9588bee2f149d/pexpect-4.9.0.tar.gz) |
| pillow | 13.0.0 | MIT-CMU | [PyPI JSON](https://pypi.org/pypi/pillow/13.0.0/json) | [pillow-13.0.0.tar.gz](https://files.pythonhosted.org/packages/ce/a4/9cc30690a394a8305e8be4c9036aa16d0dfddadd09079860b582f562496d/pillow-13.0.0.tar.gz) |
| pmd-net-addr | 0.0.3 | GPL-3.0-or-later | [PyPI JSON](https://pypi.org/pypi/pmd-net-addr/0.0.3/json) | [pmd_net_addr-0.0.3.tar.gz](https://files.pythonhosted.org/packages/ce/bb/e24ffb9af4243050b54fbaf08393879456f1bd98996b66c6df509106ad2b/pmd_net_addr-0.0.3.tar.gz) |
| pmd-net-proto | 0.0.3 | GPL-3.0-or-later | [PyPI JSON](https://pypi.org/pypi/pmd-net-proto/0.0.3/json) | [pmd_net_proto-0.0.3.tar.gz](https://files.pythonhosted.org/packages/59/ec/eed1b9570cec3e30b993dee84fa5d16be3399189ffce8c0b46373727d20e/pmd_net_proto-0.0.3.tar.gz) |
| pmd-pytcp | 0.3.9 | GPL-3.0-or-later | [PyPI JSON](https://pypi.org/pypi/pmd-pytcp/0.3.9/json) | [pmd_pytcp-0.3.9.tar.gz](https://files.pythonhosted.org/packages/f0/2f/829508adca9d96ccb07030dbeb661b5748a1e234e0873b365341067fa83b/pmd_pytcp-0.3.9.tar.gz) |
| prompt_toolkit | 3.0.53 | BSD License | [PyPI JSON](https://pypi.org/pypi/prompt_toolkit/3.0.53/json) | [prompt_toolkit-3.0.53.tar.gz](https://files.pythonhosted.org/packages/7d/ea/39b988c938f75cb75d7045b5c69f8bfed47ee2152c8837fb403de29d6fb8/prompt_toolkit-3.0.53.tar.gz) |
| psutil | 7.2.2 | BSD-3-Clause | [PyPI JSON](https://pypi.org/pypi/psutil/7.2.2/json) | [psutil-7.2.2.tar.gz](https://files.pythonhosted.org/packages/aa/c6/d1ddf4abb55e93cebc4f2ed8b5d6dbad109ecb8d63748dd2b20ab5e57ebe/psutil-7.2.2.tar.gz) |
| ptyprocess | 0.7.0 | ISC License (ISCL) | [PyPI JSON](https://pypi.org/pypi/ptyprocess/0.7.0/json) | [ptyprocess-0.7.0.tar.gz](https://files.pythonhosted.org/packages/20/e5/16ff212c1e452235a90aeb09066144d0c5a6a8c0834397e03f5224495c4e/ptyprocess-0.7.0.tar.gz) |
| pure-eval | 0.2.4 | MIT | [PyPI JSON](https://pypi.org/pypi/pure_eval/0.2.4/json) | [pure_eval-0.2.4.tar.gz](https://files.pythonhosted.org/packages/da/9f/abfd2959e9261dd5217ca8551d4de211ca6ab26fe9b72cf44731ff6c4442/pure_eval-0.2.4.tar.gz) |
| pycparser | 3.12 | BSD-3-Clause | [PyPI JSON](https://pypi.org/pypi/pycparser/3.12/json) | [pycparser-3.12.tar.gz](https://files.pythonhosted.org/packages/cb/27/eeb9f307bf07060f3d9f9aa0fb8c15b01bdfded0a941e4b2719c7f94cacd/pycparser-3.12.tar.gz) |
| pycrashreport | 2.5.1 | MIT | [PyPI JSON](https://pypi.org/pypi/pycrashreport/2.5.1/json) | [pycrashreport-2.5.1.tar.gz](https://files.pythonhosted.org/packages/b2/08/54b46e7ab708601d405d508dacf0eb7487f503cbb67dcead1dea5a72d562/pycrashreport-2.5.1.tar.gz) |
| pycryptodome | 4.6.0 | BSD-2-Clause AND Unlicense AND MIT | [PyPI JSON](https://pypi.org/pypi/pycryptodome/4.6.0/json) | [pycryptodome-4.6.0.tar.gz](https://files.pythonhosted.org/packages/e2/13/0ad2965295054c711bfed90f2b983480fe9d1eb71d1e999d6fbbfcf097f7/pycryptodome-4.6.0.tar.gz) |
| pydantic | 2.14.4 | MIT | [PyPI JSON](https://pypi.org/pypi/pydantic/2.14.4/json) | [pydantic-2.14.4.tar.gz](https://files.pythonhosted.org/packages/8e/25/3ec212432a6031b65f043eaca9c820ddf87c0d0aa330023e64f79fcb5db6/pydantic-2.14.4.tar.gz) |
| pydantic_core | 2.50.5 | MIT | [PyPI JSON](https://pypi.org/pypi/pydantic_core/2.50.5/json) | [pydantic_core-2.50.5.tar.gz](https://files.pythonhosted.org/packages/fb/63/0ceb815a7762576027ce388544c573d440574f95afb1302a2496b96db548/pydantic_core-2.50.5.tar.gz) |
| Pygments | 2.21.0 | BSD-2-Clause | [PyPI JSON](https://pypi.org/pypi/Pygments/2.21.0/json) | [pygments-2.21.0.tar.gz](https://files.pythonhosted.org/packages/49/2e/ced460408999b33da6b31b0021b0f37d329e202d4169aeb164493778f25b/pygments-2.21.0.tar.gz) |
| pygnuutils | 0.1.1 | GNU General Public License v3 or later (GPLv3+) | [PyPI JSON](https://pypi.org/pypi/pygnuutils/0.1.1/json) | [pygnuutils-0.1.1.tar.gz](https://files.pythonhosted.org/packages/03/20/6a828fe03d6586241b824ee06c7da854ea351716006a62fd2548eaa5710b/pygnuutils-0.1.1.tar.gz) |
| pyimg4 | 0.8.9 | 未明确识别；以上游随附许可证为准 | [PyPI JSON](https://pypi.org/pypi/pyimg4/0.8.9/json) | [pyimg4-0.8.9.tar.gz](https://files.pythonhosted.org/packages/5a/66/50888f9ad2c42a1ab0040c8fbba228cc145ec62bf94b376d60533afaac09/pyimg4-0.8.9.tar.gz) |
| pyinstaller | 6.22.3 | GPLv2-or-later with a special exception which allows to use PyInstaller to build and distribute non-free programs (including commercial ones) | [PyPI JSON](https://pypi.org/pypi/pyinstaller/6.22.3/json) | [pyinstaller-6.22.3.tar.gz](https://files.pythonhosted.org/packages/63/41/f90302845945abd4ed647933ff5ee7c6ac93983187be67f897b6cb613331/pyinstaller-6.22.3.tar.gz) |
| pyinstaller-hooks-contrib | 2026.10 | Apache Software License; GNU General Public License v2 (GPLv2) | [PyPI JSON](https://pypi.org/pypi/pyinstaller-hooks-contrib/2026.10/json) | [pyinstaller_hooks_contrib-2026.10.tar.gz](https://files.pythonhosted.org/packages/45/87/9a32062fb1296b43e866ec78313f887e12b09e6bc344c694647856bcd907/pyinstaller_hooks_contrib-2026.10.tar.gz) |
| pyiosbackup | 0.2.4 | GNU General Public License v3 or later (GPLv3+) | [PyPI JSON](https://pypi.org/pypi/pyiosbackup/0.2.4/json) | [pyiosbackup-0.2.4.tar.gz](https://files.pythonhosted.org/packages/46/ab/c7c3caf6785ced43d02c8c37be3c84720c40d6a9b237eb2ff560af4114e1/pyiosbackup-0.2.4.tar.gz) |
| pykdebugparser | 1.10.0 | 未明确识别；以上游随附许可证为准 | [PyPI JSON](https://pypi.org/pypi/pykdebugparser/1.10.0/json) | [pykdebugparser-1.10.0.tar.gz](https://files.pythonhosted.org/packages/13/77/fc89236fb1d87cafe5d822f55b4d12bdbf291743b496041f37923ffc8aeb/pykdebugparser-1.10.0.tar.gz) |
| pylzss | 0.3.9 | LGPL-3.0-only | [PyPI JSON](https://pypi.org/pypi/pylzss/0.3.9/json) | [pylzss-0.3.9.tar.gz](https://files.pythonhosted.org/packages/95/fa/3f003112e5e183c70304e2c15fe4517621026d3b71e61088d4ed38ecdce4/pylzss-0.3.9.tar.gz) |
| pymobiledevice3 | 11.63.1 | GPL-3.0-or-later | [PyPI JSON](https://pypi.org/pypi/pymobiledevice3/11.63.1/json) | [pymobiledevice3-11.63.1.tar.gz](https://files.pythonhosted.org/packages/f4/d1/64fdff98419fadf520fcdcea2a84ccd57968db247cd915213da87e5a1743/pymobiledevice3-11.63.1.tar.gz) |
| python-dateutil | 4.0.0 | BSD-3-Clause | [PyPI JSON](https://pypi.org/pypi/python-dateutil/4.0.0/json) | [python_dateutil-4.0.0.tar.gz](https://files.pythonhosted.org/packages/18/39/b3927f3616f6223832f9b760e4208e8a7c7e1dea2b4d9ad7d32a5d214c3a/python_dateutil-4.0.0.tar.gz) |
| python-dotenv | 1.2.4 | BSD-3-Clause | [PyPI JSON](https://pypi.org/pypi/python-dotenv/1.2.4/json) | [python_dotenv-1.2.4.tar.gz](https://files.pythonhosted.org/packages/74/26/2fbeedb218a787a5eea551c7532cac4e009f83d689dd2faa0d0353473f86/python_dotenv-1.2.4.tar.gz) |
| python-pcapng | 2.1.1 | Apache-2.0 | [PyPI JSON](https://pypi.org/pypi/python-pcapng/2.1.1/json) | [python-pcapng-2.1.1.tar.gz](https://files.pythonhosted.org/packages/3c/2f/72534730a81205cd3ca32d65b4760c927e6ffc69a3d06ff3d1edda64ae3e/python-pcapng-2.1.1.tar.gz) |
| pytun-pmd3 | 3.0.3 | GNU General Public License v3 or later (GPLv3+) | [PyPI JSON](https://pypi.org/pypi/pytun-pmd3/3.0.3/json) | [pytun_pmd3-3.0.3.tar.gz](https://files.pythonhosted.org/packages/5e/8a/6e73c70ddf5fdf9cf359cdc458f38cf795c4a653c870a4a49c8768e5db86/pytun_pmd3-3.0.3.tar.gz) |
| qh3 | 1.9.4 | BSD License | [PyPI JSON](https://pypi.org/pypi/qh3/1.9.4/json) | [qh3-1.9.4.tar.gz](https://files.pythonhosted.org/packages/72/ae/9d42d6df0ab9a014138332346fd690f7b0be0556861421d2459caec28d6f/qh3-1.9.4.tar.gz) |
| questionary | 2.1.1 | MIT | [PyPI JSON](https://pypi.org/pypi/questionary/2.1.1/json) | [questionary-2.1.1.tar.gz](https://files.pythonhosted.org/packages/f6/45/eafb0bba0f9988f6a2520f9ca2df2c82ddfa8d67c95d6625452e97b204a5/questionary-2.1.1.tar.gz) |
| remotezip2 | 0.0.2 | GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007 | [PyPI JSON](https://pypi.org/pypi/remotezip2/0.0.2/json) | [remotezip2-0.0.2.tar.gz](https://files.pythonhosted.org/packages/3f/47/94335875a4d5339f64943c1a68900f59a91ad987ab8fcd8e5201839e7cc5/remotezip2-0.0.2.tar.gz) |
| requests | 2.34.2 | Apache-2.0 | [PyPI JSON](https://pypi.org/pypi/requests/2.34.2/json) | [requests-2.34.2.tar.gz](https://files.pythonhosted.org/packages/ac/c3/e2a2b89f2d3e2179abd6d00ebd70bff6273f37fb3e0cc209f48b39d00cbf/requests-2.34.2.tar.gz) |
| rich | 15.0.0 | MIT | [PyPI JSON](https://pypi.org/pypi/rich/15.0.0/json) | [rich-15.0.0.tar.gz](https://files.pythonhosted.org/packages/c0/8f/0722ca900cc807c13a6a0c696dacf35430f72e0ec571c4275d2371fca3e9/rich-15.0.0.tar.gz) |
| setuptools | 84.2.1 | MIT | [PyPI JSON](https://pypi.org/pypi/setuptools/84.2.1/json) | [setuptools-84.2.1.tar.gz](https://files.pythonhosted.org/packages/70/b3/c19426f783614d625699a4b247faf628ea9ab1db228674491767b417f9e1/setuptools-84.2.1.tar.gz) |
| shellingham | 1.5.4 | ISC License | [PyPI JSON](https://pypi.org/pypi/shellingham/1.5.4/json) | [shellingham-1.5.4.tar.gz](https://files.pythonhosted.org/packages/58/15/8b3609fd3830ef7b27b655beb4b4e9c62313a4e8da8c676e142cc210d58e/shellingham-1.5.4.tar.gz) |
| stack-data | 0.6.3 | MIT | [PyPI JSON](https://pypi.org/pypi/stack-data/0.6.3/json) | [stack_data-0.6.3.tar.gz](https://files.pythonhosted.org/packages/28/e3/55dcc2cfbc3ca9c29519eb6884dd1415ecb53b0e934862d3559ddcb7e20b/stack_data-0.6.3.tar.gz) |
| starlette | 1.10.0 | BSD-3-Clause | [PyPI JSON](https://pypi.org/pypi/starlette/1.10.0/json) | [starlette-1.10.0.tar.gz](https://files.pythonhosted.org/packages/48/bb/3d8757f21e9a53d9035c9eb039a777047139a16bfdbedfc7a58241c3d914/starlette-1.10.0.tar.gz) |
| termcolor | 3.3.0 | MIT | [PyPI JSON](https://pypi.org/pypi/termcolor/3.3.0/json) | [termcolor-3.3.0.tar.gz](https://files.pythonhosted.org/packages/46/79/cf31d7a93a8fdc6aa0fbb665be84426a8c5a557d9240b6239e9e11e35fc5/termcolor-3.3.0.tar.gz) |
| traitlets | 5.16.1 | BSD License | [PyPI JSON](https://pypi.org/pypi/traitlets/5.16.1/json) | [traitlets-5.16.1.tar.gz](https://files.pythonhosted.org/packages/2c/2e/a7fbfe268c8a3b32546930c0297c101d65a4a14c304ad5790a9f478f0e4e/traitlets-5.16.1.tar.gz) |
| typer | 0.29.2 | MIT | [PyPI JSON](https://pypi.org/pypi/typer/0.29.2/json) | [typer-0.29.2.tar.gz](https://files.pythonhosted.org/packages/bf/21/37383ece7d0a4995fb8ea97729207c4292b3ff94085002f37b2387063cfb/typer-0.29.2.tar.gz) |
| typer-injector | 0.3.0 | MIT | [PyPI JSON](https://pypi.org/pypi/typer-injector/0.3.0/json) | [typer_injector-0.3.0.tar.gz](https://files.pythonhosted.org/packages/b3/11/7da0c6019c26cb660acc3329b44c3247286469de3dcd94013d0793598ecb/typer_injector-0.3.0.tar.gz) |
| typing-inspection | 0.4.5 | MIT | [PyPI JSON](https://pypi.org/pypi/typing-inspection/0.4.5/json) | [typing_inspection-0.4.5.tar.gz](https://files.pythonhosted.org/packages/ff/50/0195198eb1d75bab716bb0a813abea4cc394bfa17a92a189f021a34859af/typing_inspection-0.4.5.tar.gz) |
| typing-extensions | 4.16.0 | PSF-2.0 | [PyPI JSON](https://pypi.org/pypi/typing_extensions/4.16.0/json) | [typing_extensions-4.16.0.tar.gz](https://files.pythonhosted.org/packages/f6/cc/6253133b5bb138fc3306cebfbda2c520f545d36b5be2c7255cc528bb45d6/typing_extensions-4.16.0.tar.gz) |
| tzdata | 2026.6 | Apache-2.0 | [PyPI JSON](https://pypi.org/pypi/tzdata/2026.6/json) | [tzdata-2026.6.tar.gz](https://files.pythonhosted.org/packages/7a/29/6a1391d31cd00ff9e927215a224a880e1e84e826b64ba80a499e51c074d8/tzdata-2026.6.tar.gz) |
| urllib3 | 2.8.0 | MIT | [PyPI JSON](https://pypi.org/pypi/urllib3/2.8.0/json) | [urllib3-2.8.0.tar.gz](https://files.pythonhosted.org/packages/e3/05/b17359e1cefb4f909b5e40b1b90a496d987258916dbbf88e842c729f510e/urllib3-2.8.0.tar.gz) |
| uvicorn | 0.54.0 | BSD-3-Clause | [PyPI JSON](https://pypi.org/pypi/uvicorn/0.54.0/json) | [uvicorn-0.54.0.tar.gz](https://files.pythonhosted.org/packages/da/34/30e9280707135d2cfc589dfff3cb796bd07a3aeb1a3e415ba09dd89d7bb4/uvicorn-0.54.0.tar.gz) |
| wcwidth | 0.9.5 | MIT License | [PyPI JSON](https://pypi.org/pypi/wcwidth/0.9.5/json) | [wcwidth-0.9.5.tar.gz](https://files.pythonhosted.org/packages/8e/da/d59374b2c893ae70a41fdb064637ccef218f25df8c67e5431a96708235d9/wcwidth-0.9.5.tar.gz) |
| wsproto | 1.3.2 | MIT | [PyPI JSON](https://pypi.org/pypi/wsproto/1.3.2/json) | [wsproto-1.3.2.tar.gz](https://files.pythonhosted.org/packages/c7/79/12135bdf8b9c9367b8701c2c19a14c913c120b882d50b014ca0d38083c2c/wsproto-1.3.2.tar.gz) |
| xmltodict | 1.0.4 | MIT | [PyPI JSON](https://pypi.org/pypi/xmltodict/1.0.4/json) | [xmltodict-1.0.4.tar.gz](https://files.pythonhosted.org/packages/19/70/80f3b7c10d2630aa66414bf23d210386700aa390547278c789afa994fd7e/xmltodict-1.0.4.tar.gz) |

## 非依赖素材边界

- 图标及其生成提示词属于本项目随附素材，保留在 `Resources/`。
- 默认路线为公共场地的示意轨迹，不是个人设备采集的真实行踪，也不代表学校或地图服务的官方路线。
- 项目外的学校操作 PDF、地图页面截图、开发日志、设备配对记录和本机偏好配置不属于此公开源码清单；没有被此项目的 GPL 声明自动重新许可。
