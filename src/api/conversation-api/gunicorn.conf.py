import multiprocessing
import os

max_requests = 1000
max_requests_jitter = 50

log_file = "-"

bind = "0.0.0.0:9000"
forwarded_allow_ips = "*"

if not os.getenv("RUNNING_IN_PRODUCTION"):
    reload = True

num_cpus = multiprocessing.cpu_count()
workers = (num_cpus * 2) + 1
worker_class = "uvicorn.workers.UvicornWorker"
timeout = 120