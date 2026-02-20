/**
 * Shared phone hash utility for edge functions.
 * Must produce identical output to iOS ContactDiscoveryService.hashPhoneNumber().
 *
 * iOS implementation:
 *   let normalized = phone.components(separatedBy: CharacterSet.decimalDigits.inverted
 *       .subtracting(CharacterSet(charactersIn: "+"))).joined()
 *   let hash = SHA256.hash(data: Data(normalized.utf8))
 *
 * This means: keep only digits and "+", then SHA-256 the result.
 */

export async function hashPhoneNumber(phone: string): Promise<string> {
  // Strip everything except digits and "+"
  const normalized = phone.replace(/[^\d+]/g, "");
  const data = new TextEncoder().encode(normalized);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
