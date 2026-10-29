"""Small shared-cache throttle for the stage-1 password login.

The existing HTTPS tunnel has not been verified to expose reliable client IPs,
so counters are per normalized username. Keys contain only a keyed digest.
"""

from django.contrib.auth.views import LoginView
from django.core.cache import cache
from django.utils.crypto import salted_hmac


MAX_FAILURES = 8
WINDOW_SECONDS = 15 * 60


def _counter_key(username: str) -> str:
    normalized = username.strip().casefold()
    digest = salted_hmac("workbench.login-throttle", normalized).hexdigest()
    return f"login-failures:{digest}"


class ThrottledLoginView(LoginView):
    def dispatch(self, request, *args, **kwargs):
        if request.method == "POST":
            self._failure_key = _counter_key(request.POST.get("username", ""))
            if (cache.get(self._failure_key) or 0) >= MAX_FAILURES:
                form = self.get_form()
                form.add_error(None, "尝试次数较多，请 15 分钟后再试。")
                context = self.get_context_data(form=form, login_rate_limited=True)
                return self.render_to_response(context, status=429)
        return super().dispatch(request, *args, **kwargs)

    def form_invalid(self, form):
        key = self._failure_key
        if not cache.add(key, 1, WINDOW_SECONDS):
            try:
                cache.incr(key)
            except ValueError:
                # The first key can expire between add() and incr().
                cache.add(key, 1, WINDOW_SECONDS)
        return super().form_invalid(form)

    def form_valid(self, form):
        cache.delete(self._failure_key)
        return super().form_valid(form)
