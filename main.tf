terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  cloud_id = var.cloud_id
  folder_id = var.folder_id
  service_account_key_file = "/Users/d.gorlov/yc-keys/key.json"
}

resource "yandex_storage_bucket" "bucket" {
  bucket = "bot-setup"
}

resource "yandex_storage_object" "yagpt_setup" {
  bucket = yandex_storage_bucket.bucket.id
  key    = "prompt.txt"
  source = "prompt.txt"
}

resource "yandex_function" "func" {
  name        = "func-tg-bot"
  user_hash   = archive_file.zip.output_sha256
  runtime     = "python312"
  entrypoint  = "bot.handler"
  memory      = 128
  execution_timeout  = 60
  environment = {
    "tg_bot_key" = var.tg_bot_key,
    "yandex_api_key" = var.yandex_api_key,
    "object_key" = var.object_key,
    "folder_id" = var.folder_id,
    "bucket_name" = var.bucket_name,
    "aws_access_key_id" = var.aws_access_key_id,
    "aws_secret_access_key" = var.aws_secret_access_key,
    "region_name" = var.region_name,
    "IMAGES_BUCKET" = yandex_storage_bucket.bucket.bucket
  }
  service_account_id = "ajen8omclrnvrl3f4gl5"

  content {
    zip_filename = archive_file.zip.output_path
  }
}

resource "yandex_function_iam_binding" "function-iam" {
  function_id = yandex_function.func.id
  role        = "serverless.functions.invoker"

  members = [
    "system:allUsers",
  ]
}

variable "tg_bot_key" {
  type = string
}

variable "yandex_api_key" {
  type = string
}

variable "folder_id" {
  type = string
}

variable "cloud_id" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "object_key" {
  type = string
}

variable "aws_access_key_id" {
  type = string
}

variable "aws_secret_access_key" {
  type = string
}

variable "region_name" {
  type = string
}

output "func_url" {
  value = "https://functions.yandexcloud.net/${yandex_function.func.id}"
}

resource "archive_file" "zip" {
  type = "zip"
  output_path = "func.zip"
  source_dir = "/Users/d.gorlov/PycharmProjects/cheatsheet_itis_2024_vvot00_bot_py/main"
}

resource "null_resource" "curl" {
  provisioner "local-exec" {
    command = "curl --insecure -X POST https://api.telegram.org/bot${var.tg_bot_key}/setWebhook?url=https://functions.yandexcloud.net/${yandex_function.func.id}"
  }

  triggers = {
    on_version_change = var.tg_bot_key
  }

  provisioner "local-exec" {
    when    = destroy
    command = "curl --insecure -X POST https://api.telegram.org/bot${self.triggers.on_version_change}/deleteWebhook"
  }
}
