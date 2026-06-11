/**
 * Standalone entry point for the Tamari Lattice Explorer.
 * Mounted at /tamari.html — opens in a separate window from the main app.
 */
import React from 'react';
import ReactDOM from 'react-dom/client';
import { TamariExplorer } from './components/tamari/TamariExplorer';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <TamariExplorer initialN={3} />
  </React.StrictMode>,
);
