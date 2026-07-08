export interface SpecSummary {
  cortex_name: string;
  form_type: string;
  coupling_signature: string;
  logic_type: string;
  axes: string[];
  tensor_shape: number[];
  witness_type: string;
  example_count: number;
}

export interface SpecDetail {
  cortex_name: string;
  form_type: string;
  form_schema_version: string;
  coupling_signature: string;
  logic_type: string;
  axes: string[];
  tensor_shape: number[];
  validation: Record<string, unknown>;
  default_payload: Record<string, unknown>;
  magnitude_contract: Record<string, unknown>;
  examples: { title: string; source_text: string; witness_extraction: string; mapping_hint: string }[];
  provenance: Record<string, unknown>;
}

export interface CertificateInfo {
  key: string;
  source: string;
  target: string;
  path_len: number;
  verified: boolean;
}

export interface BridgeState {
  registry_bindings: { router_index: string; eml_tree: string }[];
  certificate_count: number;
  lift_cache_size: number;
  certificate_keys: string[];
}

export interface InstantiateRequest {
  spec_name: string;
  witness_data: Record<string, unknown>;
}

export interface InstantiateResponse {
  concept_name: string;
  spec_name: string;
  logic_type: string;
  certificate_key: string;
  certificate_verified: boolean;
}
