# SFTP 服务容器

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/atmoz/sftp/build.yml?logo=github) ![GitHub stars](https://img.shields.io/github/stars/atmoz/sftp?logo=github) ![Docker Stars](https://img.shields.io/docker/stars/atmoz/sftp?label=stars&logo=docker) ![Docker Pulls](https://img.shields.io/docker/pulls/atmoz/sftp?label=pulls&logo=docker)

![OpenSSH logo](https://raw.githubusercontent.com/atmoz/sftp/master/openssh.png "Powered by OpenSSH")

# 支持的标签和 `Dockerfile` 链接

- [`debian`, `latest` (*Dockerfile*)](https://github.com/atmoz/sftp/blob/master/Dockerfile) ![Docker Image Size (debian)](https://img.shields.io/docker/image-size/atmoz/sftp/debian?label=debian&logo=debian&style=plastic)
- [`alpine` (*Dockerfile*)](https://github.com/atmoz/sftp/blob/master/Dockerfile-alpine) ![Docker Image Size (alpine)](https://img.shields.io/docker/image-size/atmoz/sftp/alpine?label=alpine&logo=Alpine%20Linux&style=plastic)

# 安全地共享您的文件

使用 [OpenSSH](https://en.wikipedia.org/wiki/OpenSSH) 提供简单易用的 SFTP ([SSH File Transfer Protocol](https://en.wikipedia.org/wiki/SSH_File_Transfer_Protocol)) 服务器。

# 使用方法

- **定义用户**：可以通过以下三种方式定义用户：
  1. 命令行参数
  2. `SFTP_USERS` 环境变量
  3. 挂载到 `/etc/sftp/users.conf` 的文件（语法：`user:pass[:e][:uid[:gid[:dir1[,dir2]...]]]`，详见下文示例）
  - 如果需要用户对挂载卷的修改权限与宿主机文件系统权限匹配，请手动设置 UID/GID。
  - 末尾目录名将在用户的家目录下创建，并赋予写权限（如果不存在）。
- **挂载卷**：
  - 用户被限制（chroot）在他们的家目录中，因此您可以将卷挂载到用户家目录内的单独目录（`/data/user/已挂载目录`），或者直接挂载整个 `/data` 目录。
  - 请记住，用户无法直接在自己的家目录下创建新文件，因此请确保至少有一个子目录（如 `upload`）以便他们上传文件。
  - 为了保持服务器指纹一致，请挂载您自己的主机密钥（即 `/etc/ssh/ssh_host_*`）。

# 示例

## 最简单的 Docker 运行示例

```bash
docker run -p 22:22 -d atmoz/sftp foo:pass:::upload
```

用户 "foo" 使用密码 "pass" 登录 sftp，并可以上传文件到名为 "upload" 的文件夹。无需挂载目录或自定义 UID/GID。

## 共享计算机上的目录

挂载目录并设置 UID：

```bash
docker run \
    -v <host-dir>/upload:/data/foo/upload \
    -p 2222:22 -d atmoz/sftp \
    foo:pass:1001
```

### 使用 Docker Compose：

```yaml
sftp:
    image: atmoz/sftp
    volumes:
        - <host-dir>/upload:/data/foo/upload
    ports:
        - "2222:22"
    command: foo:pass:1001
```

### 登录

OpenSSH 服务器默认运行在 22 端口，在此示例中，我们将容器的 22 端口转发到主机的 2222 端口。使用 OpenSSH 客户端登录：`sftp -P 2222 foo@<host-ip>`

## 将用户存储在配置中

```bash
docker run \
    -v <host-dir>/users.conf:/etc/sftp/users.conf:ro \
    -v mySftpVolume:/data \
    -p 2222:22 -d atmoz/sftp
```

`<host-dir>/users.conf`:

```
foo:123:1001:100
bar:abc:1002:100
baz:xyz:1003:100
```

## 加密密码

在密码后添加 `:e` 标记其为加密密码。如果在终端中使用，请使用单引号。

```bash
docker run \
    -v <host-dir>/share:/data/foo/share \
    -p 2222:22 -d atmoz/sftp \
    'foo:$1$0G2g0GSt$ewU0t6GXG15.0hWoOX8X9.:e:1001'
```

提示：您可以使用此 Python 代码生成加密密码：  
`docker run --rm python:alpine python -c "import crypt; print(crypt.crypt('YOUR_PASSWORD'))"`

## 使用 SSH 密钥登录（免密登录）

将公钥挂载到容器的 `/etc/sftp/keys/<username>/` 目录下。该目录下的所有 `.pub` 文件将自动合并到 `authorized_keys` 中。

在这个示例中，我们**不提供密码**，因此用户 `foo` 只能通过其 SSH 密钥登录。

```bash
docker run \
    -v <host-dir>/id_rsa.pub:/etc/sftp/keys/foo/id_rsa.pub:ro \
    -v <host-dir>/share:/data/foo/share \
    -p 2222:22 -d atmoz/sftp \
    foo::1001
```

**优点**：
- **安全性**：`authorized_keys` 存储在 chroot 目录之外，用户登录后不可见且不可修改其认证配置。
- **强制密钥认证**：通过不设置密码（`user::`），可以强制用户必须使用密钥登录。

## 提供您自己的 SSH 主机密钥（推荐）

此容器在首次运行时会生成新的 SSH 主机密钥。为了避免用户在您重新创建容器（主机密钥改变）时收到 MITM 警告，您可以挂载自己的主机密钥。

```bash
docker run \
    -v <host-dir>/ssh_host_ed25519_key:/etc/ssh/ssh_host_ed25519_key \
    -v <host-dir>/ssh_host_rsa_key:/etc/ssh/ssh_host_rsa_key \
    -v <host-dir>/share:/data/foo/share \
    -p 2222:22 -d atmoz/sftp \
    foo::1001
```

提示：您可以使用以下命令生成密钥：

```bash
ssh-keygen -t ed25519 -f ssh_host_ed25519_key < /dev/null
ssh-keygen -t rsa -b 4096 -f ssh_host_rsa_key < /dev/null
```

## 执行自定义脚本或应用

将您的程序放在 `/etc/sftp.d/` 下，它们将在容器启动时自动运行。

## 绑定挂载其他位置的目录

如果您想让用户访问特定的目录，可以在 `/etc/sftp.d/` 中添加一个脚本，在容器启动后进行 `mount --bind`。

```bash
#!/bin/bash
# 文件挂载为: /etc/sftp.d/bindmount.sh

function bindmount() {
    if [ -d "$1" ]; then
        mkdir -p "$2"
    fi
    mount --bind "$1" "$2"
}

# 挂载示例
bindmount /data/common /data/foo/common
```

**注意**：使用 `mount` 需要容器运行时开启 `CAP_SYS_ADMIN` 权限。

# Debian 和 Alpine 有什么区别？

主要区别在于大小和 OpenSSH 版本。Alpine 比 Debian 小 10 倍左右。Debian 通常被认为更稳定，而 Alpine 更新周期更快。

# 每日构建

镜像每天自动构建，以获取包管理器提供的最新 OpenSSH 版本。
