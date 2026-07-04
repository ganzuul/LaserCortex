import React from 'react';
import ReactDOM from 'react-dom/client';
import { OctolinearLattice } from './components/tamari/OctolinearLattice';

async function loadData() {
  const response = await fetch('/octolinear_T4.json');
  if (!response.ok) {
    throw new Error(`Failed to load octolinear data: ${response.status}`);
  }
  return response.json();
}

function App() {
  const [data, setData] = React.useState<any>(null);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    loadData()
      .then(d => {
        setData(d);
        // Update stats display
        document.getElementById('num-nodes')!.textContent = d.stats.num_nodes.toString();
        document.getElementById('num-edges')!.textContent = d.stats.num_edges.toString();
        document.getElementById('edges-90')!.textContent = d.stats.edges_90.toString();
        document.getElementById('edges-45')!.textContent = d.stats.edges_45.toString();
        document.getElementById('x-range')!.textContent = `[${d.stats.x_range[0]}, ${d.stats.x_range[1]}]`;
        document.getElementById('y-range')!.textContent = `[${d.stats.y_range[0]}, ${d.stats.y_range[1]}]`;
      })
      .catch(err => setError(err.message));
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
        Loading octolinear lattice data...
      </div>
    );
  }

  return (
    <OctolinearLattice
      data={data}
      width={1000}
      height={700}
    />
  );
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
