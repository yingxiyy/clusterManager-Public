# CloudCluster Kubernetes HA & Stateful Stack 部署与运维手册

本项目提供了在 **3台物理机/虚拟机** 上搭建高可用 Kubernetes 集群（Keepalived VIP + HAProxy），并以集群模式部署第三方组件的完整工程方案。

---

## 目录
0. [集群所有服务初始安装账号与密码配置清单 (强制认证)](#0-集群所有服务初始安装账号与密码配置清单-强制认证)
1. [【完整手册】一步步完成所有基础组件的安装过程 (3-Master K8s 与全套分布式中间件实战指南)](#1-完整手册一步步完成所有基础组件的安装过程-3-master-k8s-与全套分布式中间件实战指南)
   - 1.1 [基础组件全局规划与全套组件矩阵表](#11-基础组件全局规划与全套组件矩阵表)
   - 1.2 [节点网络拓扑规划 (VIP、3 Master 兼任 Worker、当前管控环境)](#12-节点网络拓扑规划)
   - 1.3 [第一步：操作系统优化与系统级底座基础组件安装 (Swap/内核/网络)](#13-第一步操作系统优化与系统级底座基础组件安装)
   - 1.4 [第二步：容器运行时底座安装与配置 (Containerd + SystemdCgroup)](#14-第二步容器运行时底座安装与配置)
   - 1.5 [第三步：高可用控制面入口基础组件配置 (Keepalived VIP + HAProxy)](#15-第三步高可用控制面入口基础组件配置)
   - 1.6 [第四步：Kubernetes 核心底座安装与 3-Master 集群初始化 (kubeadm/CNI/污点消除)](#16-第四步kubernetes-核心底座安装与-3-master-集群初始化)
   - 1.7 [第五步：集群管控工具基础组件安装 (Helm 3 与 k9s 终端控制台)](#17-第五步集群管控工具基础组件安装)
   - 1.8 [第六步：全栈 Java 21 LTS 基础开发与运行时环境就绪](#18-第六步全栈-java-21-lts-基础开发与运行时环境就绪)
   - 1.9 [第七步：打通“我的这一个管控环境”与 3-Master K8s 集群](#19-第七步打通我的这一个管控环境与-3-master-k8s-集群)
   - 1.10 [第八步：全套 8 大分布式基础组件分步安装实战 (MinIO/ZK/Kafka/MySQL/Mongo/Redis/Flink/Nginx)](#110-第八步全套-8-大分布式基础组件分步安装实战)
   - 1.11 [第九步：所有基础组件健康检查、冒烟测试与端口总汇](#111-第九步所有基础组件健康检查冒烟测试与端口总汇)
   - 1.12 [第十步：外部 Git (GitHub / GitLab / Gitee) 网络访问与拉取指南](#112-第十步外部-git-github--gitlab--gitee-网络访问与拉取指南)
2. [节点环境初始化与 Kubernetes (k8s) & k9s 安装](#2-节点环境初始化与-kubernetes-k8s--k9s-安装)
3. [Master 节点高可用 (Keepalived + HAProxy) 深度配置](#3-master-节点高可用-keepalived--haproxy-深度配置)
4. [初始化 3 台 Master/Worker 节点 (kubeadm init & join)](#4-初始化-3-台-masterworker-节点-kubeadm-init--join)
5. [Worker 节点扩展流程 (物理机/VM 手工执行 CLI)](#5-worker-节点扩展流程-物理机vm-手工执行-cli)
6. [第三方应用集群部署 (Helm + Docker Hub, 全栈 Java 21 LTS)](#6-第三方应用集群部署-helm--docker-hub-全栈-java-21-lts)
7. [Pod 与组件弹性伸缩 (后端自动执行 vs CLI)](#7-pod-与组件弹性伸缩-后端自动执行-vs-cli)
8. [后端执行模式配置 (Simulator 模式 vs 真实宿主机执行)](#8-后端执行模式配置-simulator-模式-vs-真实宿主机执行)
9. [3 台物理主机下 MySQL & MongoDB 持久化存储与 S3 冷备份实战](#9-3-台物理主机下-mysql--mongodb-持久化存储与-s3-冷备份实战-方案-3---当前生效标准)
10. [Nginx 前端入口网关配置与优化实战 (代码放 Docker 外面免重构镜像)](#10-nginx-前端入口网关配置与优化实战-代码放-docker-外面免重构镜像)

---

## 0. 集群所有服务初始安装账号与密码配置清单 (强制认证)

> **安全准则**：本项目所有 8 大服务均**100% 强制启用用户名/密码或 Token 鉴权**，拒绝任何无密码匿名访问。初始安装前，用户可在 Web 控制台的 `Auth & Initial Credentials (初始认证配置)` 标签页直接审查、一键生成 16 位强密码或导出配置文件。

### 0.1 全组件初始账号与密码总表

| 序号 | 组件名称 | 端口 | 账号类别 | 默认用户名 | 默认密码 | 鉴权协议机制 | 客户端快速连接语法示例 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | **MinIO S3** | 9000 (API)<br/>9001 (Web) | 管理员 | `minioAdmin` | `minioAdminPassword123` | AccessKey + SecretKey | `mc alias set myminio http://192.168.1.100:9000 minioAdmin minioAdminPassword123` |
| 2 | **MySQL 8.4** | 3306 | 超级 Root<br/>应用业务<br/>主从同步 | `root`<br/>`app_user`<br/>`repl_user` | `mysqlRootPassword123`<br/>`mysqlAppPassword123`<br/>`replPassword123` | Native Password / GTID 复制 | `mysql -h 192.168.1.100 -P 3306 -u app_user -p'mysqlAppPassword123' appdb` |
| 3 | **MongoDB 8.0** | 27017 | 集群 Root<br/>应用业务<br/>内部节点 | `admin`<br/>`mongo_app`<br/>- | `mongoAdminPassword123`<br/>`mongoAppPassword123`<br/>Keyfile (400 权限) | SCRAM-SHA-256 + Keyfile 副本鉴权 | `mongosh "mongodb://192.168.1.100:27017/appdb?replicaSet=rs0" -u mongo_app -p'mongoAppPassword123' --authenticationDatabase admin` |
| 4 | **Redis 6.2** | 6379 (Cache)<br/>26379 (Sentinel) | 统一密码 | `default` | `redisAuthPassword123` | `requirepass` + `masterauth` | `redis-cli -h 192.168.1.100 -p 6379 -a 'redisAuthPassword123' ping` |
| 5 | **Kafka 4.0.1** | 9092 | 集群 Admin<br/>业务 Client | `admin`<br/>`app_user` | `kafkaAdminPassword123`<br/>`kafkaAppPassword123` | **SASL_PLAINTEXT** (Java 21 Native KRaft) | 详见下方 0.3 节 client.properties 配置 |
| 6 | **ZooKeeper 3.9.3**| 2181 | 节点 Admin | `zkAdmin` | `zkAdminPassword123` | SASL Digest-MD5 (Java 21) | `zkCli.sh -server 192.168.1.100:2181` 然后执行 `addauth digest zkAdmin:zkAdminPassword123` |
| 7 | **Flink 2.2** | 8081 | 仪表盘 Admin | `flinkAdmin` | `flinkAdminPassword123` | HTTP Basic Auth (Java 21) | 浏览器访问 `http://192.168.1.100:8081` 或 `curl -u flinkAdmin:flinkAdminPassword123 ...` |
| 8 | **Kubernetes** | 6443 | 集群管理 | `kubernetes-admin` | Token: `abcdef.0123456789abcdef` | mTLS 双向证书 + Bearer Token | `kubectl --server=https://192.168.1.100:6443 get nodes` |
| 9 | **Nginx 1.27** | 8088 (前端SPA+API)<br/>8000 (Purge) | 前端入口网关 | - | 宿主机外部目录 `/data/frontend/dist` | 静态极速读取 + 反代 Gateway | 浏览器直接访问 `http://192.168.1.100:30088` (代码放外部免重构镜像) |

---

### 0.2 如何在初始安装前定制修改密码

#### 方式 1：Web 控制台一键定制与导出（最简捷）
1. 访问本系统 Web 控制台顶部导航栏的 **`Auth & Initial Credentials (初始认证配置)`** 标签页；
2. 点击 **`🎲 一键生成强密码`** 按钮，系统会自动为所有 8 大服务生成互不相同的 16 位强密码；
3. 点击 **`📋 复制凭证总表`** 保存到您的密码管理器，或点击 **`💾 导出 credentials.yaml`**；
4. 切换到 `Helm Values Configurator` 标签页，所有修改的账号密码已实时自动更新至部署代码中。

#### 方式 2：修改 `./helm/values.yaml` 文件
在执行 `helm install` 前，直接编辑 `values.yaml`：
```yaml
minio:
  rootUser: "myAdmin"
  rootPassword: "MyCustomStrongPassword123!"

mysql:
  rootPassword: "MyMysqlRootPassword123!"
  appUser: "my_app_user"
  appPassword: "MyAppPassword123!"

mongodb:
  auth:
    rootUser: "admin"
    rootPassword: "MyMongoPassword123!"
    appUser: "my_app_user"
    appPassword: "MyMongoAppPassword123!"

redis:
  password: "MyRedisPassword123!"

kafka:
  auth:
    enabled: true
    adminUser: "admin"
    adminPassword: "MyKafkaAdminPassword123!"
    clientUser: "app_user"
    clientPassword: "MyKafkaClientPassword123!"

flink:
  auth:
    enabled: true
    adminUser: "flinkAdmin"
    adminPassword: "MyFlinkPassword123!"
```

---

### 0.3 客户端认证连接代码配置样例

#### 1. MySQL 8.4 通用应用连接配置：
* **Java Spring Boot (`application.yml`)**：
  ```yaml
  spring:
    datasource:
      url: jdbc:mysql://192.168.1.100:3306/appdb?useUnicode=true&characterEncoding=UTF-8&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC
      username: app_user
      password: mysqlAppPassword123
      driver-class-name: com.mysql.cj.jdbc.Driver
  ```
* **Python (SQLAlchemy / PyMySQL)**：
  ```python
  DATABASE_URI = "mysql+pymysql://app_user:mysqlAppPassword123@192.168.1.100:3306/appdb"
  ```
* **Linux 终端直接登录**：
  ```bash
  mysql -h 192.168.1.100 -P 3306 -u app_user -p'mysqlAppPassword123' appdb
  ```

#### 2. MongoDB 8.0 副本集群通用连接配置：
* **标准业务应用（推荐：零侵入、原生直连，无需任何 authSource 参数）**：
  ```yaml
  # Spring Boot application.yml
  spring:
    data:
      mongodb:
        uri: mongodb://mongo_app:mongoAppPassword123@192.168.1.100:27017/appdb?replicaSet=rs0
  ```
* **Python (PyMongo)**：
  ```python
  from pymongo import MongoClient
  client = MongoClient("mongodb://mongo_app:mongoAppPassword123@192.168.1.100:27017/appdb?replicaSet=rs0")
  db = client["appdb"]
  ```
* **跨库多微服务集中认证（如连入其他订单库、用户库）**：
  ```text
  mongodb://mongo_app:mongoAppPassword123@192.168.1.100:27017/<任意目标库>?authSource=admin&replicaSet=rs0
  ```

#### 3. Apache Kafka SASL 客户端配置 (`client.properties`)：
```properties
bootstrap.servers=192.168.1.100:9092
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
    username="app_user" \
    password="kafkaAppPassword123";
```

#### 4. Redis 6.2 哨兵与缓存通用连接：
```text
redis://:redisAuthPassword123@192.168.1.100:6379/0
```

---

### 0.4 其他第三方应用程序通用性与深度解答 (FAQ)

#### Q1: 为什么在命令行登录 Mongo 时有时带 `--authenticationDatabase admin`？我的其他应用程序直接连接会报错吗？
* **核心机制解析**：
  MongoDB 的用户并非全局平铺，而是**隶属于特定数据库（Authentication Database）**：
  * **集群 Root 管理员**（如 `admin` 账号）是创建在 `admin` 系统库中的，因此登录 `admin` 管理员账号必须指定认证源为 `admin`（即 `--authenticationDatabase admin` 或 URI 后的 `?authSource=admin`）。
  * **业务应用账号（`mongo_app`）**：在本项目初始化 Job 中，我们为该账号做到了**双向就绪（Dual-Ready）**：
    1. **原生业务库直连**：`mongo_app` 已直接注册在 `appdb` 内部，角色为 `readWrite` + `dbAdmin`。因此，您的任何通用应用程序（Spring Boot、Node.js Mongoose、Python PyMongo、Go）**只需使用最标准、最通用的连接串 `mongodb://mongo_app:pwd@192.168.1.100:27017/appdb?replicaSet=rs0` 即可直接连入，不需要传任何 `--authenticationDatabase` 参数！**
    2. **跨库全局授权**：同时在 `admin` 系统库中也为 `mongo_app` 赋予了 `readWriteAnyDatabase`。如果未来有多个微服务共用该账号访问各自独立的库（如 `order_db`），只需在 URI 附加 `?authSource=admin` 即可读写全集群任意库。

#### Q2: MySQL 的 `app_user` 其他微服务能通用吗？会不会报“Host '10.244.x.x' is not allowed to connect”或权限不足？
* **100% 通用无阻碍**：
  1. **通配主机 `%`**：本项目的 MySQL 初始化脚本自动将 `app_user` 授权为主机通配符 `'app_user'@'%'`，无论是 K8s 内部 Pod（`10.244.x.x`）、宿主机局域网（`192.168.1.x`）还是外部客户端均可自由连接。
  2. **全局多库权限**：自动赋予 `GRANT ALL PRIVILEGES ON *.* TO 'app_user'@'%' WITH GRANT OPTION;`。您的其他应用不仅可以操作默认的 `appdb`，还能自由创建新数据库（`CREATE DATABASE service_b;`）并拥有完全读写管理权限。
  3. **认证协议向下兼容**：MySQL 8.x 默认的 `caching_sha2_password` 会导致很多旧版 Java 驱动、PHP 或 Python 报插件不支持错误。本项目已在 `my.cnf` 与用户创建中统一采用 `mysql_native_password`，保证 100% 的通用兼容性。

#### Q3: 如果我的其他应用程序想要创建完全隔离的独立账号与数据库，怎么操作？
* **MySQL 创建新微服务账号（1行命令）**：
  ```bash
  mysql -h 192.168.1.100 -P 3306 -u root -p'mysqlRootPassword123' -e "
    CREATE DATABASE IF NOT EXISTS order_service;
    CREATE USER 'order_app'@'%' IDENTIFIED WITH mysql_native_password BY 'OrderStrongPass123!';
    GRANT ALL PRIVILEGES ON order_service.* TO 'order_app'@'%';
    FLUSH PRIVILEGES;
  "
  ```
* **MongoDB 创建新微服务独立账号（1行命令）**：
  ```bash
  mongosh "mongodb://192.168.1.100:27017/admin?replicaSet=rs0" -u admin -p'mongoAdminPassword123' --eval "
    db.getSiblingDB('order_service').createUser({
      user: 'order_app',
      pwd: 'OrderStrongPass123!',
      roles: [{ role: 'readWrite', db: 'order_service' }, { role: 'dbAdmin', db: 'order_service' }]
    });
  "
  # 创建后，该微服务即可原生标准直连，无需任何 admin 认证源：
  # mongodb://order_app:OrderStrongPass123!@192.168.1.100:27017/order_service?replicaSet=rs0
  ```

---

### 0.5 统一账号密码体系下：微服务如何知道密码并完成登录？(4 大标准分发姿势)

既然所有微服务共用同一套通用账号密码（如 `mongo_app` / `app_user`），**微服务本身如何“知道”这个密码？**在生产和开发环境中有 4 种标准的优雅分发方式：

#### 姿势 1：Kubernetes 内部微服务 Pod 自动挂载 Secret（云原生最推荐，零密码泄露）
如果你的微服务部署在当前 K8s 集群中，**开发者完全不需要在代码或配置文件里写死密码**！直接在微服务的 Deployment YAML 中引用集群已自动建好的 Secret：
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: data-platform
spec:
  template:
    spec:
      containers:
        - name: app
          image: my-registry/order-service:v1.0
          env:
            # 1. 自动从 Secret 注入 Mongo 密码与用户名
            - name: MONGO_USER
              valueFrom:
                secretKeyRef:
                  name: mongodb-auth
                  key: app-user
            - name: MONGO_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mongodb-auth
                  key: app-password
            # 2. 动态拼装通用直连 URI (无需人工记密码)
            - name: SPRING_DATA_MONGODB_URI
              value: "mongodb://$(MONGO_USER):$(MONGO_PASSWORD)@mongodb:27017/appdb?replicaSet=rs0"

            # 3. 自动注入 MySQL 密码与连接串
            - name: MYSQL_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-credentials
                  key: app-password
            - name: SPRING_DATASOURCE_URL
              value: "jdbc:mysql://mysql:3306/appdb?useSSL=false&allowPublicKeyRetrieval=true"
            - name: SPRING_DATASOURCE_USERNAME
              value: "app_user"
            - name: SPRING_DATASOURCE_PASSWORD
              value: "$(MYSQL_PASSWORD)"
```
> **优势**：密码由 Kubernetes 负责安全注入，微服务代码中只读取环境变量，后期更改密码只需修改一次 Secret，全集群微服务自动生效！

---

#### 姿势 2：通过微服务配置中心集中分发 (Nacos / Apollo / Spring Cloud Config)
大型微服务项目通常具备配置中心。你只需在配置中心的**公共共享组（如 `common-datasource.yaml`）**里配置一次：
```yaml
# Nacos / Apollo 公共配置: common-datasource.yaml
spring:
  data:
    mongodb:
      uri: mongodb://mongo_app:mongoAppPassword123@192.168.1.100:27017/appdb?replicaSet=rs0
  datasource:
    url: jdbc:mysql://192.168.1.100:3306/appdb?useSSL=false&allowPublicKeyRetrieval=true
    username: app_user
    password: mysqlAppPassword123
```
所有 10~50 个微服务（用户服务、订单服务、支付服务等）启动时默认加载 `common-datasource.yaml`，**任何微服务开发者都不需要单独维护密码，启动即连通**。

---

#### 姿势 3：通过环境变量文件分发 (Docker / Docker Compose / 物理机 VM)
对于运行在独立 Docker 容器或虚拟机上的微服务：
1. 本系统在根目录下已生成标准环境变量文件 `credentials.env`；
2. 启动容器时直接附加 `--env-file` 参数，或在 docker-compose 中引用：
   ```yaml
   services:
     order-service:
       image: order-service:latest
       env_file:
         - credentials.env
   ```
微服务内部直接读取 `process.env.MONGO_APP_PASSWORD` 或 `${MONGO_APP_PASSWORD}`。

---

#### 姿势 4：CI/CD 自动化流水线直接通过 HTTP API 拉取
运维或 CI/CD 构建脚本无需打开网页查看密码，直接请求控制台提供的 API：
```bash
# 获取所有实时密码的 JSON 清单
curl -s http://192.168.1.100:3000/api/credentials

# 提取 Mongo 密码示例:
MONGO_PWD=$(curl -s http://192.168.1.100:3000/api/credentials | grep -o '"MONGO_APP_PASSWORD":"[^"]*' | cut -d'"' -f4)
```

---

### 0.6 Spring Cloud / ZooKeeper 多模块微服务集群对接实战 (以 Gateway + 子服务为例)

针对多模块微服务架构（如带有 `gateway` 作为流量入口、各个子模块通过 `git-commit-id-plugin` 生成构建包并注册到 **ZooKeeper** 的 Spring Cloud / Dubbo 系统），在本项目环境中的标准集成步骤如下：

#### 1. 注册中心连接 (ZooKeeper)
本项目已在 `data-platform` 命名空间中部署了 3 节点高可用 ZooKeeper 集群（端口 `2181`）。
* **集群内微服务连接串**：
  ```properties
  spring.cloud.zookeeper.connect-string=zookeeper:2181
  ```
* **K8s Pod 服务发现关键参数**：
  由于 Pod 之间通过 Calico/Flannel 容器网络互通，微服务注册到 ZooKeeper 时**必须优先使用 Pod IP**，防止被识别为无解析的主机名：
  ```yaml
  spring:
    cloud:
      zookeeper:
        connect-string: zookeeper:2181
        discovery:
          enabled: true
          prefer-ip-address: true # 关键：使用 Pod IP 注册，保证 Gateway 路由能直接连通
          instance-host: ${POD_IP:}
  ```

#### 2. Gateway API 入口网关暴露与路由
`gateway` 作为全平台的外部调用统一入口：
1. **路由到各个子微服务**：利用 Spring Cloud Gateway 动态服务发现，根据服务名做负载均衡：
   ```yaml
   spring:
     cloud:
       gateway:
         discovery:
           locator:
             enabled: true
             lower-case-service-id: true
         routes:
           - id: service-route
             uri: lb://auth-service # 自动从 ZooKeeper 获取各微服务实例列表
             predicates:
               - Path=/api/auth/**
   ```
2. **在 K8s 中通过 NodePort 或 VIP 暴露 Gateway**：
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: microservice-gateway
     namespace: data-platform
   spec:
     type: NodePort
     selector:
       app: gateway
     ports:
       - port: 8080
         targetPort: 8080
         nodePort: 30080 # 外部访问: http://192.168.1.100:30080
   ```

#### 3. 带有 `git-commit-id-plugin` 的微服务打包与 Dockerfile
在 Maven 父工程根目录下，可以单独编译指定子模块：
```bash
# 只编译打包 gateway 模块
mvn clean package -pl gateway -am -DskipTests

# 批量编译打包所有子微服务
mvn clean package -DskipTests
```
通用微服务 Dockerfile 范式：
```dockerfile
FROM eclipse-temurin:21-jre-alpine # Java 21 LTS 官方轻量运行时镜像
WORKDIR /app
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar
ENV JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC"
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
```

---

## 1. 【完整手册】一步步完成所有基础组件的安装过程 (3-Master K8s 与全套分布式中间件实战指南)

> **本节定位**：这是一份**零歧义、可完全复制粘贴、一步步落地**的生产级安装手册。涵盖从裸机/虚拟机环境初始化、Containerd 运行时、Keepalived+HAProxy 高可用入口、3-Master Kubernetes 集群、Helm 3 与 k9s 工具，到打通“当前管控环境”，再到全套 8 大分布式中间件（MinIO S3、ZooKeeper、Kafka KRaft、MySQL 8.4、MongoDB 8.0、Redis 哨兵、Flink 2.2、Nginx 网关，统一基于 **Java 21 LTS**）的分步安装、配置与联通验证。

---

### 1.1 基础组件全局规划与全套组件矩阵表

在开始安装前，请确认所有基础组件的版本规格与技术指标：

| 层次类型 | 基础组件名称 | 生产版本 | 运行时/依赖 | 关键端口 | 职责定位与高可用机制 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **系统底层** | **Containerd** | 1.7.x / 最新 | SystemdCgroup | unix:///run/containerd/containerd.sock | 业界标准容器运行时，取代 Docker-shim |
| **网络网关** | **Keepalived** | 2.2.x+ | VRRP 协议 | 组播 / 心跳 | 提供高可用浮动 VIP (`192.168.1.100`)，主宕自漂 |
| **负载均衡** | **HAProxy** | 2.8.x+ | 四层 TCP 转发 | `6443` | 负责分发 API Server 请求到 3 台 Master |
| **容器编排** | **Kubernetes** | v1.29.6+ | Go 1.22 / CRI | `6443`, `10250` | 3 节点控制面 + 兼任 Worker 计算/存储节点 |
| **容器网络** | **Flannel / Calico** | 最新稳定版 | VXLAN / BGP | UDP 8472 / 4789 | 提供跨物理主机的 Pod 虚拟平坦互联网络 |
| **管理工具** | **Helm 3** | v3.14.x+ | Go 二进制 | - | 云原生组件包管理与配置参数驱动工具 |
| **管理工具** | **k9s** | v0.32.x+ | 终端图形界面 | - | Linux 终端全屏实时监控看板与秒级排障 |
| **核心运行时**| **Java Runtime** | **Java 21 LTS** | Eclipse Temurin | - | 全栈统一现代化 LTS 运行底座 (Kafka/ZK/Flink) |
| **对象存储** | **MinIO S3** | 最新分布式版 | 纯分布式 4 驱动 | `9000` (API), `9001` (Web) | 全局中央对象存储，承担 Flink 状态与冷备归档 |
| **协调仲裁** | **Apache ZooKeeper**| 3.9.3 | Java 21 LTS | `2181` (客户端), `2888/3888` | 3 节点 Quorum 仲裁集群 (SASL Digest-MD5 认证) |
| **消息中间件**| **Apache Kafka** | 4.0.1 (KRaft) | Java 21 原生 | `9092` (业务), `9093` (控制器) | 3 节点无 ZooKeeper 原生 KRaft 分布式消息流 |
| **关系型数据**| **MySQL** | 8.4.6 LTS | C++ / InnoDB | `3306` | 1 主 2 从 GTID 复制 + S3 定时冷备份 sidecar |
| **文档型数据**| **MongoDB** | 8.0.9 | C++ / WiredTiger | `27017` | 3 节点副本集 (`rs0`) + Keyfile 内部鉴权 + SCRAM |
| **内存与哨兵**| **Redis** | 6.2.6-alpine | C / 内存快照 | `6379` (数据), `26379` (哨兵) | 1 主 2 从 + 3 哨兵仲裁，微秒级缓存与故障切换 |
| **流式计算** | **Apache Flink** | 2.2.0 | Java 21 LTS | `8081` (Web), `6123` (RPC) | 1 JobManager + 3 TaskManager，S3 状态后端 |
| **接入网关** | **Nginx** | 1.27-alpine | 高性能 C | `8088` (业务), `30088` (NodePort) | 挂载宿主机 `/data/frontend/dist` 实现免重构更新 |

---

### 1.2 节点网络拓扑规划

本架构以 **3 台物理机 / 虚拟机** 构建高可用控制面与计算存储一体化架构，外加“当前管控机”进行联通：

```
+----------------------------------------------------------------------------------------------------+
|                               【当前管控环境 / 本开发与部署机】                                       |
|                                                                                                    |
|  • Web 运维管理控制台 (React 19 SPA)                • 后端引擎 (Express: /api/k8s/...)             |
|  • 凭证中心 (credentials.env & custom.yaml)        • Helm 部署套件 (helm/ & scripts/)              |
|  • 运行模式: SIMULATOR=false (直连集群下发)          • 访问凭据: ~/.kube/config (指向 VIP:6443)      |
+--------------------------------------------------+-------------------------------------------------+
                                                   |
                                [mTLS 6443 双向加密认证 / Helm 交付 / Pod 监控]
                                                   |
                                                   v
+----------------------------------------------------------------------------------------------------+
|                          【高可用虚拟浮动入口 VIP: 192.168.1.100】                                  |
|                    Keepalived VRRP 心跳漂移 (自动主备切换) + HAProxy 6443 轮询负载均衡                  |
+---------------------------+------------------------------+-----------------------------------------+
                            |                              |                                         |
                            v                              v                                         v
             +------------------------------+ +------------------------------+ +------------------------------+
             |        k8s-master-01         | |        k8s-master-02         | |        k8s-master-03         |
             |        (192.168.1.101)       | |        (192.168.1.102)       | |        (192.168.1.103)       |
             +------------------------------+ +------------------------------+ +------------------------------+
             |  • Keepalived (Master)       | |  • Keepalived (Backup)       | |  • Keepalived (Backup)       |
             |  • HAProxy (6443 监听)       | |  • HAProxy (6443 监听)       | |  • HAProxy (6443 监听)       |
             |  • kube-apiserver / etcd-0   | |  • kube-apiserver / etcd-1   | |  • kube-apiserver / etcd-2   |
             |  • kube-scheduler / cm       | |  • kube-scheduler / cm       | |  • kube-scheduler / cm       |
             +------------------------------+ +------------------------------+ +------------------------------+
             |   【解除 Taint 兼任 Worker】  | |   【解除 Taint 兼任 Worker】  | |   【解除 Taint 兼任 Worker】  |
             |  • Mongo Pod-0 (Primary)     | |  • Mongo Pod-1 (Secondary)   | |  • Mongo Pod-2 (Secondary)   |
             |  • Kafka 4.0.1 (KRaft-0)     | |  • Kafka 4.0.1 (KRaft-1)     | |  • Kafka 4.0.1 (KRaft-2)     |
             |  • ZK 3.9.3 (Server 1)       | |  • ZK 3.9.3 (Server 2)       | |  • ZK 3.9.3 (Server 3)       |
             |  • MySQL 8.4 (Leader)        | |  • MySQL 8.4 (Follower 1)    | |  • MySQL 8.4 (Follower 2)    |
             |  • Redis 6.2 (Master)        | |  • Redis 6.2 (Slave 1)       | |  • Redis 6.2 (Slave 2)       |
             |  • Flink 2.2 (JobManager)    | |  • Flink 2.2 (TaskManager 1) | |  • Flink 2.2 (TaskManager 2) |
             |  • MinIO S3 (Drive 1)        | |  • MinIO S3 (Drive 2)        | |  • MinIO S3 (Drive 3/4)      |
             |  • Nginx 网关 (Pod-0)        | |  • Nginx 网关 (Pod-1)        | |  • Nginx 网关 (Pod-2)        |
             +------------------------------+ +------------------------------+ +------------------------------+
```

---

### 1.3 第一步：操作系统优化与系统级底座基础组件安装

> **执行目标节点**：所有 3 台 Master 机器（`192.168.1.101`, `192.168.1.102`, `192.168.1.103`）。

#### 1. 禁用 Swap 分区（Kubernetes 强依赖）
```bash
# 立即关闭当前 swap
sudo swapoff -a

# 永久从 fstab 中注销 swap 分区
sudo sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab
```

#### 2. 加载 Linux 内核网络模块
```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

#### 3. 配置内核 Sysctl 桥接网络与 IPv4 转发参数
```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# 使内核参数立即生效
sudo sysctl --system
```

#### 4. 配置 Chrony 时间同步（分布式 etcd / Kafka / Mongo 强依赖时间一致性）
```bash
sudo apt-get update && sudo apt-get install -y chrony curl wget iptables ebtables ethtool socat conntrack
sudo systemctl enable --now chrony
chronyc tracking
```

---

### 1.4 第二步：容器运行时底座安装与配置 (Containerd + SystemdCgroup)

> **执行目标节点**：所有 3 台 Master 机器。

```bash
# 1. 安装 containerd 软件包
sudo apt-get install -y containerd

# 2. 生成默认配置文件
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# 3. 关键配置：将 cgroup 驱动修改为 systemd (K8s 强要求)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# 4. (国内网络可选) 配置 pause 基础镜像加速
sudo sed -i 's#sandbox_image = "registry.k8s.io/pause:3.8"#sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.9"#g' /etc/containerd/config.toml

# 5. 重启并设置开机自启
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo systemctl restart containerd

# 6. 验证运行时状态
sudo crictl info | grep -i 'runtimeReady'
```

---

### 1.5 第三步：高可用控制面入口基础组件配置 (Keepalived VIP + HAProxy)

为保障 3 台 Master 节点的 API Server（6443 端口）在任意一台主机硬件宕机时不中断，需在 3 台 Master 上配置 Keepalived 漂移 VIP 与 HAProxy 负载均衡。

> **自动化脚本快速执行（推荐）**：
```bash
# 在 3 台 Master 分别运行：
sudo ./scripts/k8s-ha-setup/setup-haproxy-keepalived.sh 192.168.1.100 auto 192.168.1.101 192.168.1.102 192.168.1.103
```

> **手动配置分步说明**：

#### 1. 安装 Keepalived 与 HAProxy
```bash
sudo apt-get install -y keepalived haproxy
```

#### 2. 配置 HAProxy (`/etc/haproxy/haproxy.cfg`)
在 3 台机器上写入相同的反代负载均衡配置：
```haproxy
global
    log /dev/log local0
    maxconn 4000
    daemon

defaults
    mode tcp
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend k8s_apiserver_frontend
    bind 0.0.0.0:6443
    mode tcp
    default_backend k8s_apiserver_backend

backend k8s_apiserver_backend
    mode tcp
    balance roundrobin
    option tcp-check
    server k8s-master-01 192.168.1.101:6443 check fall 3 rise 2
    server k8s-master-02 192.168.1.102:6443 check fall 3 rise 2
    server k8s-master-03 192.168.1.103:6443 check fall 3 rise 2
```

#### 3. 配置 Keepalived (`/etc/keepalived/keepalived.conf`)
* **在 Master 01 (`192.168.1.101`) 上设置为 MASTER，priority 101**：
```keepalived
vrrp_script check_haproxy {
    script "killall -0 haproxy"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state MASTER
    interface eth0          # 或通过 ip route get 8.8.8.8 探测的实际网卡
    virtual_router_id 51
    priority 101
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass K8sHaVipPasswd123
    }
    virtual_ipaddress {
        192.168.1.100/24
    }
    track_script {
        check_haproxy
    }
}
```
* **在 Master 02 (`192.168.1.102`) 与 Master 03 (`192.168.1.103`) 上设置为 BACKUP，priority 分别为 100 与 99**。

#### 4. 启动服务并验证 VIP 绑定
```bash
sudo systemctl enable --now haproxy keepalived
sudo systemctl restart haproxy keepalived

# 在 Master 01 检查 VIP 绑定
ip addr show | grep 192.168.1.100
```
如看到 `inet 192.168.1.100/24 scope global secondary`，说明浮动 VIP 已就绪。

---

### 1.6 第四步：Kubernetes 核心底座安装与 3-Master 集群初始化 (kubeadm/CNI/污点消除)

#### 1. 安装 Kubernetes 基础工具包 (在 3 台 Master 执行)
```bash
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg --yes
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
```

#### 2. 在 Master 01 (`192.168.1.101`) 初始化控制面高可用集群
```bash
sudo ./scripts/k8s-ha-setup/init-masters.sh 192.168.1.100
```
或直接通过命令行初始化：
```bash
sudo kubeadm init \
  --control-plane-endpoint "192.168.1.100:6443" \
  --upload-certs \
  --pod-network-cidr=10.244.0.0/16 \
  --image-repository=registry.aliyuncs.com/google_containers

# 自动建立本地凭据
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 安装 Flannel 容器 CNI 跨主机网络
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

#### 3. 核心关键步：消除 Master 污点（兼任 Worker，物尽其用）
中小型集群中 3 台机器需要同时作为数据计算与存储节点：
```bash
# 解除控制面污点，允许第三方数据库和 Pod 在 3 台 Master 上调度
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
```

#### 4. 将 Master 02 与 Master 03 加入控制面
在 Master 01 初始化完成时终端打印出的控制面加入命令，复制到 Master 02 与 Master 03 终端执行：
```bash
sudo kubeadm join 192.168.1.100:6443 \
  --token <YOUR_TOKEN> \
  --discovery-token-ca-cert-hash sha256:<YOUR_HASH> \
  --control-plane --certificate-key <YOUR_CERT_KEY>
```

#### 5. 验证 3-Master 集群状态
```bash
kubectl get nodes -o wide
```
预期输出：3 个节点均处于 **`Ready`** 状态，且各节点的 INTERNAL-IP 分别为 `.101`, `.102`, `.103`。

---

### 1.7 第五步：集群管控工具基础组件安装 (Helm 3 与 k9s 终端控制台)

#### 1. 安装 Helm 3 客户端
```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

#### 2. 安装 k9s 终端全屏图形控制台
```bash
curl -sS -L https://github.com/derailed/k9s/releases/download/v0.32.4/k9s_Linux_amd64.tar.gz | sudo tar -xz -C /usr/local/bin k9s
sudo chmod +x /usr/local/bin/k9s
k9s version
```

---

### 1.8 第六步：全栈 Java 21 LTS 基础开发与运行时环境就绪

本项目所有大数据与消息组件（Kafka 4.0.1、ZooKeeper 3.9.3、Flink 2.2.0）均基于 **Java 21 LTS** 现代化运行时。

在机器上安装 Java 21 LTS：
```bash
# Ubuntu / Debian 安装 Eclipse Temurin OpenJDK 21
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg --yes
echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/adoptium.list
sudo apt-get update && sudo apt-get install -y temurin-21-jdk

# 验证版本
java -version
```
输出应包含：`openjdk version "21.0.x"`。

---

### 1.9 第七步：打通“我的这一个管控环境”与 3-Master K8s 集群

所谓**“我的这一个管控环境”**，就是当前运行本 CloudCluster Web 控制台与管理脚本的机器（宿主机或开发者管理机）。

#### 1. 验证管控环境到高可用 VIP 的连通性
```bash
# 验证网络层 ping 通
ping -c 3 192.168.1.100

# 验证 API Server 6443 握手 (返回 401/403 即表示链路畅通)
curl -k https://192.168.1.100:6443/version
```

#### 2. 同步集群凭证 (Kubeconfig) 到当前环境
```bash
mkdir -p ~/.kube
scp root@192.168.1.101:/etc/kubernetes/admin.conf ~/.kube/config
chmod 600 ~/.kube/config

# 确保配置文件中的服务器地址统一指向 VIP: 192.168.1.100:6443
sed -i 's#server: https://.*:6443#server: https://192.168.1.100:6443#g' ~/.kube/config

# 验证测试
kubectl get nodes
```

#### 3. 切换当前环境为 Real Host (真实集群生效模式)
在项目根目录下配置 `.env`：
```bash
echo "SIMULATOR=false" >> .env
```
或在 Web 界面 Header 处点击切换为 **`[⚡ Real Host (Live)]`**。

#### 4. 生成强密码体系文件
```bash
bash scripts/init-credentials.sh
```
该命令会自动生成 `credentials.env` 并注入至 `helm/custom-credentials.yaml`，保障全栈强制认证。

---

### 1.10 第八步：全套 8 大分布式基础组件分步安装实战

您可以选择 **方式 A（Helm 一键批量部署）** 或 **方式 B（逐个基础组件分步部署）**：

#### 方式 A：Helm 一键自动化批量交付（最推荐）
```bash
chmod +x ./scripts/helm-install.sh
./scripts/helm-install.sh data-platform cloudcluster helm/values.yaml
```

---

#### 方式 B：各基础组件分步独立部署与配置详解

##### 1. 基础组件：MinIO S3 分布式对象存储集群 (4 副本)
* **作用**：全平台中央对象存储，承担 Flink Checkpoints 状态快照与 MySQL/MongoDB 定时冷备文件存储。
* **部署命令**：
  ```bash
  helm upgrade --install minio ./helm \
    --namespace data-platform --create-namespace \
    --set flink.enabled=false --set kafka.enabled=false --set mysql.enabled=false \
    --set mongodb.enabled=false --set redis.enabled=false --set zookeeper.enabled=false \
    --set nginx.enabled=false
  ```
* **存储桶初始化与客户端配置**：
  ```bash
  # 安装 mc 客户端并配置别名
  curl https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc
  chmod +x /usr/local/bin/mc
  mc alias set myminio http://192.168.1.100:9000 minioAdmin minioAdminPassword123

  # 创建基础存储桶
  mc mb myminio/flink-checkpoints || true
  mc mb myminio/mysql-backups || true
  mc mb myminio/mongodb-backups || true
  mc ls myminio/
  ```

##### 2. 基础组件：Apache ZooKeeper 3.9.3 仲裁集群 (3 节点, Java 21 LTS)
* **作用**：提供微服务注册发现与分布式协调锁服务，默认启用 SASL Digest-MD5 安全认证。
* **部署与验证**：
  ```bash
  # 验证 ZooKeeper 3 个 Pod 运行状态
  kubectl get pods -n data-platform -l app=zookeeper -o wide

  # 进入容器验证节点状态
  kubectl exec -it -n data-platform zookeeper-0 -- zkServer.sh status
  ```
  输出示例：Mode 为 `follower` 或 `leader`，3 节点自动形成 Quorum。

##### 3. 基础组件：Apache Kafka 4.0.1 分布式消息队列 (KRaft 模式, Java 21 原生)
* **作用**：高吞吐事件流消息总线，彻底摒弃传统 ZooKeeper 依赖，采用现代化的 KRaft 协议共识。
* **部署与主题创建**：
  ```bash
  # 查看 Kafka 3 节点 Pod
  kubectl get pods -n data-platform -l app=kafka -o wide

  # 创建业务主题 (3 分区 3 副本高可用)
  kubectl exec -it -n data-platform kafka-0 -- /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --command-config /opt/kafka/config/client.properties \
    --create --topic telemetry-events --partitions 3 --replication-factor 3

  # 列出主题验证
  kubectl exec -it -n data-platform kafka-0 -- /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --command-config /opt/kafka/config/client.properties --list
  ```

##### 4. 基础组件：MySQL 8.4.6 LTS 高可用主从集群 (GTID 复制 + S3 备份 sidecar)
* **作用**：高可靠关系型事务数据库，包含 1 主 2 从读写分离结构及通配主机用户权限。
* **验证主从同步状态**：
  ```bash
  # 登录 MySQL 主节点验证 GTID
  kubectl exec -it -n data-platform mysql-0 -- mysql -uroot -pmysqlRootPassword123 -e "SHOW MASTER STATUS\G"

  # 登录从节点验证 Slave 复制线程
  kubectl exec -it -n data-platform mysql-1 -- mysql -uroot -pmysqlRootPassword123 -e "SHOW REPLICA STATUS\G"
  ```
  预期输出：`Replica_IO_Running: Yes` 与 `Replica_SQL_Running: Yes`。

##### 5. 基础组件：MongoDB 8.0.9 副本集集群 (3 节点副本集 rs0)
* **作用**：海量文档与灵活数据模型存储，配置 Keyfile 内部安全签名与 SCRAM-SHA-256 用户认证。
* **验证副本集状态**：
  ```bash
  kubectl exec -it -n data-platform mongodb-0 -- mongosh -u admin -p mongoAdminPassword123 --authenticationDatabase admin --eval "rs.status().members.map(m => ({name: m.name, stateStr: m.stateStr}))"
  ```
  预期输出：1 个 `PRIMARY` 与 2 个 `SECONDARY`。

##### 6. 基础组件：Redis 6.2.6 + Sentinel 哨兵缓存集群 (1 主 2 从 + 3 哨兵)
* **作用**：微秒级分布式缓存与 Session 存储，哨兵集群负责自动故障转移与拓扑监控。
* **验证主从与哨兵监控**：
  ```bash
  # 验证 Redis 主从角色
  kubectl exec -it -n data-platform redis-0 -- redis-cli -a redisAuthPassword123 info replication

  # 验证 Sentinel 哨兵仲裁状态
  kubectl exec -it -n data-platform redis-sentinel-0 -- redis-cli -p 26379 sentinel masters
  ```

##### 7. 基础组件：Apache Flink 2.2.0 实时流计算集群 (Java 21 LTS + MinIO S3 Checkpoint)
* **作用**：大规模流批一体计算引擎，1 JobManager + 3 TaskManager 弹性槽位，检查点直写 MinIO S3。
* **验证状态**：
  ```bash
  # 检查 Flink 集群 Pods
  kubectl get pods -n data-platform -l app=flink -o wide

  # 查看 Flink Web 概览 API (HTTP Basic 鉴权)
  curl -u flinkAdmin:flinkAdminPassword123 http://192.168.1.100:8081/overview
  ```

##### 8. 基础组件：Nginx 1.27 前端接入与反代网关 (挂载宿主机免重构)
* **作用**：3 副本高可用反向代理，静态前端资源直接挂载宿主机 `/data/frontend/dist`，实现热更新与动静分流。
* **宿主机目录初始化与验证**：
  ```bash
  # 在 3 台 Master 宿主机上准备前端挂载目录
  sudo mkdir -p /data/frontend/dist /data/frontend/logs
  sudo chmod -R 755 /data/frontend

  # 检查 Nginx Pod 状态与 NodePort 端口暴露
  kubectl get svc -n data-platform nginx-service
  ```

---

### 1.11 第九步：所有基础组件健康检查、冒烟测试与端口总汇

在完成全部安装后，执行以下标准巡检测试：

#### 1. 全集群 Pod 状态全局概览
```bash
kubectl get pods -n data-platform -o wide
```
**合格标准**：所有 Pod 处于 `Running` 状态，且副本均匀分布在 `k8s-master-01`, `k8s-master-02`, `k8s-master-03` 上。

#### 2. 一键冒烟测试命令清单 (从当前环境执行)
```bash
echo "=== 1. 测试 MinIO S3 API (9000) ==="
curl -s -I http://192.168.1.100:9000/minio/health/live | head -n 1

echo "=== 2. 测试 Flink 仪表盘 (8081) ==="
curl -s -u flinkAdmin:flinkAdminPassword123 http://192.168.1.100:8081/jobmanager/config | head -n 1

echo "=== 3. 测试 MySQL 8.4 连接 (3306) ==="
mysql -h 192.168.1.100 -P 3306 -u app_user -pmysqlAppPassword123 -e "SELECT @@version, @@gtid_mode;"

echo "=== 4. 测试 MongoDB 8.0 副本集 (27017) ==="
mongosh "mongodb://mongo_app:mongoAppPassword123@192.168.1.100:27017/appdb?replicaSet=rs0" --eval "db.runCommand({ping: 1})"

echo "=== 5. 测试 Redis 6.2 读写 (6379) ==="
redis-cli -h 192.168.1.100 -p 6379 -a redisAuthPassword123 ping

echo "=== 6. 测试 Nginx 前端 Web 访问 (30088) ==="
curl -s -I http://192.168.1.100:30088/ | head -n 1
```

#### 3. 全套组件对外访问地址速查：
* **业务前端系统**：`http://192.168.1.100:30088`
* **MinIO S3 控制台**：`http://192.168.1.100:9001` (账号: `minioAdmin` / `minioAdminPassword123`)
* **Flink 管理看板**：`http://192.168.1.100:8081` (账号: `flinkAdmin` / `flinkAdminPassword123`)
* **Kafka 业务连接串**：`192.168.1.100:9092` (SASL_PLAINTEXT: `app_user` / `kafkaAppPassword123`)
* **MySQL 业务连接串**：`192.168.1.100:3306` (账号: `app_user` / `mysqlAppPassword123`)
* **MongoDB 连接串**：`mongodb://mongo_app:mongoAppPassword123@192.168.1.100:27017/appdb?replicaSet=rs0`
* **Redis 缓存连接串**：`redis://:redisAuthPassword123@192.168.1.100:6379/0`
* **k9s 终端实时监控**：在终端直接运行 `k9s -n data-platform`

---

### 1.12 第十步：外部 Git (GitHub / GitLab / Gitee) 网络访问与拉取指南

在物理机部署或容器运行过程中，经常需要拉取外部 Git 仓库的代码、Helm Chart 或配置文件。

#### 1. 默认网络连通性
* **物理宿主机**：只要宿主机配置了默认网关（Default Gateway）并开通了外网访问（DNS 8.8.8.8 / 114.114.114.114 可达），即可直接运行 `git clone https://github.com/...`。
* **Kubernetes Pod 内部**：Pod 通过 CNI（Calico/Flannel）提供的 SNAT（源地址转换/IP伪装）借用物理网卡直接出网，同样可以直接访问外部 Git。

#### 2. 测试外网 Git 连通性快速命令
在任意 Master 节点或终端执行以下命令，验证是否能连通外部 Git：
```bash
# 测试 GitHub 连通性 (无需完整 clone，秒级握手探查)
git ls-remote https://github.com/torvalds/linux.git HEAD

# 测试 Gitee 连通性
git ls-remote https://gitee.com/oschina/git-osc.git HEAD
```
如果返回对应分支哈希值（如 `72d3fcf... HEAD`），说明外网 Git 通信 100% 正常。

#### 3. 国内机房访问 GitHub 慢或超时的加速方案
如果在国内物理机网络访问 GitHub 遇到超时，可使用以下主流方案：
* **方案 A：使用 GitHub 镜像加速代理（最简单）**：
  ```bash
  # 在原有 GitHub 地址前添加加速代理前缀:
  git clone https://ghproxy.net/https://github.com/your-org/your-repo.git
  # 或者针对全站 git 配置替换:
  git config --global url."https://ghproxy.net/https://github.com/".insteadOf "https://github.com/"
  ```
* **方案 B：导入国内 Gitee / 腾讯 Coding 镜像**：
  在 Gitee 上一键“从 GitHub 导入仓库”，然后直接克隆 Gitee 地址：
  ```bash
  git clone https://gitee.com/your-name/your-repo.git
  ```
* **方案 C：配置全局 HTTP 代理（如果有企业专线/代理网关）**：
  ```bash
  git config --global http.proxy http://192.168.1.254:7890
  git config --global https.proxy http://192.168.1.254:7890
  ```

#### 4. 访问私有 Git 仓库凭证配置 (Private Repo)
* **方式 1：使用 Personal Access Token (PAT)**：
  ```bash
  git clone https://<your-username>:<your-token>@github.com/your-org/private-repo.git
  ```
* **方式 2：在 Kubernetes 中注入 Git 凭证 Secret（供微服务或 CI/CD Pod 使用）**：
  ```bash
  kubectl create secret generic git-credentials \
    --namespace=data-platform \
    --type=kubernetes.io/basic-auth \
    --from-literal=username='<your-git-user>' \
    --from-literal=password='<your-git-pat-token>'
  ```

---

## 2. 节点环境初始化与 Kubernetes (k8s) & k9s 安装

> **适用范围**：在所有 3 台 Master 机器与后续所有扩展 Worker 物理机/虚拟机上均需执行本节环境初始化与组件安装。

### 方式 A：一键自动化脚本（推荐）
本项目已将系统调优、容器运行时与 Kubernetes 组件封装为自动化脚本，直接在目标机器执行：
```bash
chmod +x ./scripts/k8s-ha-setup/*.sh

# 1. 一键安装 containerd、kubeadm、kubelet、kubectl 并完成内核/Swap优化
sudo ./scripts/k8s-ha-setup/install-k8s-prerequisites.sh v1.29

# 2. 一键安装 k9s 终端图形化管理工具
sudo ./scripts/k8s-ha-setup/install-k9s.sh v0.32.4
```

---

### 方式 B：手动分步安装与原理解析

#### 步骤 2.1：操作系统优化与永久关闭 Swap
Kubernetes 要求节点必须关闭 Swap 分区，以确保 Pod 内存调度的精确与稳定性：
```bash
# 临时关闭 swap
sudo swapoff -a

# 永久关闭 swap（注释 /etc/fstab 中的 swap 挂载行）
sudo sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab
```

#### 步骤 2.2：加载内核模块与开启网络桥接与转发
加载 `overlay` 和 `br_netfilter` 模块，并配置 sysctl 允许 iptables 检查网桥流量：
```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

#### 步骤 2.3：安装与配置容器运行时 (containerd)
Kubernetes 默认采用 CRI 标准的 `containerd`，并需配置 systemd 作为 cgroup 驱动：
```bash
# Ubuntu / Debian 环境：
sudo apt-get update && sudo apt-get install -y containerd

# CentOS / RHEL 环境：
# sudo yum install -y containerd

# 生成默认配置并启用 SystemdCgroup
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# 重启并开机自启 containerd
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo systemctl restart containerd
```

#### 步骤 2.4：安装 Kubernetes 核心组件 (kubelet, kubeadm, kubectl)
从官方源安装对应版本的 Kubernetes 工具包（以 `v1.29` 为例）：
```bash
# Ubuntu 22.04 / Debian 环境：
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg --yes
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

# CentOS / RHEL 环境：
# cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
# [kubernetes]
# name=Kubernetes
# baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
# enabled=1
# gpgcheck=1
# gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
# EOF
# sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
# sudo systemctl enable --now kubelet
```

#### 步骤 2.5：安装与使用 K9s 终端图形化管理面板
K9s 是 Kubernetes 运维工程师最喜爱的终端全屏监控看板，无需繁琐的 `kubectl` 敲命令，即可图形化查看 Pod、资源消耗、实时日志并一键进入容器：
```bash
# 下载官方二进制安装包并解压至 /usr/local/bin
curl -sS -L https://github.com/derailed/k9s/releases/download/v0.32.4/k9s_Linux_amd64.tar.gz | sudo tar -xz -C /usr/local/bin k9s
sudo chmod +x /usr/local/bin/k9s

# 验证安装
k9s version
```

**K9s 快速操作命令与常用快捷键**：
* 启动终端看板：
  ```bash
  k9s -n data-platform      # 直接进入并实时监控 data-platform 业务组件
  ```
* 核心操作热键：
  * `:pods`：查看当前命名空间的所有 Pod 状态、CPU、内存实时消耗；
  * `l`：实时查看选中 Pod 的日志（Follow logs，类似 `tail -f`）；
  * `d`：执行 describe 查看详细事件（Events）与排错；
  * `s`：直接打开 Shell 进入选中的容器终端；
  * `:ns`：快速切换命名空间。

---

## 3. Master 节点高可用 (Keepalived + HAProxy)

### 关于网卡名称 (`INTERFACE`) 的疑问解答：
> **问：`./k8s-ha-setup.sh <VIP> <INTERFACE> ...` 中，INTERFACE 是 3 台机器都一样吗？**  
> **答：不一定一样！**  
> - 如果是相同规格的云主机（如 CentOS 统一叫 `eth0`，Ubuntu 统一叫 `ens3`），网卡名可能相同。
> - 如果是不同物理机或不同虚拟机（如有的机器是 `ens192`，有的是 `enp3s0`，有的是 `bond0`），网卡名各不相同。
> - **解决方案**：脚本已升级为**自动探测本机默认网卡**。如果你不确定，可传 `auto`，脚本会自动通过 `ip route get 8.8.8.8` 识别本机的有效网卡。

### 执行步骤（3台 Master 分别执行）：

在每台 Master 机器上执行：
```bash
chmod +x ./scripts/k8s-ha-setup/*.sh

# 参数说明: <VIP> <本机网卡名|auto> <MASTER1_IP> <MASTER2_IP> <MASTER3_IP>
sudo ./scripts/k8s-ha-setup/setup-haproxy-keepalived.sh 192.168.1.100 auto 192.168.1.101 192.168.1.102 192.168.1.103
```

检查 VIP 是否成功绑定（应在 Master 1 上看到 VIP）：
```bash
ip addr show | grep 192.168.1.100
systemctl status haproxy keepalived
```

> **接入终端模式支持 (VIP 或 域名)**：
> 1. **虚拟 IP 模式 (Virtual IP)**：例如 `192.168.1.100`，由 Keepalived VRRP 协议负责在 3 台 Master 之间做故障漂移。
> 2. **域名 FQDN 模式**：例如 `k8s-vip.internal.cloud`，由内网 DNS 或各节点 `/etc/hosts` 指向负载均衡器或 Master 节点，Kubeadm 自动将域名写入证书 SAN。
> 3. **后期动态修改**：在 Web 界面随时输入新 IP 或域名，点击【保存修改】后弹出安全确认窗口，确认后后端将**自动更新所有 8 个关联配置文件**并**自动重启 Keepalived、HAProxy、Kubelet 与 API Server**。

---

## 4. 初始化 3 台 Master/Worker 节点 (kubeadm init & join)

### 步骤 4.1：在 Master 1 (`192.168.1.101`) 初始化控制面
```bash
sudo ./scripts/k8s-ha-setup/init-masters.sh 192.168.1.100
```
该脚本将自动完成：
1. 传入 `--control-plane-endpoint "192.168.1.100:6443"` 并调用 `kubeadm init`。
2. 拷贝 `/etc/kubernetes/admin.conf` 到 `$HOME/.kube/config`。
3. 安装 Flannel CNI 网络插件。
4. **移除 Master 污点**，允许业务 Pod 在 Master 1 上运行。

输出中会包含两条 Join 命令：
- **Master 加入命令**（带 `--control-plane` 与 `--certificate-key`）。
- **Worker 加入命令**（普通 Token）。

### 步骤 4.2：将 Master 2 与 Master 3 加入控制面
在 `192.168.1.102` 与 `192.168.1.103` 上分别执行 Master 加入命令：
```bash
sudo kubeadm join 192.168.1.100:6443 \
  --token <YOUR_TOKEN> \
  --discovery-token-ca-cert-hash sha256:<YOUR_HASH> \
  --control-plane --certificate-key <YOUR_CERT_KEY>
```

加入后，在 Master 1 上验证 3 节点状态：
```bash
kubectl get nodes -o wide
```
应该看到 3 台机器状态均为 `Ready`。

---

## 5. Worker 节点扩展流程 (物理机/VM 手工执行 CLI)

因为 Worker 节点可能是新采购的物理服务器或新开的虚拟机，**必须在目标机器上人工/终端执行**。

### Web 界面操作：
1. 打开 Web 控制台：**"3-Master HA & Worker Nodes"** 标签页。
2. 在 **"Extend Cluster: Add New Worker Node"** 表单输入：
   - Worker 主机名（如 `k8s-worker-04`）
   - IP 地址（如 `192.168.1.104`）
   - 安装目录（默认 `/opt/kubernetes`）
3. 点击 **"Generate Worker Join CLI"**，弹出安全确认窗口。
4. 确认后，Web 界面将直接生成该主机的**专用初始化与加入命令**。

### 在新 Worker 物理机/VM 上执行：
登录新机器（`192.168.1.104`），直接粘贴运行：
```bash
# 1. 确保安装 containerd 与 kubeadm
sudo apt-get update && sudo apt-get install -y containerd kubeadm kubectl

# 2. 加入集群
sudo kubeadm join 192.168.1.100:6443 \
  --token <YOUR_TOKEN> \
  --discovery-token-ca-cert-hash sha256:<YOUR_HASH>
```

在 Master 上验证：
```bash
kubectl get nodes
```

---

## 6. 第三方应用集群部署 (Helm + Docker Hub, 全栈 Java 21 LTS)

本项目已将所有第三方组件镜像直接对接 **Global Docker Hub 官方镜像**，无需自行在本地构建 Dockerfile 即可启动：

- **MongoDB**: `mongo:8.0.9` (分片集群模式 Sharded Cluster: 2 Mongos 路由器 + 3 节点 ConfigServer CSRS + 2 分片 Shard0/Shard1 × 3 节点高可用)
- **Flink**: `flink:2.2-java21` (Java 21 LTS, 1 JobManager + N TaskManagers, 专职处理实时事件流计算，无需参与数据库副本复制)
- **Kafka**: `apache/kafka:4.0.1` (KRaft 原生模式, Java 21 LTS 原生构建, 3 节点 Raft 仲裁, 直连 MinIO S3 做数据归档)
- **ZooKeeper**: `zookeeper:3.9.3` (Java 21 LTS 兼容, 3 节点仲裁集群, client: 2181, peer: 2888, leader: 3888)
- **MySQL**: `mysql:8.4.6` (3 节点 GTID 主从复制)
- **Redis**: `redis:6.2.6-alpine` (3 节点 + Sentinel 仲裁)
- **MinIO**: `minio/minio:RELEASE.2024-04-18T19-09-19Z` (分布式 S3 存储)
- **Nginx**: `nginx:1.27-alpine` (前端 SPA 入口与反代网关, 宿主机目录 `/data/frontend/dist` 映射至 `/home/dci/web/dist`, 代码放外面无需重构镜像)

### Kafka 直连 MinIO S3 (无需经过 Flink)
数据流直写 S3 配置位于 `/scripts/kafka-connect/kafka-s3-sink-connector.json`，通过 Kafka Connect S3 Sink 直接拉取 Kafka 主题流式写入 MinIO S3 (`s3://flink-checkpoints/`)，极大精简系统链路，不占用 Flink 计算槽位。
执行命令启动：
```bash
./scripts/kafka-connect/start-kafka-s3-sink.sh http://localhost:8083
```

### 一键部署命令：
```bash
helm upgrade --install cloudcluster ./helm \
  --namespace data-platform \
  --create-namespace \
  -f ./helm/values.yaml
```

---

## 7. Pod 与组件弹性伸缩 (后端自动执行 vs CLI)

针对 Pod 级别组件（如 Flink TaskManager、Kafka 节点、Mongo 副本数）：

### 方式 A：Web 控制台后端直接执行
在 Web 界面的 **"Cluster & Flink Extension Center"** 中：
1. 点击 Flink TaskManager `+` 增加节点或 `-` 减少节点。
2. 弹出**强制安全确认窗口 (Confirmation Modal)**，展示：
   - 目标组件名称与当前 Pod 数量。
   - 槽位变化与任务受影响分析（如 Task Slots 从 12 变 20）。
   - 仲裁安全警告。
3. 点击 **"Confirm"** 后，Web 后端 API (`POST /api/k8s/scale`) 将**直接调用底层 Kubernetes 执行伸缩**，无需手动敲命令！

### 方式 B：终端手动 CLI 执行
```bash
# 伸缩 Flink TaskManagers 至 8 节点
helm upgrade cloudcluster ./helm -n data-platform --reuse-values --set flink.taskManager.replicas=8

# 伸缩 Kafka KRaft 节点至 5 节点
helm upgrade cloudcluster ./helm -n data-platform --reuse-values --set kafka.replicas=5
```

---

## 8. 后端执行模式配置 (Simulator 模式 vs 真实宿主机执行)

为防止开发/演示阶段误操作真实生产集群，系统内置了 `SIMULATOR` 配置开关：

### 配置方式：
1. **环境变量配置 (`.env` 或系统环境变量)**：
   ```bash
   # 开启模拟模式（只生成命令与模拟返回，不真实执行系统命令）
   export SIMULATOR=true

   # 关闭模拟模式（默认：直接在宿主机真实执行 helm / systemctl 等命令）
   export SIMULATOR=false
   ```
2. **Web 界面动态一键切换**：
   在页面顶部 Header 的 `Backend Mode` 开关处，可随时点击在 `[🧪 Simulator (Dry-run)]` 与 `[⚡ Real Host (Live)]` 之间热切换。
3. **返回规则**：
   - 当 `simulator=true` 时：返回 `mode: 'simulated_or_ready'`，不执行系统底层命令。
   - 当 `simulator=false` 时：命令直接在真实后端 Host Server 上执行：
     - 若执行成功，返回 `mode: 'live_k8s_applied'` 或 `mode: 'live_executed'` 并携带服务器真实 `stdout` 输出；
     - 若命令执行失败，直接返回 HTTP 500 与真实系统错误信息（`stderr` 及 `exitCode`），绝不隐瞒真实异常。

---

## 9. 3 台物理主机下 MySQL & MongoDB 持久化存储与 S3 冷备份实战 (方案 3 - 当前生效标准)

### 核心结论：直接挂载 S3 放数据目录不可行，但采用“本地盘 + S3 冷备份”是黄金标准！

> **为什么不能直接把 `/var/lib/mysql` 或 `/data/db` 挂载到 S3？**
> - **S3 是对象存储 (Object Storage)**，缺少 POSIX 字节级文件锁与原子扇区刷盘保证（`fsync()`）。
> - 若使用 s3fs 挂载，每次数据库 16KB 页更新需全量反复下载重传，延迟由 `<0.5ms` 暴增至 `500~1000ms+`，网络轻微抖动即可能导致**表空间彻底损坏**。

### 生产标准落地方案（方案 3）：

1. **日常高性能读写**：
   - 3 台物理机各自使用本地高速 NVMe/SSD 挂载路径（`/opt/kubernetes/data/`）。
   - 享受硬件原生满速 IOPS（100,000+）与微秒级响应延迟。
2. **MongoDB 采用 3 节点高可用副本集群 (ReplicaSet `rs0`)**：
   - 3 个 Pod 分布式调度在 3 台物理主机：`mongodb-0`（Master 1）、`mongodb-1`（Master 2）、`mongodb-2`（Master 3）；
   - 1 Primary + 2 Secondaries 构成 Raft 选举与 Oplog 同步链条，任一节点断电 3~5 秒内自动秒级无感选举新主库；
   - 业务访问入口统一通过集群 DNS：`mongodb.data-platform.svc.cluster.local:27017` 或 ReplicaSet 连接串：
     ```text
     mongodb://admin:mongoAdminPassword123@mongodb-0.mongodb-headless:27017,mongodb-1.mongodb-headless:27017,mongodb-2.mongodb-headless:27017/?replicaSet=rs0&authSource=admin
     ```
3. **跨机与灾难恢复安全兜底：MySQL & MongoDB 均开启 S3 冷备份，且 S3 严格只保留 3 份数据**：
   - **自动化 CronJob**：由 Kubernetes 定时触发，无锁抽取一致性快照与变更日志，流式上传到中央 MinIO / AWS S3 对象存储桶；
   - **3 份保留策略 (Retention Policy = 3)**：备份任务上传完成后，脚本自动对比时间戳，**自动销毁清理更早的历史备份，S3 桶内严格恒定只保留最新的 3 份冷备数据**，杜绝对象存储磁盘被写满；
   - **异地灾备**：即使 3 台物理机全部遭遇不可逆毁灭性硬件故障，也能从 S3 最新 3 份备份中瞬时恢复至期望时间点。

---

### S3 冷备份运维实战命令与灾难恢复演练

#### 1. 查看 MinIO S3 存储桶中的 3 份冷备文件（确认只保留 3 份）：
```bash
# 配置 MinIO 客户端 (mc)
mc alias set myminio http://192.168.1.100:9000 minioAdmin minioAdminPassword123

# 列出 MySQL 与 MongoDB 冷备份文件列表 (恒定仅 3 个文件)
mc ls myminio/mysql-backups/
mc ls myminio/mongodb-backups/
```

#### 2. 手动立即触发一次 S3 冷备份（验证备份并自动裁剪只留 3 份）：
```bash
# 手动触发 MongoDB 副本集群冷备份 Job
kubectl create job --from=cronjob/mongodb-backup-to-s3 manual-mongo-backup -n data-platform

# 手动触发 MySQL 8.4 冷备份 Job
kubectl create job --from=cronjob/mysql-backup-to-s3 manual-mysql-backup -n data-platform

# 检查备份 Pod 执行日志与自动裁剪旧备份的过程
kubectl logs -n data-platform -l app=mongodb-backup --tail=50
kubectl logs -n data-platform -l app=mysql-backup --tail=50
```

#### 3. 灾难恢复演练（从 S3 拉取冷备份文件一键还原）：

* **从 S3 还原 MongoDB 副本集群数据**：
  ```bash
  # 下载 S3 最新冷备归档文件
  mc cp myminio/mongodb-backups/mongo_latest.archive.gz /tmp/mongo_restore.archive.gz

  # 通过 mongorestore 流式回放恢复（含 Oplog 事务）
  mongorestore --host="mongodb-0.mongodb-headless:27017" \
    --username="admin" --password="mongoAdminPassword123" --authenticationDatabase="admin" \
    --oplogReplay --archive=/tmp/mongo_restore.archive.gz --drop
  ```

* **从 S3 还原 MySQL 8.4 数据库**：
  ```bash
  # 下载 S3 最新 SQL 归档压缩包
  mc cp myminio/mysql-backups/mysql_latest.sql.gz /tmp/mysql_restore.sql.gz

  # 解压并流式导入 MySQL 主节点
  gunzip < /tmp/mysql_restore.sql.gz | mysql -h mysql-0.mysql-headless -u root -pmysqlRootPassword123
  ```

---

## 10. Nginx 前端入口网关配置与优化实战 (代码放 Docker 外面免重构镜像)

### 9.1 设计初衷与核心价值
传统 Docker 化前端每次代码改动都需要：`npm run build` -> `docker build` -> `docker push` -> `kubectl rollout restart`，发布链路长、镜像仓库冗余、更新延迟高。
**本项目黄金落地标准**：
1. **优先部署在 3 个 Master 节点**：通过 Kubernetes `tolerations` 容忍控制面污点，配合 `podAntiAffinity` 优先在 3 台 Master 物理机各运行 1 个 Pod，直通 Keepalived VIP `192.168.1.100`；
2. **后期支持在 Worker 节点自由扩展**：集群加入新 Worker 主机后，无需修改架构，直接 `kubectl scale deployment nginx-entry --replicas=5`，调度器自动平滑调度至 Worker 节点；
3. **静态代码放在宿主机外面**：物理机通过统一路径（`/data/frontend/dist/`）存放前端打包产物；
4. **K8s HostPath 热映射**：Nginx 容器只负责高性能 Web 引擎和反代，通过 Volume 挂载宿主机 `/data/frontend/dist`；
5. **零重构镜像、秒级热更新**：前端 CI/CD 构建完成后，仅需 `rsync` 或 `scp` 覆盖宿主机目录，用户浏览器刷新即可即刻加载新版本！

### 9.2 优化后的 `nginx.conf` 核心提升亮点
1. **单页面应用 (SPA) 路由防 404**：
   - 增加 `try_files $uri $uri/ /index.html;`，用户在浏览器直接刷新 Vue/React 路径时绝不报错；
2. **动静分流与智能缓存**：
   - JS/CSS/图片等静态文件开启 30 天强缓存 (`Cache-Control: max-age=2592000`)；
   - `index.html` 强制 `no-cache, must-revalidate`，确保前端发布后第一时间获取最新 JS 入口；
3. **低延迟 WebSocket 全双工长连接**：
   - 配置 `map $http_upgrade $connection_upgrade`，原生打通 `pm-ws`、`telemetry` 等实时长连接；
4. **反向代理后端长连接池**：
   - `upstream dci_backend` 配置 `keepalive 32;`，避免每次 HTTP 请求重新握手 TCP，API 响应延迟下降 40%；
5. **客户端大体积上传缓冲区优化**：
   - `client_max_body_size 50m;`，针对设备日志、升级包等大文件传输无阻断。

### 9.3 外部访问入口与运维命令
```bash
# 1. 验证 3 个 Master 节点上的 Nginx Pod 状态与宿主机挂载
kubectl get pods -n data-platform -l app=nginx -o wide

# 2. 检查 Nginx 访问与错误日志 (实时落盘在宿主机 /data/frontend/logs/)
kubectl logs -n data-platform -l app=nginx --tail=50 -f

# 3. 前端发布更新 (仅需将打包后的 dist 目录覆盖至宿主机，无需重启 Pod)
cp -r /path/to/your/dist/* /data/frontend/dist/

# 4. 后期扩容至 Worker 节点的弹性扩展命令:
kubectl scale deployment nginx-entry -n data-platform --replicas=5
# 观察新增的 Pod 自动调度到新增的 Worker 节点:
kubectl get pods -n data-platform -l app=nginx -o wide

# 5. 浏览器访问验证
# - 前端业务系统入口: http://192.168.1.100:30088
# - 健康检查接口:       http://192.168.1.100:30088/healthz (返回 healthy)
# - 管理与清理缓存:     http://192.168.1.100:30080/purge/
```


