# SFTP 服务容器

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/bineyond/sftp/docker-publish.yml?logo=github&label=build) ![GitHub stars](https://img.shields.io/github/stars/bineyond/sftp?logo=github) ![GitHub release (latest by date)](https://img.shields.io/github/v/release/bineyond/sftp?logo=github)

![OpenSSH logo](https://raw.githubusercontent.com/bineyond/sftp/master/openssh.png "Powered by OpenSSH")

# 支持的标签和 `Dockerfile` 链接

- [`debian`, `latest` (*Dockerfile*)](https://github.com/bineyond/sftp/blob/master/Dockerfile)
- [`alpine` (*Dockerfile*)](https://github.com/bineyond/sftp/blob/master/Dockerfile-alpine)

# 安全地共享您的文件

使用 [OpenSSH](https://en.wikipedia.org/wiki/OpenSSH) 提供简单易用的 SFTP ([SSH File Transfer Protocol](https://en.wikipedia.org/wiki/SSH_File_Transfer_Protocol)) 服务器。

此版本基于 atmoz/sftp 进行了现代化重构，支持高级用户配置（UID/GID/多子目录）和安全的 SSH 密钥免密登录。

# 使用方法

- **定义用户**：可以通过以下三种方式定义用户：
  1. 命令行参数（例如：`foo:pass:1001`）
  2. `SFTP_USERS` 环境变量（用户名密码对，用逗号或空格分隔）
  3. 挂载到 `/etc/sftp/users.conf` 的外部文件
  - **语法**：`user:pass[:e][:uid[:gid[:dir1[,dir2]...]]]`
  - `:e` 标志表示密码已加密。
  - `uid` 和 `gid` 用于设置系统用户 ID 和组 ID（推荐用于匹配宿主机特定权限）。
  - `dir1,dir2...` 定义在用户 chroot 目录下自动创建的可写子目录。如果不指定，默认创建 `upload` 目录。
- **挂载卷**：
  - 用户被限制（chroot）在 `/data/<username>` 目录中。
  - **重要**：用户无法直接在自己的 chroot 根目录下创建新文件（由 root 所有以满足 SSH 安全要求），必须在子目录（如 `upload`）中操作。
  - 为了保持服务器指纹一致，请挂载您自己的主机密钥（`/etc/ssh/ssh_host_*`）。

# 示例

## 1. 最简单的运行方式

```bash
docker run -p 22:22 -d bineyond/sftp foo:pass:::upload
```

用户 "foo" 使用密码 "pass" 登录，并可以上传文件到名为 "upload" 的文件夹。

## 2. 共享主机上的特定目录

挂载目录并设置 UID 以匹配宿主机权限：

```bash
docker run \
    -v <host-dir>/upload:/data/foo/upload \
    -p 2222:22 -d bineyond/sftp \
    foo:pass:1001
```

### 使用 Docker Compose

```yaml
services:
  sftp:
    image: bineyond/sftp
    volumes:
      - <host-dir>/upload:/data/foo/upload
    ports:
      - "2222:22"
    command: foo:pass:1001
```

### 登录方式
OpenSSH 服务器运行在容器的 22 端口，将其映射到主机的 2222 端口后，使用客户端登录：
`sftp -P 2222 foo@<host-ip>`

## 3. 使用配置文件管理大量用户

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
    -v mySftpVolume:/data \
    -p 22:22 -d bineyond/sftp
```

## 4. 加密密码 (Encrypted Passwords)

在密码后添加 `:e`。您可以使用以下命令生成加密密码：
`docker run --rm python:alpine python -c "import crypt; print(crypt.crypt('YOUR_PASSWORD'))"`

```bash
docker run -p 22:22 -d bineyond/sftp 'foo:$6$xyz...:e:1001'
```

## 5. SSH 密钥登录 (免密登录 - 推荐)

将公钥挂载到容器的 `/etc/sftp/keys/<username>/` 目录下。该目录下的所有 `.pub` 文件将自动合并。

```bash
docker run \
    -v <host-dir>/id_rsa.pub:/etc/sftp/keys/foo/id_rsa.pub:ro \
    -v <host-dir>/share:/data/foo/share \
    -p 2222:22 -d bineyond/sftp \
    foo::1001
```

**优点**：
- **安全性**：认证密钥存储在 chroot 目录外，用户登录后无法查看或篡改。
- **强制密钥认证**：通过不设置密码（`user::`），可以禁用该用户的密码登录。

## 6. 提供自定义 SSH 主机密钥 (避免警告)

挂载您自己的主机密钥以保证容器重新创建后指纹不变：

```bash
docker run \
    -v <host-dir>/ssh_host_ed25519_key:/etc/ssh/ssh_host_ed25519_key \
    -v <host-dir>/ssh_host_rsa_key:/etc/ssh/ssh_host_rsa_key \
    -p 22:22 -d bineyond/sftp foo:pass
```

提示：使用 `ssh-keygen -t ed25519 -f ssh_host_ed25519_key < /dev/null` 生成密钥。

# 高级自定义

## 执行初始化脚本
将 `.sh` 脚本放在 `/etc/sftp.d/` 下，它们将在容器启动（用户创建后，服务启动前）自动按字母顺序执行。

## 绑定挂载 (Bind Mounts)
如果您希望用户访问系统中的其他目录，可以利用初始化脚本进行绑定挂载：

```bash
#!/bin/bash
# 文件位置: /etc/sftp.d/bindmount.sh
mount --bind /home/share/docs /data/foo/docs
```
*注意：容器需要开启 `CAP_SYS_ADMIN` 权限或使用 `--privileged` 模式。*

---

由 [Bineyond](https://github.com/bineyond) 维护和优化。联系邮箱：[bineyond@gmail.com](mailto:bineyond@gmail.com)
