/**
 * SpecBrowserPanel — the Reading Room.
 *
 * Browse the 10 seed CortexSpecs, inspect their witness schemas,
 * magnitude contracts, and worked examples.  Selecting a spec
 * pre-populates the inference target.
 */
import { useState, useEffect, useCallback } from 'react';
import {
  BookOpen,
  ChevronDown,
  ChevronUp,
  FileJson,
  RefreshCw,
  AlertCircle,
  CheckCircle2,
  X,
  Eye,
  EyeOff,
  Scale,
  Siren,
} from 'lucide-react';
import { cortexApi } from '../../services/cortexApi';
import type { SpecSummary, SpecDetail } from '../../types/cortex';

interface SpecBrowserPanelProps {
  isOpen: boolean;
  onToggle: () => void;
}

export function SpecBrowserPanel({ isOpen, onToggle }: SpecBrowserPanelProps) {
  const [specs, setSpecs] = useState<SpecSummary[]>([]);
  const [selectedSpec, setSelectedSpec] = useState<SpecDetail | null>(null);
  const [loading, setLoading] = useState(false);
  const [detailLoading, setDetailLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [expandedExample, setExpandedExample] = useState<number | null>(null);
  const [showPayload, setShowPayload] = useState(false);

  const fetchSpecs = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await cortexApi.listSpecs();
      setSpecs(data);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to load specs');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (isOpen && specs.length === 0) {
      fetchSpecs();
    }
  }, [isOpen, specs.length, fetchSpecs]);

  const selectSpec = async (name: string) => {
    setDetailLoading(true);
    setError(null);
    try {
      const detail = await cortexApi.getSpec(name);
      setSelectedSpec(detail);
      setExpandedExample(null);
      setShowPayload(false);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to load spec detail');
    } finally {
      setDetailLoading(false);
    }
  };

  const logicTypeColor = (lt: string): string => {
    switch (lt) {
      case 'CLASSICAL': return 'text-blue-600 bg-blue-50';
      case 'TEMPORAL': return 'text-amber-600 bg-amber-50';
      case 'QUANTUM': return 'text-purple-600 bg-purple-50';
      default: return 'text-slate-600 bg-slate-50';
    }
  };

  if (!isOpen) return null;

  return (
    <div className="border-b border-slate-200 bg-white">
      <div className="flex items-center justify-between px-4 py-2 bg-slate-50 border-b border-slate-200">
        <div className="flex items-center gap-2">
          <BookOpen size={16} className="text-amber-600" />
          <span className="text-sm font-medium text-slate-700">Reading Room</span>
          <span className="text-xs text-slate-400">({specs.length} statutes)</span>
        </div>
        <div className="flex items-center gap-1">
          <button
            onClick={fetchSpecs}
            disabled={loading}
            className="p-1 text-slate-400 hover:text-slate-600 rounded transition-colors disabled:opacity-50"
            title="Refresh specs"
          >
            <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
          </button>
          <button
            onClick={onToggle}
            className="p-1 text-slate-400 hover:text-slate-600 rounded transition-colors"
            title="Close"
          >
            <X size={14} />
          </button>
        </div>
      </div>

      {error && (
        <div className="mx-4 mt-2 px-3 py-2 bg-red-50 border border-red-200 rounded-lg flex items-center gap-2 text-sm text-red-700">
          <AlertCircle size={14} />
          {error}
        </div>
      )}

      <div className="flex max-h-96 overflow-hidden">
        {/* Spec list */}
        <div className="w-1/3 border-r border-slate-200 overflow-y-auto">
          {specs.map((spec) => (
            <button
              key={spec.cortex_name}
              onClick={() => selectSpec(spec.cortex_name)}
              className={`w-full text-left px-3 py-2 border-b border-slate-100 hover:bg-slate-50 transition-colors ${
                selectedSpec?.cortex_name === spec.cortex_name ? 'bg-amber-50 border-l-2 border-l-amber-500' : ''
              }`}
            >
              <div className="text-sm font-medium text-slate-800 truncate">
                {spec.cortex_name}
              </div>
              <div className="flex items-center gap-2 mt-0.5">
                <span className={`text-xs px-1.5 py-0.5 rounded ${logicTypeColor(spec.logic_type)}`}>
                  {spec.logic_type}
                </span>
                <span className="text-xs text-slate-400">{spec.form_type}</span>
              </div>
              <div className="text-xs text-slate-400 mt-0.5">
                {spec.axes.join(', ')}
              </div>
            </button>
          ))}
        </div>

        {/* Spec detail */}
        <div className="w-2/3 overflow-y-auto">
          {detailLoading ? (
            <div className="flex items-center justify-center h-full py-8">
              <RefreshCw size={20} className="animate-spin text-slate-400" />
            </div>
          ) : selectedSpec ? (
            <div className="p-3 space-y-3">
              <div>
                <h3 className="text-sm font-semibold text-slate-800">{selectedSpec.cortex_name}</h3>
                <div className="flex items-center gap-2 mt-1">
                  <span className={`text-xs px-1.5 py-0.5 rounded ${logicTypeColor(selectedSpec.logic_type)}`}>
                    {selectedSpec.logic_type}
                  </span>
                  <span className="text-xs text-slate-500">{selectedSpec.form_type}</span>
                  <span className="text-xs text-slate-400">v{selectedSpec.form_schema_version}</span>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-2">
                <div className="text-xs">
                  <span className="text-slate-500">Coupling:</span>{' '}
                  <span className="font-medium text-slate-700">{selectedSpec.coupling_signature}</span>
                </div>
                <div className="text-xs">
                  <span className="text-slate-500">Witness type:</span>{' '}
                  <span className="font-medium text-slate-700">{selectedSpec.validation.witness_type as string}</span>
                </div>
                <div className="text-xs">
                  <span className="text-slate-500">Axes:</span>{' '}
                  <span className="font-medium text-slate-700">{selectedSpec.axes.join(', ')}</span>
                </div>
                <div className="text-xs">
                  <span className="text-slate-500">Shape:</span>{' '}
                  <span className="font-medium text-slate-700">[{selectedSpec.tensor_shape.join(', ')}]</span>
                </div>
              </div>

              <div>
                <button
                  onClick={() => setShowPayload(!showPayload)}
                  className="flex items-center gap-1 text-xs text-slate-500 hover:text-slate-700 transition-colors"
                >
                  {showPayload ? <EyeOff size={12} /> : <Eye size={12} />}
                  {showPayload ? 'Hide payload' : 'Show default payload'}
                </button>
                {showPayload && (
                  <pre className="mt-1 p-2 bg-slate-50 rounded text-xs text-slate-600 overflow-x-auto max-h-32">
                    {JSON.stringify(selectedSpec.default_payload, null, 2)}
                  </pre>
                )}
              </div>

              <div>
                <div className="flex items-center gap-1 text-xs text-slate-500 mb-1">
                  <Scale size={12} />
                  Magnitude Contract
                </div>
                <div className="grid grid-cols-2 gap-1 text-xs">
                  <div className="text-slate-500">Witness mass:</div>
                  <div className="text-slate-700">
                    [{selectedSpec.magnitude_contract.witness_mass_min as number}, {selectedSpec.magnitude_contract.witness_mass_max as number}]
                  </div>
                  <div className="text-slate-500">Skeptic mass:</div>
                  <div className="text-slate-700">
                    [{selectedSpec.magnitude_contract.skeptic_mass_min as number}, {selectedSpec.magnitude_contract.skeptic_mass_max as number}]
                  </div>
                  <div className="text-slate-500">Balance threshold:</div>
                  <div className="text-slate-700">{selectedSpec.magnitude_contract.balance_threshold as number}</div>
                </div>
              </div>

              {selectedSpec.examples.length > 0 && (
                <div>
                  <div className="flex items-center gap-1 text-xs text-slate-500 mb-1">
                    <Siren size={12} />
                    Worked Examples ({selectedSpec.examples.length})
                  </div>
                  {selectedSpec.examples.map((ex, i) => (
                    <div key={i} className="mb-1">
                      <button
                        onClick={() => setExpandedExample(expandedExample === i ? null : i)}
                        className="w-full flex items-center justify-between px-2 py-1 bg-slate-50 hover:bg-slate-100 rounded text-xs text-left transition-colors"
                      >
                        <span className="font-medium text-slate-700 truncate">{ex.title}</span>
                        {expandedExample === i ? <ChevronUp size={12} /> : <ChevronDown size={12} />}
                      </button>
                      {expandedExample === i && (
                        <div className="px-2 py-1.5 space-y-1 text-xs text-slate-600">
                          <p><span className="text-slate-400">Source:</span> {ex.source_text}</p>
                          <p><span className="text-slate-400">Witness:</span> {ex.witness_extraction}</p>
                          <p><span className="text-slate-400">Mapping:</span> {ex.mapping_hint}</p>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}

              <div className="flex items-center gap-1 text-xs text-slate-400 pt-1 border-t border-slate-100">
                <CheckCircle2 size={10} className="text-green-500" />
                Provenance: {selectedSpec.provenance.prompt as string}
              </div>
            </div>
          ) : (
            <div className="flex items-center justify-center h-full text-sm text-slate-400 py-8">
              Select a spec to inspect
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
