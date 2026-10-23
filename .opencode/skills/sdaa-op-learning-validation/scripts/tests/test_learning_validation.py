from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parents[1]
OPS_DIR = SCRIPT_DIR.parents[1]
sys.path.insert(0, str(SCRIPT_DIR))
sys.path.insert(0, str(SCRIPT_DIR / "hooks"))
sys.path.insert(0, str(OPS_DIR / "sdaa-op-template" / "scripts" / "hooks"))

import backend_profiles  # noqa: E402
import init_learning_task  # noqa: E402
import learned_patterns_guard  # noqa: E402
import new_op_preflight  # noqa: E402
import promote_stage_result  # noqa: E402
import snapshot_pattern_evidence  # noqa: E402
import validate_learned_patterns  # noqa: E402
import validate_stage_result  # noqa: E402


class LearningValidationTests(unittest.TestCase):
    def valid_stage(self) -> dict:
        return {
            "schema_version": 1,
            "backend": "teco-ops",
            "topic": "pipeline/test",
            "stage": "v1",
            "target_op": "test_op",
            "attempt_type": "isolated",
            "hypothesis": "one isolated change improves the target path",
            "status": "pass",
            "allowed_changes": ["target path"],
            "forbidden_changes": ["unrelated path"],
            "verified_shapes": ["M=128,N=32,K=128"],
            "correctness": {"python_api": "pass", "optest": "pass"},
            "delivery": {"test_commands": "pass"},
            "perf_before": {"time_ms": 2.0},
            "perf_after": {"time_ms": 1.0},
            "failures": [],
            "learned_rules": ["keep the isolated change"],
            "result_classification": "positive_alone",
        }

    def test_arbitrary_shape_keys(self) -> None:
        shape = init_learning_task.parse_shape(
            "q_seq=8192,q_head=16,kv_seq=8192,topk=512"
        )
        self.assertEqual(shape["q_seq"], 8192)
        self.assertEqual(shape["topk"], 512)

    def test_arbitrary_shape_defaults_to_target(self) -> None:
        target = {"q_seq": 8192, "q_head": 16, "topk": 512}
        self.assertEqual(
            init_learning_task.default_stage_shape("generic", target, "smoke"),
            target,
        )

    def test_shape_rejects_duplicate_or_nonpositive_dimensions(self) -> None:
        with self.assertRaises(ValueError):
            init_learning_task.parse_shape("M=128,m=64,K=32")
        with self.assertRaises(ValueError):
            init_learning_task.parse_shape("q_seq=0,q_head=16")
        with self.assertRaises(ValueError):
            init_learning_task.parse_shape("128,0,32")

    def test_init_learning_task_cli_dry_run(self) -> None:
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT_DIR / "init_learning_task.py"),
                "--mode",
                "optimize_existing",
                "--topic",
                "simd/test",
                "--profile",
                "generic",
                "--dtype",
                "fp32",
                "--target-shape",
                "q_seq=8192,q_head=16,topk=512",
                "--target-op",
                "test_op",
                "--dry-run",
            ],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("工作模式：`optimize_existing`", result.stdout)
        self.assertIn("q_seq=8192", result.stdout)

    def test_machine_absolute_path_is_detected(self) -> None:
        self.assertIsNotNone(
            validate_learned_patterns.MACHINE_ABSOLUTE_PATH_RE.search(
                "/data/user/repo/op_learning/stage.json"
            )
        )

    def test_portable_evidence_reference(self) -> None:
        refs = validate_learned_patterns.referenced_evidence_ids(
            "- evidence: dma-v1-pair-stride-gather\n"
            "- evidence: dma-v1-pair-stride-gather\n"
        )
        self.assertEqual(refs, ["dma-v1-pair-stride-gather"])

    def test_domain_route_config_is_valid(self) -> None:
        self.assertEqual(validate_learned_patterns.validate_domain_routes(), [])
        routes = new_op_preflight.load_domain_routes()
        self.assertIn("gemm", routes)
        self.assertIn("attention", routes)
        self.assertIn("sparse_attention", routes)

    def test_performance_direction(self) -> None:
        self.assertTrue(
            validate_learned_patterns.evidence_performance_improved(
                {
                    "performance": {
                        "before": 2.0,
                        "after": 1.0,
                        "direction": "lower_is_better",
                    }
                }
            )
        )

    def test_normalized_stage_result_passes(self) -> None:
        self.assertEqual(validate_stage_result.validate(self.valid_stage()), [])

    def test_stage_schema_required_fields_match_validator(self) -> None:
        schema_path = (
            SCRIPT_DIR.parent
            / "references"
            / "schemas"
            / "stage-result.schema.json"
        )
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        self.assertEqual(set(schema["required"]), validate_stage_result.REQUIRED_FIELDS)

    def test_positive_stage_requires_performance_improvement(self) -> None:
        payload = self.valid_stage()
        payload["perf_after"] = {"time_ms": 3.0}
        errors = validate_stage_result.validate(payload)
        self.assertTrue(any("performance improvement" in error for error in errors))

    def test_combination_requires_attribution_fields(self) -> None:
        payload = self.valid_stage()
        payload["attempt_type"] = "combination"
        payload["result_classification"] = "positive_in_bundle"
        errors = validate_stage_result.validate(payload)
        self.assertTrue(any("combination missing fields" in error for error in errors))

    def test_source_stage_must_match_backend_and_stage(self) -> None:
        payload = self.valid_stage()
        self.assertIsNone(
            snapshot_pattern_evidence.validate_source_stage(
                "backend://teco-ops/op_learning/pipeline/test/stage_results/v1.json",
                payload,
            )
        )

    def test_evidence_id_is_immutable_without_force(self) -> None:
        registry = {"schema_version": 1, "evidence": {"test-id": {"value": 1}}}
        with self.assertRaises(ValueError):
            snapshot_pattern_evidence.merge_evidence(
                registry,
                "test-id",
                {"value": 2},
                force=False,
            )

    def test_snapshot_cli_dry_run(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            stage_path = Path(root) / "v1.json"
            stage_path.write_text(
                json.dumps(self.valid_stage(), ensure_ascii=False),
                encoding="utf-8",
            )
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT_DIR / "snapshot_pattern_evidence.py"),
                    "--stage-result",
                    str(stage_path),
                    "--evidence-id",
                    "test-cli-evidence",
                    "--source-stage",
                    "backend://teco-ops/op_learning/pipeline/test/stage_results/v1.json",
                    "--dry-run",
                ],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("test-cli-evidence", result.stdout)

    def test_success_pattern_rejects_failed_evidence(self) -> None:
        errors = validate_learned_patterns.validate_evidence_item(
            "test-id",
            {
                "status": "fail",
                "correctness_passed": True,
                "delivery_passed": True,
                "source_stage": "backend://teco-ops/op_learning/x/stage_results/v1.json",
                "performance": {
                    "before": 2.0,
                    "after": 1.0,
                    "direction": "lower_is_better",
                },
            },
            require_performance=True,
        )
        self.assertTrue(any("not a passing stage" in error for error in errors))

    def test_stop_hook_outputs_codex_json_shape(self) -> None:
        blocked = learned_patterns_guard.build_stop_output(
            validation_error="invalid evidence",
            kernel_warnings=[],
            stop_hook_active=False,
        )
        self.assertEqual(blocked["decision"], "block")
        self.assertIn("invalid evidence", blocked["reason"])

        second_stop = learned_patterns_guard.build_stop_output(
            validation_error="invalid evidence",
            kernel_warnings=[],
            stop_hook_active=True,
        )
        self.assertNotIn("decision", second_stop)
        self.assertTrue(second_stop["continue"])

        warning = learned_patterns_guard.build_stop_output(
            validation_error="",
            kernel_warnings=["kernel warning"],
            stop_hook_active=False,
        )
        self.assertEqual(warning["systemMessage"], "kernel warning")

    def test_stop_hook_cli_stdout_is_single_json_object(self) -> None:
        result = subprocess.run(
            [sys.executable, str(SCRIPT_DIR / "hooks" / "learned_patterns_guard.py")],
            input=json.dumps({"stop_hook_active": False}),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertIsInstance(payload, dict)

    def test_user_prompt_hook_outputs_codex_json_shape(self) -> None:
        payload = new_op_preflight.build_user_prompt_output("read the patterns")
        hook_output = payload["hookSpecificOutput"]
        self.assertEqual(hook_output["hookEventName"], "UserPromptSubmit")
        self.assertEqual(hook_output["additionalContext"], "read the patterns")

        result = subprocess.run(
            [sys.executable, str(OPS_DIR / "sdaa-op-template" / "scripts" / "hooks" / "new_op_preflight.py")],
            input=json.dumps({"prompt": "普通问题"}, ensure_ascii=False),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {})

    def test_attention_preflight_routes_to_valid_row_pattern(self) -> None:
        prompt = "优化 attention kernel 的 QK score transpose"
        self.assertTrue(new_op_preflight.looks_like_kernel_work(prompt))
        self.assertEqual(new_op_preflight.matched_domain_names(prompt), ["attention"])
        indexes = "\n".join(new_op_preflight.domain_index_summaries(prompt))
        patterns = "\n".join(new_op_preflight.search_patterns(prompt))
        self.assertIn("attention/README.md", indexes)
        self.assertIn("simd/valid-row-bounded-transpose.md", patterns)

    def test_configured_gemm_domain_and_action_trigger_preflight(self) -> None:
        prompt = "继续优化 gemm"
        self.assertTrue(new_op_preflight.looks_like_kernel_work(prompt))
        self.assertEqual(new_op_preflight.matched_domain_names(prompt), ["gemm"])
        indexes = "\n".join(new_op_preflight.domain_index_summaries(prompt))
        patterns = "\n".join(new_op_preflight.search_patterns(prompt))
        self.assertIn("gemm/README.md", indexes)
        self.assertIn("gemm/2d-splitk-c-rma-reduce.md", patterns)
        self.assertIn("pipeline/ab-dma-double-buffer-ace-gemm.md", patterns)

        self.assertFalse(new_op_preflight.looks_like_kernel_work("测试 matmul"))
        self.assertFalse(new_op_preflight.looks_like_kernel_work("benchmark gemm"))
        self.assertFalse(new_op_preflight.looks_like_kernel_work("性能测试 matmul"))
        self.assertTrue(new_op_preflight.looks_like_kernel_work("写一个 gemm 算子"))
        self.assertTrue(new_op_preflight.looks_like_kernel_work("implement gemm"))
        self.assertFalse(new_op_preflight.looks_like_kernel_work("解释 gemm 是什么"))
        self.assertFalse(new_op_preflight.looks_like_kernel_work("latest gemm notes"))
        self.assertEqual(new_op_preflight.extract_terms("测试 matmul"), {"matmul"})

    def test_sparse_attention_preflight_inherits_attention_route(self) -> None:
        prompt = "继续优化 flash_mla_sparse decode"
        self.assertTrue(new_op_preflight.looks_like_kernel_work(prompt))
        self.assertEqual(
            new_op_preflight.matched_domain_names(prompt),
            ["attention", "sparse_attention"],
        )
        indexes = "\n".join(new_op_preflight.domain_index_summaries(prompt))
        patterns = "\n".join(new_op_preflight.search_patterns(prompt))
        self.assertIn("attention/README.md", indexes)
        self.assertIn("sparse-attention/README.md", indexes)
        self.assertIn("simd/valid-row-bounded-transpose.md", patterns)
        self.assertIn("dma/pair-stride-gather.md", patterns)

    def test_sparse_attention_hook_cli_emits_domain_routes(self) -> None:
        result = subprocess.run(
            [
                sys.executable,
                str(
                    OPS_DIR
                    / "sdaa-op-template"
                    / "scripts"
                    / "hooks"
                    / "new_op_preflight.py"
                ),
            ],
            input=json.dumps(
                {"prompt": "继续优化 flash_mla_sparse decode"},
                ensure_ascii=False,
            ),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        report = payload["hookSpecificOutput"]["additionalContext"]
        self.assertIn("attention/README.md", report)
        self.assertIn("sparse-attention/README.md", report)
        self.assertIn("simd/valid-row-bounded-transpose.md", report)
        self.assertNotIn("gemm/a-reuse-across-n.md", report)

    def test_promote_design_facts_requires_normalized_target(self) -> None:
        payload = self.valid_stage()
        payload["evidence"] = ["backend://teco-ops/op_learning/pipeline/test/stage_results/v1.json"]
        payload["verified_facts"] = [
            {"path": "pipeline_layout.tested", "value": True, "evidence": "v1.json"}
        ]
        promote_stage_result.validate_promotable_stage_result(
            payload,
            op="test_op",
            topic="pipeline/test",
            stage="v1",
            backend="teco-ops",
        )
        payload["target_op"] = "other_op"
        with self.assertRaises(SystemExit):
            promote_stage_result.validate_promotable_stage_result(
                payload,
                op="test_op",
                topic="pipeline/test",
                stage="v1",
                backend="teco-ops",
            )

    def test_promote_design_facts_cli_dry_run(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            root_path = Path(root)
            stage = self.valid_stage()
            stage["evidence"] = [
                "backend://teco-ops/op_learning/pipeline/test/stage_results/v1.json"
            ]
            stage["verified_facts"] = [
                {"path": "pipeline_layout.tested", "value": True, "evidence": "v1.json"}
            ]
            stage_path = root_path / "v1.json"
            design_path = root_path / "design.json"
            stage_path.write_text(json.dumps(stage), encoding="utf-8")
            design_path.write_text(json.dumps({"op": "test_op"}), encoding="utf-8")
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT_DIR / "promote_design_facts.py"),
                    "--op",
                    "test_op",
                    "--topic",
                    "pipeline/test",
                    "--stage-result",
                    str(stage_path),
                    "--design",
                    str(design_path),
                    "--demo-root",
                    root,
                    "--dry-run",
                    "--no-md",
                    "--no-learned",
                    "--json",
                ],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('"applied_updates"', result.stdout)

if __name__ == "__main__":
    unittest.main()
