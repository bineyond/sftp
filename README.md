# SFTP 服务容器

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/bineyond/sftp/docker-publish.yml?logo=github&label=build) ![GitHub stars](https://img.shields.io/github/stars/bineyond/sftp?logo=github) ![GitHub release (latest by date)](https://img.shields.io/github/v/release/bineyond/sftp?logo=github)

![OpenSSH logo](https://raw.githubusercontent.com/bineyond/sftp/master/openssh.png "Powered by OpenSSH")

# 支持的标签和 `Dockerfile` 链接

- [`debian`, `latest` (*Dockerfile*)](https://github.com/bineyond/sftp/blob/master/Dockerfile)
- [`alpine` (*Dockerfile*)](https://github.com/bineyond/sftp/blob/master/Dockerfile-alpine)

# 安全地共享您的文件

使用 [OpenSSH](https://en.wikipedia.org/wiki/OpenSSH) 提供简单易用的 SFTP ([SSH File Transfer Protocol](https://en.wikipedia.org/wiki/SSH_File_Transfer_Protocol)) 服务器。支持高级用户配置（UID/GID/多子目录）和 SSH 密钥免密登录。

# 使用方法

- **定义用户**：可以通过以下三种方式定义用户：
  1. 命令行参数（例如：`docker run ... foo:pass:1001`）
  2. `SFTP_USERS` 环境变量（用户名密码对，用逗号或空格分隔）
  3. 挂载到 `/etc/sftp/users.conf` 的文件
  - **语法**：`user:pass[:e][:uid[:gid[:dir1[,dir2]...]]]`
  - `:e` 标志表示密码已加密。
  - `uid` 和 `gid` 用于设置系统用户 ID 和组 ID（推荐用于匹配宿主机权限）。
  - `dir1,dir2...` 定义在用户 chroot 目录下自动创建的可写子目录。如果不指定，默认创建 `upload` 目录。
- **挂载卷**：
  - 用户被限制（chroot）在 `/data/<username>` 目录中。
  - 用户无法直接在自己的 chroot 根目录下创建新文件，必须在子目录（如 `upload`）中操作。
  - 为了保持服务器指纹一致，请挂载您自己的主机密钥（`/etc/ssh/ssh_host_*`）。

# 示例

## 高级用户配置示例

通过一个配置定义用户名、加密密码、自定义 UID/GID 以及多个预建目录：

```bash
docker run -p 22:22 -d bineyond/sftp \
    'alice:$6$xyz$abc...:e:1234:5678:personal,shared'
```

## 使用 SSH 密钥登录（免密登录）

将公钥挂载到容器的 `/etc/sftp/keys/<username>/` 目录下。该目录下的所有 `.pub` 文件将自动合并到 `authorized_keys` 中。

```bash
docker run \
    -v <host-dir>/id_rsa.pub:/etc/sftp/keys/foo/id_rsa.pub:ro \
    -v <host-dir>/share:/data/foo/share \
    -p 2222:22 -d bineyond/sftp \
    foo::1001
```

**优点**：
- **安全性**：认证密钥存储在 chroot 目录外，用户无法查看或修改。
- **强制密钥认证**：通过不设置密码（`user::`），可以禁用密码登录。

## 将用户存储在配置中

`<host-dir>/users.conf`:
```text
# 用户名:密码:是否加密:UID:GID:子目录
foo:123::1001:100:upload,backup
bar:abc::1002:100:work
admin:pass::0:0:config
```

运行容器：
```bash
docker run \
    -v <host-dir>/users.conf:/etc/sftp/users.conf:ro \
    -p 22:22 -d bineyond/sftp
```

## 提供您自己的 SSH 主机密钥（推荐）

```bash
docker run \
    -v <host-dir>/ssh_host_ed25519_key:/etc/ssh/ssh_host_ed25519_key \
    -v <host-dir>/ssh_host_rsa_key:/etc/ssh/ssh_host_rsa_key \
    -p 22:22 -d bineyond/sftp \
    foo:pass
```

## 执行自定义脚本

将您的 `.sh` 脚本放在 `/etc/sftp.d/` 下，它们将在容器启动（用户创建后，服务启动前）自动运行。

---

由 [Bineyond](https://github.com/bineyond) 维护和优化。

**注意**：使用 `mount` 需要容器运行时开启 `CAP_SYS_ADMIN` 权限。

# Debian 和 Alpine 有什么区别？

主要区别在于大小和 OpenSSH 版本。Alpine 比 Debian 小 10 倍左右。Debian 通常被认为更稳定，而 Alpine 更新周期更快。

# 每日构建

镜像每天自动构建，以获取包管理器提供的最新 OpenSSH 版本。
