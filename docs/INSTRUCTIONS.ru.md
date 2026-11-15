# Java-приложение в Яндекс Облаке: Jenkins + Terraform + Ansible

## Описание работы

```
Jenkins pipeline (локальный контейнер, встроенный агент)
  │ 1. terraform apply  → сеть, реестр, ВМ build и ВМ stage
  │ 2. ansible build.yml  → на build: docker build + push в реестр
  │ 3. ansible deploy.yml → на stage: docker pull + запуск контейнера
  └ 4. smoke test (curl)
```

* **Terraform** создаёт только инфраструктуру (сеть, security group, Container Registry, сервисные аккаунты, ВМ `demo-build` и `demo-stage`). cloud-init ставит на ВМ Docker.
* **Ansible** собирает образ на build-ВМ и разворачивает контейнер на stage-ВМ.
* **Jenkins** (`Jenkinsfile`) запускает всё по порядку. Нужные инструменты (`terraform`, `ansible`, `jq`, `ssh-keygen`, `tar`) уже есть в образе Jenkins.

## Структура

```
Dockerfile, pom.xml, src/   приложение
Jenkinsfile                 pipeline
jenkins/                    запуск Jenkins в Docker (Dockerfile, docker-compose.yml, jenkins.yaml, .env.example)
scripts/install-tools.sh    установка инструментов при сборке образа Jenkins
ansible/                    плейбуки build.yml, deploy.yml и роли
terraform/                  инфраструктура (модули vm и network)
```

## 1. Настройка

### 1.1. `terraform/terraform.tfvars`
```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

| Переменная | Что указать |
|---|---|
| `cloud_id` | ID облака |
| `folder_id` | ID каталога |
| `sa_key_file` | путь к ключу сервисного аккаунта (в Jenkins не используется, см. ниже) |
| `ssh_public_key_path` / `ssh_private_key_path` | пути к SSH-ключу (в Jenkins не используются, см. ниже) |
| `ssh_allowed_cidrs` | `["<ваш_внешний_IP>/32"]` (`curl -s ifconfig.me`): с этого адреса Ansible заходит на ВМ по SSH |
| `zone`, `name_prefix`, `app_port`, `build_vm`, `stage_vm` | по желанию (значения по умолчанию подходят) |

В Jenkins `sa_key_file` и `ssh_*_key_path` не используются: pipeline сам передаёт пути к смонтированным ключам (п. 1.2), поэтому ключи в `tfvars` могут называться как угодно (нужны только для запуска Terraform вручную).

### 1.2. `jenkins/.env`
```bash
cp jenkins/.env.example jenkins/.env
```

| Переменная | Что указать | Куда попадает в контейнере |
|---|---|---|
| `JENKINS_ADMIN_PASSWORD` | пароль пользователя `admin` | настройка Jenkins |
| `YC_SA_KEY_FILE` | абсолютный путь к `key.json` сервисного аккаунта | `/var/jenkins_home/.yc/key.json` |
| `SSH_KEY_FILE` | абсолютный путь к приватному SSH-ключу (рядом должен лежать `.pub`) | `/var/jenkins_home/.ssh/id_ed25519(.pub)` |

`terraform.tfvars` в `.env` не указывается: папка проекта целиком смонтирована в контейнер как `/project` (только для чтения), оттуда pipeline берёт `Jenkinsfile`, исходники и `terraform/terraform.tfvars`. Git не нужен. Ключи тоже монтируются только для чтения; в образ и в Jenkins credentials они не попадают.

## 2. Запуск Jenkins

1. Заполните `terraform/terraform.tfvars` (п. 1.1) и `jenkins/.env` (п. 1.2).
2. Запустите:
   ```bash
   cd jenkins
   docker compose up -d --build
   ```
3. Откройте http://localhost:8081, войдите как `admin` с паролем из `.env`.

Job **`yc-deploy`** уже создан автоматически. Образ Jenkins содержит нужные инструменты и зеркало провайдеров Terraform; pipeline выполняется на встроенном (дефолтном) агенте.

## 3. Запуск pipeline

Нажмите **Build Now** у job `yc-deploy`. Этапы:
1. **Prepare sources** — копирование папки проекта в workspace (состояние Terraform в workspace сохраняется между сборками).
2. **Terraform: init & validate**.
3. **Terraform: apply** — инфраструктура; outputs сохраняются в `tf-output.json`.
4. **Ansible: inventory** — inventory и переменные генерируются из outputs Terraform.
5. **Ansible: build image** — `build.yml`: сборка образа на build-ВМ и push в реестр (тег = номер сборки).
6. **Ansible: deploy to stage** — `deploy.yml`: запуск контейнера на stage-ВМ и проверка здоровья.
7. **Smoke test** — `curl` на адрес приложения.

Адрес приложения: `http://<публичный IP stage-ВМ>:8080/` (виден в логе и в `terraform output app_url`).

Обновление приложения: измените файлы в папке проекта и снова нажмите **Build Now**. Параметр `DESTROY` (появляется после первого запуска) вместо деплоя удаляет инфраструктуру; образы в реестре перед этим удалите вручную — реестр с образами не удаляется.

Первый запуск занимает ~8–10 минут.

> Состояние Terraform и workspace лежат в томе `jenkins_home` и переживают перезапуск контейнера. `docker compose down -v` их удаляет — тогда уже созданные ресурсы придётся удалять вручную.

