"""Tests for reasoning_library.embedder.

Required: ≥ 5 test cases (cosine_similarity is pure function, tested here)
"""

import sys
from pathlib import Path

import pytest

REASONING_LIB = Path(__file__).parent.parent
if str(REASONING_LIB) not in sys.path:
    sys.path.insert(0, str(REASONING_LIB))

from reasoning_library.embedder import cosine_similarity, EMBED_DIM


# ── cosine_similarity tests ───────────────────────────────────────────

class TestCosineSimilarity:
    """Tests for cosine_similarity."""

    def test_identical_vectors(self, identical_vectors_fixture):
        """cosine_similarity(identical, identical) → 1.0."""
        a, b = identical_vectors_fixture
        sim = cosine_similarity(a, b)
        assert abs(sim - 1.0) < 1e-10, f"Expected 1.0, got {sim}"

    def test_opposite_vectors(self, opposite_vectors_fixture):
        """cosine_similarity(opposite, opposite) → -1.0."""
        a, b = opposite_vectors_fixture
        sim = cosine_similarity(a, b)
        assert abs(sim - (-1.0)) < 1e-10, f"Expected -1.0, got {sim}"

    def test_zero_vector(self, zero_vector_fixture, non_zero_vector_fixture):
        """cosine_similarity(zero, anything) → 0.0."""
        zero = zero_vector_fixture
        non_zero = non_zero_vector_fixture
        sim = cosine_similarity(zero, non_zero)
        assert sim == 0.0

    def test_both_zero_vectors(self, zero_vector_fixture):
        """cosine_similarity(zero, zero) → 0.0."""
        zero = zero_vector_fixture
        sim = cosine_similarity(zero, zero)
        assert sim == 0.0

    def test_orthogonal_vectors(self):
        """Orthogonal vectors → 0.0."""
        a = [1.0, 0.0, 0.0]
        b = [0.0, 1.0, 0.0]
        sim = cosine_similarity(a, b)
        assert sim == 0.0

    def test_partial_similarity(self):
        """Partially similar vectors → value between 0 and 1."""
        a = [1.0, 0.0, 0.0]
        b = [1.0, 1.0, 0.0]
        sim = cosine_similarity(a, b)
        # Cosine of 45 degrees = 1/sqrt(2) ≈ 0.707
        import math
        expected = 1.0 / math.sqrt(2)
        assert abs(sim - expected) < 1e-10

    def test_returns_float(self):
        """Result is always a float."""
        sim = cosine_similarity([1.0, 0.0], [1.0, 0.0])
        assert isinstance(sim, float)
        assert -1.0 <= sim <= 1.0

    def test_high_dim_vectors(self):
        """Works with 1024-dim vectors (embedder dimension)."""
        import random
        random.seed(42)
        a = [random.gauss(0, 1) for _ in range(EMBED_DIM)]
        b = [random.gauss(0, 1) for _ in range(EMBED_DIM)]
        sim = cosine_similarity(a, b)
        assert isinstance(sim, float)
        assert -1.0 <= sim <= 1.0
