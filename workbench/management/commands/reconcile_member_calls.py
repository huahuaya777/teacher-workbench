"""Inspect or reconcile abandoned member calls without contacting a provider."""

from datetime import timedelta

from django.core.management.base import BaseCommand, CommandError
from django.db.models import Q
from django.utils import timezone

from workbench.call_gate import reclaim_stale_reservation, reconcile_stale_post_send_task
from workbench.models import CallAttempt, GenerationTask


class Command(BaseCommand):
    help = "Preview stale member calls; --apply releases unsent slots and closes stranded sent tasks."

    def add_arguments(self, parser):
        parser.add_argument("--apply", action="store_true", help="Apply the reviewed reconciliation.")
        parser.add_argument("--min-age-minutes", type=int, default=60,
                            help="Minimum age before reconciliation (at least 10 minutes).")

    def handle(self, *args, **options):
        age_minutes = options["min_age_minutes"]
        if age_minutes < 10:
            raise CommandError("最短等待时间为 10 分钟；没有修改任务。")
        now = timezone.now()
        minimum_age = timedelta(minutes=age_minutes)
        cutoff = now - minimum_age
        unsent_ids = list(CallAttempt.objects.filter(
            status=CallAttempt.Status.RESERVED, reserved_at__lte=cutoff,
        ).order_by("pk").values_list("task_id", flat=True))
        sent_ids = list(CallAttempt.objects.filter(
            task__status=GenerationTask.Status.RUNNING,
            status__in=(CallAttempt.Status.SENT, CallAttempt.Status.COMPLETED, CallAttempt.Status.UNKNOWN),
        ).filter(
            Q(status=CallAttempt.Status.SENT, sent_at__lte=cutoff) |
            Q(status__in=(CallAttempt.Status.COMPLETED, CallAttempt.Status.UNKNOWN), finished_at__lte=cutoff)
        ).order_by("pk").values_list("task_id", flat=True))
        if not options["apply"]:
            self.stdout.write(f"MEMBER_CALL_RECONCILE_PREVIEW unsent={len(unsent_ids)} sent={len(sent_ids)} "
                              f"min_age_minutes={age_minutes}")
            return
        released = sum(reclaim_stale_reservation(task_id, at=now, min_age=minimum_age)
                       for task_id in unsent_ids)
        closed = sum(reconcile_stale_post_send_task(task_id, at=now, min_age=minimum_age)
                     for task_id in sent_ids)
        self.stdout.write(f"MEMBER_CALL_RECONCILE_APPLIED released_unsent={released} "
                          f"closed_sent={closed} skipped={len(unsent_ids) + len(sent_ids) - released - closed}")
