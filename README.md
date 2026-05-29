# custom-derper-docker

使用 Docker 自建 Tailscale DERP 服务器

- 官方文档：[Custom DERP Servers](https://tailscale.com/kb/1118/custom-derp-servers)

## 目录

```bash
.
├── Dockerfile
├── LICENSE
├── README.md
└── derp
    ├── .env
    ├── .env.template
    ├── certs
    │   └── gen_self_certs.sh
    └── compose.yaml
```

## 镜像构建

```bash
# 普通构建
docker build -t derp .
# 跨平台构建
docker buildx build --platform linux/amd64 -t derp --load .
```

## 部署

### 1. 生成证书

支持非域名部署：

```bash
cd derp/certs
bash gen_self_certs.sh <domain/ip>
```

### 2. 配置环境变量

```bash
cd derp
cp .env.template .env
vim .env
```

### 3. 启动

```bash
docker compose up -d
```

### 4. 参数说明

配置文件：`derp/.env`

| ENV | 必须 | 描述 | 默认值 |
| --- | ---- | ---- | ------ |
| DERP_DOMAIN | 是 | DERP 服务器域名或 IP | |
| DERP_ADDR | 否 | DERP 服务器监听地址 | :443 |
| DERP_HTTP_PORT | 否 | HTTP 服务端口（-1 禁用） | -1 |
| DERP_CERT_MODE | 否 | 获取证书的模式，可选值：letsencrypt, manual | manual |
| DERP_CERT_DIR | 否 | 证书存放目录 | /app/certs |
| DERP_STUN | 否 | 是否启用 STUN 服务 | true |
| DERP_STUN_PORT | 否 | STUN 服务端口 | 3478 |
| DERP_VERIFY_CLIENTS | 否 | 是否验证客户端 | true |
| DERP_VERIFY_CLIENT_URL | 否 | 配置对客户端认证的 webhook 地址 | |

### 客户端验证（DERP_VERIFY_CLIENTS）

`DERP_VERIFY_CLIENTS` 用于限制只有已授权的 Tailscale 节点才能使用 DERP 服务器进行流量中继，防止未授权设备滥用你的服务器带宽。

- `true`（默认）：derper 通过本地 tailscaled 守护进程验证连接客户端是否为合法 Tailscale 节点
- `false`：关闭验证，任何设备均可使用你的 DERP 服务器

**验证原理：** derper 进程通过 Unix Socket 连接到宿主机上运行的 tailscaled，调用其 Local API 来校验客户端身份。因此需要将宿主机的 tailscaled socket 文件挂载到容器内。

#### 配置步骤

**1. 确认宿主机 tailscaled socket 路径**

常见路径（取决于操作系统和安装方式）：

| 操作系统 | 默认路径 |
| --- | --- |
| Linux | `/var/run/tailscale/tailscaled.sock` |
| macOS | `/var/run/tailscale/tailscaled.sock` |
| FreeBSD | `/var/run/tailscale/tailscaled.sock` |

可通过以下命令确认实际路径：

```bash
# 查找 socket 文件
sudo find / -name tailscaled.sock 2>/dev/null
```

**2. 挂载 socket 到容器**

`compose.yaml` 中已默认挂载了 socket 文件：

```yaml
volumes:
  - /var/run/tailscale/tailscaled.sock:/var/run/tailscale/tailscaled.sock
```

如果你的 socket 路径不同，修改冒号左侧的宿主机路径即可，例如：

```yaml
volumes:
  - /custom/path/tailscaled.sock:/var/run/tailscale/tailscaled.sock
```

**3. 确保宿主机 tailscaled 已登录并运行**

容器内的 derper 需要通过 socket 与宿主机的 tailscaled 通信。验证客户端身份时，tailscaled 会从 Tailscale 协调服务器获取包含所有节点公钥的网络映射表（Network Map）来校验连接方是否为合法节点。

因此，宿主机上的 tailscaled 需要满足：

| 条件 | 是否必须 | 说明 |
| --- | --- | --- |
| tailscaled 进程运行 | 是 | 守护进程必须在后台运行 |
| 已登录 Tailnet | 是 | 需要与协调服务器同步节点信息 |
| `tailscale up` 加入网络 | 否 | 宿主机无需作为网络节点暴露 |
| 开启子网路由/接受路由 | 否 | 与 DERP 验证无关 |

检查 tailscaled 状态：

```bash
tailscale status
```

**4. 配置环境变量**

```bash
# .env
DERP_VERIFY_CLIENTS=true
```

> **注意：** 如果你没有在宿主机运行 Tailscale，或不需要客户端验证（**关闭验证可能会导致非预期的客户端链接**，不建议关闭），将 `DERP_VERIFY_CLIENTS` 设为 `false`，并注释掉 `compose.yaml` 中的 socket 挂载行。

## 启用自建 DERP 服务

### 配置步骤

#### 1. 登录 Tailscale 控制台

访问 [Tailscale Admin Console](https://login.tailscale.com/admin) 并登录你的账号。

#### 2. 编辑 ACL 配置

1. 在控制台左侧菜单选择 **Access Controls**
2. 点击 **JSON editor** 按钮
3. 在 JSON 编辑器中找到或添加 `derpMap` 配置:

```json
{
  // ... 其他 ACL 配置 ...
  "derpMap": {
    // "OmitDefaultRegions": true, // 禁用 Tailscale 官方 DERP，仅使用自建服务
    "Regions": {
      "900": {
        "RegionID": 900,
        "RegionCode": "customderp",
        "RegionName": "Custom DERP",
        "Nodes": [
          {
            "Name": "customderp1",
            "HostName": "your-domain.com",  // 替换为你的域名或IP
            "IPv4": "1.2.3.4",              // 替换为你的服务器IP
            "InsecureForTests": true        // 自签证书必须设置为 true
          }
        ]
      }
    }
  }
}
```

#### 3. 配置说明

| 字段 | 说明 |
| ---- | ---- |
| `RegionID` | 自定义区域 ID，范围 900-999，避免与官方 ID 冲突 |
| `RegionCode` | 区域代码，用于标识 |
| `RegionName` | 区域名称，显示在 Tailscale 客户端中 |
| `Name` | DERP 节点名称 |
| `HostName` | DERP 服务器域名或 IP（需与 DERP_DOMAIN 一致） |
| `IPv4` | 服务器 IPv4 地址 |
| `InsecureForTests` | 是否允许不安全连接，自签证书必须设为 `true` |
| `OmitDefaultRegions` | 设为 `true` 将禁用 Tailscale 官方 DERP，仅使用自建服务 |

**注意**：Tailscale 默认优先选择官方 DERP 节点，自建服务器可能不会被选用。解决方案：

- 将 `RegionID` 设置为较低的值（如 900 以下）
- 或开启 `OmitDefaultRegions: true` 完全禁用官方 DERP 节点

#### 4. 保存并验证

1. 点击 **Save** 保存配置
2. 在客户端运行以下命令验证：

```bash
tailscale derp list
tailscale netcheck
tailscale ping <target>
```
