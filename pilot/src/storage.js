import { seed, apply, validateBackup } from './domain.js';
const DATABASE = 'zivlo-peru-pilot-v1';
let db;
const channel = typeof BroadcastChannel !== 'undefined' ? new BroadcastChannel(DATABASE) : null;
export function onOtherTab(fn) {
  if (channel) channel.onmessage = fn;
}
export function openDatabase() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DATABASE, 1);
    request.onupgradeneeded = () => request.result.createObjectStore('state');
    request.onerror = () =>
      reject(
        new Error(
          'No se pudo abrir el almacenamiento local. Usa un navegador con IndexedDB habilitado.',
        ),
      );
    request.onsuccess = () => {
      db = request.result;
      resolve(db);
    };
  });
}
export function readState() {
  return new Promise((resolve, reject) => {
    const tx = db.transaction('state', 'readwrite');
    let state;
    const store = tx.objectStore('state');
    const request = store.get('current');
    request.onsuccess = () => {
      state = request.result ?? seed();
      if (!request.result) store.put(state, 'current');
    };
    tx.oncomplete = () => resolve(state);
    tx.onerror = () => reject(new Error('No se pudo leer la base de datos local.'));
  });
}
export function commit(action, expectedRevision) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction('state', 'readwrite');
    const store = tx.objectStore('state');
    let outcome, error;
    store.get('current').onsuccess = (event) => {
      try {
        const state = event.target.result;
        if (state.revision !== expectedRevision)
          throw new Error(
            'Los datos cambiaron en otra pestaña. Vuelve a intentar con la información actualizada.',
          );
        if (action.type === 'restore') {
          const restored = validateBackup(action.state);
          restored.revision = state.revision + 1;
          outcome = { state: restored, result: null };
        } else outcome = apply(state, action);
        store.put(outcome.state, 'current');
      } catch (e) {
        error = e;
        tx.abort();
      }
    };
    tx.oncomplete = () => {
      channel?.postMessage({ revision: outcome.state.revision });
      resolve(outcome);
    };
    tx.onabort = () =>
      reject(
        error ??
          new Error('No se guardó la operación. Revisa el espacio disponible y vuelve a intentar.'),
      );
    tx.onerror = () => {
      error ??= new Error('No se guardó la operación. Revisa el almacenamiento del navegador.');
    };
  });
}
