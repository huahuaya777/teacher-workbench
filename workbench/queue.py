from django.conf import settings
from redis import Redis
from rq import Queue
from .models import GenerationTask


def enqueue_task(task_id):
    member_mode = GenerationTask.objects.only("member_mode").get(pk=task_id).member_mode
    if member_mode and not settings.AI_MEMBER_TASKS_ENABLED:
        raise ValueError("成员模型调用未启用。")
    if settings.AI_STAGING_MANUAL_QUEUE:
        # Staging PostgreSQL persists the task, but no worker or paid provider
        # runs until an operator explicitly starts one reviewed task.
        return
    if settings.AI_LOCAL_QUEUE and settings.DATABASES["default"]["ENGINE"] == "django.db.backends.sqlite3":
        # Local-only validation: the task stays in SQLite until an operator
        # explicitly processes that single task. No Redis or model call here.
        return
    connection = Redis.from_url(settings.REDIS_URL)
    queue = Queue("generation", connection=connection)
    target = ("workbench.tasks.process_member_generation_task" if member_mode else
              "workbench.tasks.process_generation_task")
    queue.enqueue(target, task_id, job_id=f"generation-{task_id}", job_timeout=180)
