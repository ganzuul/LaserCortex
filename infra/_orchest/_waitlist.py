import logging
from dataclasses import dataclass, field
from typing import List, Optional
from infra._orchest._repo import InferenceEntry
from infra._cortex._types import RouterIndex, flow_to_index

@dataclass
class WaitlistItem:
    """Represents an inference waiting to be processed."""
    inference_entry: InferenceEntry
    router_index: Optional[RouterIndex] = field(default=None, repr=False)

    def __hash__(self):
        return hash(self.inference_entry.id)

    def __eq__(self, other):
        return isinstance(other, WaitlistItem) and self.inference_entry.id == other.inference_entry.id

@dataclass
class Waitlist:
    """Represents the entire collection of items to be orchestrated."""
    id: str
    items: List[WaitlistItem]
    status: str = "pending"
    
    def sort_by_flow_index(self):
        """Sorts items according to the dot system (flow_index)."""
        def sort_key(item):
            flow_index = item.inference_entry.flow_info['flow_index']
            # Convert dot notation to tuple of integers for proper sorting
            # e.g., '1.2' -> (1, 2), '1.3' -> (1, 3), '1' -> (1,)
            return tuple(int(part) for part in flow_index.split('.'))
        
        self.items.sort(key=sort_key)
        logging.info(f"Waitlist items sorted by flow_index: {[item.inference_entry.flow_info['flow_index'] for item in self.items]}")

    def assign_router_indices(self) -> None:
        """Assign a bounded RouterIndex to each item based on sorted position.

        The bound is ``len(items)`` so every item gets a unique address
        in ``[0, bound)`` — the minimum space needed for injectivity.
        """
        bound = len(self.items)
        for i, item in enumerate(self.items):
            item.router_index = RouterIndex(i, bound)
        logging.info(
            f"Assigned RouterIndices [0, {bound}) to {len(self.items)} items."
        )

    def get_supporting_items(self, target_item: WaitlistItem) -> List[WaitlistItem]:
        """
        Retrieves a list of items that are supporting a specific item.
        An item is considered a "supporter" if its flow_index is a descendant
        of the target item's flow_index (e.g., '1.1' supports '1').
        """
        target_flow_index = target_item.inference_entry.flow_info['flow_index']
        return [
            item for item in self.items
            if item != target_item and item.inference_entry.flow_info['flow_index'].startswith(target_flow_index + '.')
        ]

    def get_dependent_items(self, parent_item: WaitlistItem) -> List[WaitlistItem]:
        """
        Retrieves a list of items that depend on the concept inferred by the parent item.
        An item is a "dependent" if the parent's inferred concept is in its
        value_concepts or is its function_concept.
        """
        parent_inferred_concept_name = parent_item.inference_entry.concept_to_infer.concept_name
        dependents = []

        for item in self.items:
            if item == parent_item:
                continue

            # Check value concepts
            value_concept_names = {vc.concept_name for vc in item.inference_entry.value_concepts}
            if parent_inferred_concept_name in value_concept_names:
                dependents.append(item)
                continue  # Move to next item once dependency is found

            # Check function concept
            if item.inference_entry.function_concept:
                if item.inference_entry.function_concept.concept_name == parent_inferred_concept_name:
                    dependents.append(item)

        return dependents