# Temporary baseline harness: preload a fake openai module so
# infra._agent._models._language_models can be imported without
# the real dependency. This file is ONLY for running existing tests
# against the unmodified repo; it is not a production change.
import sys
import types

if "openai" not in sys.modules:
    fake_openai = types.ModuleType("openai")

    class _FakeOpenAI:
        def __init__(self, *args, **kwargs):
            pass

    fake_openai.OpenAI = _FakeOpenAI
    sys.modules["openai"] = fake_openai
