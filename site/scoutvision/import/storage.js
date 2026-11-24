let opening;

// Version 2 adds "models" (detector heads and scoring cameras trained in this browser)
// and "scoring" (frames where someone labelled goal stacks and toggles).
const STORES = ["replays", "labels", "models", "scoring"];

function database() {
  opening ||= new Promise((resolve, reject) => {
    const request = indexedDB.open("scoutvision-browser", 2);
    request.onupgradeneeded = () => {
      for (const name of STORES) {
        if (!request.result.objectStoreNames.contains(name)) request.result.createObjectStore(name, {keyPath: "id"});
      }
    };
    request.onsuccess = () => {
      request.result.onversionchange = () => request.result.close();
      resolve(request.result);
    };
    request.onerror = () => reject(request.error);
    request.onblocked = () => reject(new Error("Close other Match studio tabs, then reload this page."));
  }).catch(error => { opening = undefined; throw error; });
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
