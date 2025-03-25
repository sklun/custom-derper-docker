# custom-derper-docker
使用 Docker 自建 Tailscale DERP 服务器

- 官方文档：[Custom DERP Servers](https://tailscale.com/kb/1118/custom-derp-servers)



# 目录

```bash
.
├── Dockerfile
├── LICENSE
├── README.md
└── derp
    ├── certs
    │   └── gen_self_certs.sh
    └── compose.yaml

3 directories, 5 files
```



# 镜像构建

```bash
# 普通构建
docker build -t derp .
# 跨平台构建
docker buildx build --platform linux/amd64 -t derp --load .

```



# 部署

1. 生成证书

- 支持非域名部署

```bash
cd derp/certs
bash gen_self_certs.sh <domain/ip>
```

2. 启动

```bash
docker compose up -d
```

3. 参数说明

| ENV                    | 必须 | 描述                                        | 默认值     |
| ---------------------- | ---- | ------------------------------------------- | ---------- |
| DERP_DOMAIN            | 是   | DERP 服务器域名或 IP                        | domain/ip  |
| DERP_ADDR              | 否   | DERP 服务器端口                             | :443       |
| DERP_HTTP_PORT         | 否   | HTTP 服务端口                               | 80         |
| DERP_CERT_MODE         | 否   | 获取证书的模式，可选值：letsencrypt, manual | manual     |
| DERP_CERT_DIR          | 否   | 证书存放目录                                | /app/certs |
| DERP_STUN              | 否   | 是否启用 STUN 服务                          | true       |
| DERP_STUN_PORT         | 否   | STUN 服务端口                               | 3478       |
| DERP_VERIFY_CLIENTS    | 否   | 是否验证客户端                              | true       |
| DERP_VERIFY_CLIENT_URL | 否   | 配置对客户端认证的 webhook 地址             | ""         |



# 启用自建 DERP 服务

- tailscale 控制台 ACL 添加规则

```json
"derpMap": {
		// "OmitDefaultRegions": true, // 强制使用自建 DERP 服务
		"Regions": {
			"900": { // RegionID 900-999
				"RegionID":   900, // RegionID 900-999
				"RegionCode": "customderp",
				"Nodes": [{
					"Name":             "customderp", // DERP node name
					"HostName":         "domain/ip",  // 你的域名或服务器IP
					"IPv4":             "ip", // 你的服务器IP
					"InsecureForTests": true, // 自签证书必须启用
				}],
			},
		},
	},
```



# 测试

```bash
tailscale netcheck
tailscale ping <device>
```

