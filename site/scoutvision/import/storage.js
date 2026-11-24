let opening;

function database() {
  opening ||= new Promise((resolve, reject) => {
    const request = indexedDB.open("scoutvision-browser", 1);
    request.onupgradeneeded = () => {
      for (const name of ["replays", "labels"]) {
        request.result.createObjectStore(name, {keyPath: "id"});
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
  return opening;
}

export async function access(name, method, value) {
  const db = await database();
  const transaction = db.transaction(name, method === "get" || method === "getAll" ? "readonly" : "readwrite");
  const store = transaction.objectStore(name);
  const request = value === undefined ? store[method]() : store[method](value);
  return new Promise((resolve, reject) => {
    transaction.oncomplete = () => resolve(request.result);
    transaction.onabort = transaction.onerror = () => reject(transaction.error || request.error);
  });
}
