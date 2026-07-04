/**
 * Entry point for Tamari Lattice Hasse diagram visualization.
 * Uses dagre-d3 for automatic hierarchical layout.
 */
import React from 'react';
import ReactDOM from 'react-dom/client';
import { TamariLattice } from './components/tamari/TamariLattice';

// Fetch lattice data
async function loadLatticeData() {
  const response = await fetch('/tamari_lattice_T4.json');
  if (!response.ok) {
    throw new Error(`Failed to load lattice data: ${response.status}`);
  }
  return response.json();
}

// Main app component
function App() {
  const [data, setData] = React.useState<any>(null);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    loadLatticeData()
      .then(setData)
      .catch((err) => setError(err.message));
  }, []);

  if (error) {
    return (
      <div style={{ color: 'red', padding: '20px' }}>
        Error: {error}
      </div>
    );
  }

  if (!data) {
    return (
      <div style={{ padding: '20px' }}>
        Loading lattice data...
      </div>
    );
  }

  return (
    <TamariLattice
      data={data}
      width={1000}
      height={700}
    />
  );
}

// Mount the app
ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
