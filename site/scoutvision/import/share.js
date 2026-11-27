// Opt-in sharing of checked frames and answers, so ScoutVision's models can be retrained on
// every venue people use. Off unless the visitor turns it on. Only the single frame that was
// checked is sent, with the answers; never the video.

const KEY = "scoutvision-share-v1";

let available = false;
// The site answers 405 (wrong method) when sharing storage is connected, 503 when it is not.
export async function sharingAvailable() {
  try { available = (await fetch("/api/scoutvision/contribute", {method:"GET"})).status === 405; }
  catch { available = false; }
  return available;
}
export const sharingOn = () => { try { return available && localStorage.getItem(KEY) === "yes"; } catch { return false; } };
export function setSharing(on) { try { localStorage.setItem(KEY, on ? "yes" : "no"); } catch { /* private mode */ } }

async function base64(blob) {
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let text = "";
  for (let i = 0; i < bytes.length; i += 32768) text += String.fromCharCode(...bytes.subarray(i, i + 32768));
  return btoa(text);
}

// A short, non-reversible id that groups frames from the same video without sending its name.
export async function clipId(key) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(String(key)));
  return Array.from(new Uint8Array(digest).slice(0, 12), b => b.toString(16).padStart(2, "0")).join("");
}

async function shrink(blob) {
  // Keep uploads small: frames are at most 960 px wide already; re-encode only if large.
  if (blob.size <= 600_000) return blob;
  const bitmap = await createImageBitmap(blob);
  const canvas = document.createElement("canvas");
  const scale = Math.min(1, 960 / bitmap.width);
  canvas.width = Math.round(bitmap.width * scale);
  canvas.height = Math.round(bitmap.height * scale);
  canvas.getContext("2d").drawImage(bitmap, 0, 0, canvas.width, canvas.height);
  bitmap.close();
  return new Promise(resolve => canvas.toBlob(resolve, "image/jpeg", .8));
}

/**
 * Send one contribution if sharing is on. Returns "shared", "off" or an error message; never
 * throws, so a failed upload can't interrupt checking or labelling.
 */
export async function share(kind, image, fields) {
  if (!sharingOn()) return "off";
  try {
    const small = await shrink(image);
    const bitmap = await createImageBitmap(small);
    const size = {width:bitmap.width, height:bitmap.height};
    bitmap.close();
    const response = await fetch("/api/scoutvision/contribute", {
      method:"POST", headers:{"Content-Type":"application/json"},
      body:JSON.stringify({version:1, kind, image:await base64(small), ...size, ...fields}),
    });
    if (response.ok) return "shared";
    const reason = await response.json().catch(() => ({}));
    return reason.error || `Sharing failed (${response.status}).`;
  } catch {
    return "Sharing failed (offline?).";
  }
}
