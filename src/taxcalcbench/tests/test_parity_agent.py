"""The parity agent builds the same request as upstream, for every case.

No API call is made. Run from src/taxcalcbench/ with the ``parity`` extra:
    TAXCALCBENCH_ROOT=/path/to/tax-calc-bench uv run --extra parity --with pytest pytest tests
"""

from __future__ import annotations

import json
import os
import shutil
from pathlib import Path

import pytest

ROOT = os.environ.get("TAXCALCBENCH_ROOT")
pytestmark = pytest.mark.skipif(not ROOT, reason="set TAXCALCBENCH_ROOT to an upstream checkout")

MODEL = "openai/gpt-6.2-sol"


@pytest.fixture(scope="module")
def tasks(tmp_path_factory):
    from taxcalcbench.adapter import TaxCalcBenchAdapter

    out = tmp_path_factory.mktemp("tasks")
    adapter = TaxCalcBenchAdapter(output_dir=out, benchmark_root=Path(ROOT))
    adapter.run()
    return adapter, out


@pytest.fixture(scope="module")
def upstream():
    from taxcalcbench.parity_agent import _load_upstream

    up = _load_upstream()
    from tax_calc_bench.config import TAX_YEAR
    from tax_calc_bench.ty24_prompt import TAX_RETURN_GENERATION_PROMPT

    up["TY24"] = (TAX_YEAR, TAX_RETURN_GENERATION_PROMPT)
    return up


@pytest.fixture(scope="module")
def agent(tmp_path_factory):
    from taxcalcbench.parity_agent import TaxCalcBenchDirectAgent

    return TaxCalcBenchDirectAgent(logs_dir=tmp_path_factory.mktemp("logs"), model_name=MODEL)


def test_request_matches_upstream(tasks, upstream, agent, monkeypatch):
    from taxcalcbench.parity_agent import upstream_prompt_from_instruction

    adapter, out = tasks
    gen = upstream["gen"]
    monkeypatch.chdir(ROOT)  # upstream builders read test data relative to cwd
    effort = upstream["openai_reasoning_effort"]("gpt-6.2-sol", "high")

    for case in adapter.discover():
        task_dir = out / case.task_id
        prompt = upstream_prompt_from_instruction((task_dir / "instruction.md").read_text())
        args = agent.build_request(prompt, task_dir / "environment" / "input")

        if case.tax_year == "ty25":
            expected_input = gen.build_ty25_response_input(case.source_id)
            assert args["input"] == expected_input, case.task_id
            assert args["stream"] is True and args["timeout"] == gen.TY25_LONG_RUN_TIMEOUT
        else:
            tax_year, template = upstream["TY24"]
            with open(case.case_dir / "input.json") as f:
                input_data = json.load(f)
            expected = template.format(tax_year=tax_year, tool_use_hint="", input_data=input_data)
            assert args["input"] == expected, case.task_id
            assert "stream" not in args and "timeout" not in args
        assert args["model"] == MODEL
        assert args["reasoning"] == {"effort": effort}


def test_prompt_needs_harbor_notes():
    from taxcalcbench.parity_agent import upstream_prompt_from_instruction

    with pytest.raises(ValueError):
        upstream_prompt_from_instruction("no notes here")
