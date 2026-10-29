"""Re-encrypt saved credentials after a new external key version is installed."""

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from workbench.credential_vault import (VaultIntegrityError, VaultUnavailable,
                                        reseal_with_active_key, vault_ready)
from workbench.models import ModelCredential


class Command(BaseCommand):
    help = "Re-encrypt member model keys with the configured active key version."

    def add_arguments(self, parser):
        parser.add_argument("--confirm", action="store_true", help="Confirm a reviewed backup and key rotation plan.")

    def handle(self, *args, **options):
        if not options["confirm"]:
            raise CommandError("未提供 --confirm；没有读取或修改模型配置。")
        if not vault_ready():
            raise CommandError("新的主密钥文件不可用；没有修改模型配置。")
        version = settings.MODEL_ACTIVE_KEY_VERSION
        changed = 0
        try:
            with transaction.atomic():
                credentials = list(ModelCredential.objects.select_for_update().order_by("pk"))
                if any(item.key_version > version for item in credentials):
                    raise CommandError("目标主密钥版本不能低于已有记录。")
                for credential in credentials:
                    if reseal_with_active_key(credential):
                        credential.save(update_fields=["key_ciphertext", "key_nonce", "key_version", "updated_at"])
                        changed += 1
        except (VaultUnavailable, VaultIntegrityError) as exc:
            raise CommandError("主密钥或密文验证失败；数据库事务已回滚。") from exc
        self.stdout.write(f"MODEL_CREDENTIAL_ROTATION_OK version={version} changed={changed}")
