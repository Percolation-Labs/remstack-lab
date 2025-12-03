"""
Patched Phoenix evaluator function that uses structured output instead of llm_classify.

This is based on the carrier implementation pattern and fixes the issue where
all evaluations return 0 scores because llm_classify ignores schema properties.

To use, copy the helper functions and replace create_evaluator_from_schema in:
  .venv/lib/python3.12/site-packages/rem/agentic/providers/phoenix.py
"""

from typing import Any, Callable
from pathlib import Path
import json
import yaml
import re

from loguru import logger


# =============================================================================
# HELPER FUNCTIONS FOR PHOENIX CONFIG PROCESSING
# =============================================================================


def _evaluate_expression(expression: str, context: dict[str, Any]) -> Any:
    """Safely evaluate a simple expression with context variables.

    Supports: arithmetic, comparisons, boolean logic, len()
    """
    try:
        # Simple safe eval with context
        # Only allow specific operations for safety
        allowed_names = {
            "len": len,
            "True": True,
            "False": False,
            "true": True,
            "false": False,
        }
        # Add context variables
        allowed_names.update(context)

        return eval(expression, {"__builtins__": {}}, allowed_names)
    except Exception as e:
        logger.warning(f"Expression evaluation failed: {expression} - {e}")
        return 0.0


def _calculate_derived_scores(
    response_json: dict[str, Any],
    derived_scores_config: dict[str, Any],
) -> dict[str, Any]:
    """Calculate derived scores from evaluator output using config formulas.

    Supports:
    - weighted_sum: Weighted average of fields
    - conditional_weighted: Different formulas based on conditions
    - boolean_logic: Boolean expression evaluation
    """
    for score_name, score_config in derived_scores_config.items():
        score_type = score_config.get("type")

        if score_type == "weighted_sum":
            weights = score_config.get("weights", {})
            total = 0.0
            for field, weight in weights.items():
                field_value = response_json.get(field, 0.0)
                if isinstance(field_value, (int, float)):
                    total += field_value * weight
            response_json[score_name] = total

        elif score_type == "conditional_weighted":
            conditions = score_config.get("conditions", [])
            formula_to_use = None

            for cond_config in conditions:
                condition = cond_config.get("condition")

                if condition is None:
                    formula_to_use = cond_config.get("formula")
                    break

                field = condition.get("field")
                operator = condition.get("operator")
                value = condition.get("value")
                field_value = response_json.get(field, 0.0)

                condition_met = False
                if operator == ">=":
                    condition_met = field_value >= value
                elif operator == ">":
                    condition_met = field_value > value
                elif operator == "<=":
                    condition_met = field_value <= value
                elif operator == "<":
                    condition_met = field_value < value
                elif operator == "==":
                    condition_met = field_value == value
                elif operator == "!=":
                    condition_met = field_value != value

                if condition_met:
                    formula_to_use = cond_config.get("formula")
                    break

            if formula_to_use and formula_to_use.get("type") == "weighted_sum":
                weights = formula_to_use.get("weights", {})
                total = 0.0
                for field, weight in weights.items():
                    field_value = response_json.get(field, 0.0)
                    if isinstance(field_value, (int, float)):
                        total += field_value * weight
                response_json[score_name] = total

        elif score_type == "boolean_logic":
            expression = score_config.get("expression", "")
            result = _evaluate_expression(expression, response_json)
            response_json[score_name] = result

    return response_json


def _create_phoenix_evaluations(
    response_json: dict[str, Any],
    evaluations_config: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Create Phoenix evaluation dicts from evaluator output using config.

    Each evaluation becomes a column in Phoenix UI with name, label, score, explanation.
    """
    evaluations = []

    for eval_config in evaluations_config:
        eval_name = eval_config.get("name", "unnamed")
        score_field = eval_config.get("score_field")
        score_expression = eval_config.get("score_expression")
        label_field = eval_config.get("label_field")
        label_expression = eval_config.get("label_expression")
        label_logic = eval_config.get("label_logic", [])
        label_transform = eval_config.get("label_transform", {})
        score_logic = eval_config.get("score_logic", {})
        explanation_field = eval_config.get("explanation_field")

        evaluation = {"name": eval_name}

        # Get score
        if score_expression:
            evaluation["score"] = _evaluate_expression(score_expression, response_json)
        elif score_field:
            evaluation["score"] = response_json.get(score_field, 0.0)
        elif score_logic:
            if label_field:
                label_value = response_json.get(label_field)
                if isinstance(label_value, bool):
                    label_value = "true" if label_value else "false"
                evaluation["score"] = score_logic.get(str(label_value), 0.0)
            else:
                evaluation["score"] = 0.0
        else:
            evaluation["score"] = None

        # Get label
        if label_expression:
            evaluation["label"] = str(_evaluate_expression(label_expression, response_json))
        elif label_field:
            label_value = response_json.get(label_field)
            if isinstance(label_value, bool):
                label_value = "true" if label_value else "false"
            if label_transform:
                evaluation["label"] = label_transform.get(str(label_value), str(label_value))
            else:
                evaluation["label"] = str(label_value)
        elif label_logic and (score_field or score_expression):
            score_value = evaluation.get("score", 0.0)
            label = "unknown"
            for logic in label_logic:
                threshold = logic.get("threshold", 0.0)
                operator = logic.get("operator", ">=")
                logic_label = logic.get("label", "unknown")

                condition_met = False
                if operator == ">=":
                    condition_met = score_value >= threshold
                elif operator == ">":
                    condition_met = score_value > threshold
                elif operator == "<=":
                    condition_met = score_value <= threshold
                elif operator == "<":
                    condition_met = score_value < threshold
                elif operator == "==":
                    condition_met = score_value == threshold

                if condition_met:
                    label = logic_label
                    break

            evaluation["label"] = label
        else:
            evaluation["label"] = None

        # Get explanation
        if explanation_field:
            explanation_value = response_json.get(explanation_field, "")
            if isinstance(explanation_value, list):
                evaluation["explanation"] = ", ".join(str(x) for x in explanation_value) if explanation_value else "None"
            else:
                evaluation["explanation"] = str(explanation_value)
        else:
            evaluation["explanation"] = None

        evaluations.append(evaluation)

    return evaluations


# =============================================================================
# PATCHED EVALUATOR FUNCTION
# =============================================================================


def create_evaluator_from_schema_patched(
    evaluator_schema_path: str | Path | dict[str, Any],
    model_name: str | None = None,
) -> Callable[[Any], Any]:
    """Create an evaluator function from a schema file or dict.

    PATCHED VERSION: Uses direct LLM call with JSON schema instead of llm_classify.
    This properly extracts all schema properties as evaluation scores.
    """
    from phoenix.evals import OpenAIModel, AnthropicModel

    # Load schema if path/name provided
    if isinstance(evaluator_schema_path, (str, Path)):
        schema_path = Path(evaluator_schema_path)
        if schema_path.exists():
            logger.debug(f"Loading evaluator schema from {schema_path}")
            if schema_path.suffix in [".yaml", ".yml"]:
                with open(schema_path) as f:
                    schema = yaml.safe_load(f)
            else:
                with open(schema_path) as f:
                    schema = json.load(f)
        else:
            # Try to load from schema loader
            from rem.utils.schema_loader import load_agent_schema
            schema = load_agent_schema(str(evaluator_schema_path))
    else:
        schema = evaluator_schema_path

    # Extract schema components
    evaluator_name = schema.get("title", "UnnamedEvaluator")
    system_prompt = schema.get("description", "")
    output_schema = schema.get("properties", {})
    required_fields = schema.get("required", [])

    # Extract phoenix_config for derived scores and evaluations
    phoenix_config = schema.get("phoenix_config", {})
    derived_scores_config = phoenix_config.get("derived_scores", {})
    evaluations_config = phoenix_config.get("evaluations", [])

    # Default model
    if model_name is None:
        model_name = "claude-sonnet-4-5-20250929"

    logger.info(f"Creating Phoenix evaluator: {evaluator_name} with model={model_name}")

    # Create LLM wrapper
    if ":" in model_name:
        provider, phoenix_model_name = model_name.split(":", 1)
    else:
        if model_name.startswith("claude"):
            provider = "anthropic"
        else:
            provider = "openai"
        phoenix_model_name = model_name

    if provider.lower() == "anthropic":
        llm = AnthropicModel(model=phoenix_model_name, temperature=0.0)
    else:
        llm = OpenAIModel(model=phoenix_model_name, temperature=0.0)

    # Store config for closure
    evaluator_config = {
        "name": evaluator_name,
        "llm": llm,
        "prompt_template": system_prompt,
        "schema": output_schema,
        "required": required_fields,
    }

    def evaluator_fn(input: dict[str, Any], output: dict[str, Any], expected: dict[str, Any]) -> list[dict[str, Any]]:
        """Evaluate using Phoenix's named parameter binding with structured LLM output.

        Args:
            input: Dataset input dict
            output: Task's return value (agent output)
            expected: Expected output dict (reference/ground truth)

        Returns:
            List of Phoenix evaluation dicts with name, score, label, explanation
        """
        logger.debug(f"Evaluating with structured output pattern")

        # Extract question from input
        if isinstance(input, dict):
            question = input.get("input", input.get("text", str(input)))
        else:
            question = str(input)

        # Serialize agent output
        if isinstance(output, dict):
            output_str = json.dumps(output, indent=2)
        else:
            output_str = str(output)

        # Get reference from expected
        if isinstance(expected, dict):
            reference = expected.get("reference", expected.get("expected_output",
                         expected.get("ground_truth", str(expected))))
        else:
            reference = str(expected)

        try:
            # Build user message
            user_message = f"""Question/Input: {question}

Agent's Answer:
{output_str}

Expected Answer (Reference):
{reference}

Please evaluate the agent's answer according to the evaluation criteria."""

            # Add JSON schema requirement to system prompt
            schema_instruction = f"\n\nYou MUST respond with valid JSON matching this schema:\n{json.dumps(output_schema, indent=2)}\n\nProvide ONLY the JSON response, no markdown code blocks or extra text."
            system_with_schema = system_prompt + schema_instruction

            # Phoenix LLM models expect a single prompt string
            full_prompt = f"{system_with_schema}\n\n{user_message}"
            response_text = llm(full_prompt)

            # Parse JSON response
            try:
                response_json = json.loads(response_text)
            except json.JSONDecodeError:
                # Try to extract JSON from markdown code blocks
                json_match = re.search(r'```(?:json)?\s*(\{.*?\})\s*```', response_text, re.DOTALL)
                if json_match:
                    response_json = json.loads(json_match.group(1))
                else:
                    raise ValueError(f"Could not parse JSON from LLM response: {response_text[:200]}")

            logger.debug(f"LLM response parsed: {list(response_json.keys())}")

            # Calculate derived scores
            if derived_scores_config:
                logger.debug(f"Calculating {len(derived_scores_config)} derived scores")
                response_json = _calculate_derived_scores(response_json, derived_scores_config)

            # Create Phoenix evaluations
            if evaluations_config:
                logger.debug(f"Creating {len(evaluations_config)} Phoenix evaluations")
                evaluations = _create_phoenix_evaluations(response_json, evaluations_config)
            else:
                # Fallback: create evaluations from all numeric/boolean fields
                logger.warning("No evaluations_config - creating default evaluations from schema")
                evaluations = []
                for field_name, field_value in response_json.items():
                    if isinstance(field_value, (int, float)):
                        evaluations.append({
                            "name": field_name,
                            "score": float(field_value),
                            "label": "good" if field_value >= 0.5 else "poor",
                            "explanation": None
                        })
                    elif isinstance(field_value, bool):
                        evaluations.append({
                            "name": field_name,
                            "score": 1.0 if field_value else 0.0,
                            "label": "pass" if field_value else "fail",
                            "explanation": None
                        })

                # Always add overall if not present
                if not any(e["name"] == "overall" for e in evaluations):
                    overall_score = response_json.get("overall_score", 0.0)
                    overall_pass = response_json.get("pass", False)
                    evaluations.append({
                        "name": "overall",
                        "score": overall_score if isinstance(overall_score, (int, float)) else 0.0,
                        "label": "pass" if overall_pass else "fail",
                        "explanation": response_json.get("evaluation_notes", None)
                    })

            logger.debug(f"Returning {len(evaluations)} evaluations")
            return evaluations

        except Exception as e:
            logger.error(f"Evaluator error: {e}")
            return [{
                "name": "error",
                "label": "error",
                "score": 0.0,
                "explanation": f"Evaluator failed: {str(e)}",
            }]

    return evaluator_fn


# =============================================================================
# TEST
# =============================================================================

if __name__ == "__main__":
    # Test the patched evaluator
    print("Testing patched evaluator...")

    # Example schema
    test_schema = {
        "title": "TestEvaluator",
        "description": "Test evaluator for QA tasks.",
        "properties": {
            "factual_accuracy_score": {"type": "number", "minimum": 0, "maximum": 1},
            "completeness_score": {"type": "number", "minimum": 0, "maximum": 1},
            "overall_score": {"type": "number", "minimum": 0, "maximum": 1},
            "pass": {"type": "boolean"},
        },
        "required": ["factual_accuracy_score", "completeness_score", "overall_score", "pass"],
        "phoenix_config": {
            "evaluations": [
                {"name": "factual_accuracy", "score_field": "factual_accuracy_score"},
                {"name": "completeness", "score_field": "completeness_score"},
                {"name": "overall", "score_field": "overall_score"},
                {"name": "pass_fail", "label_field": "pass", "score_logic": {"true": 1.0, "false": 0.0}},
            ]
        }
    }

    print("Schema loaded successfully")
    print(f"Evaluations config: {test_schema['phoenix_config']['evaluations']}")
