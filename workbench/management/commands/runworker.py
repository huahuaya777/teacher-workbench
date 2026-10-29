from django.conf import settings
from django.core.management.base import BaseCommand
from redis import Redis
from rq import Queue, Worker


class Command(BaseCommand):
    help = "Run the private generation queue worker"

    def handle(self, *args, **options):
        connection = Redis.from_url(settings.REDIS_URL)
        worker = Worker([Queue("generation", connection=connection)], connection=connection)
        worker.work()
