
import {
  randomBytes,
  createHash
} from "node:crypto";

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const {
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
    GAME_SERVER_SECRET
  } = process.env;

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !GAME_SERVER_SECRET) {
    return res.status(500).json({ error: "Missing server configuration" });
  }

  const suppliedSecret = req.headers["x-game-server-secret"];

  if (suppliedSecret !== GAME_SERVER_SECRET) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  const userId = String(req.body?.robloxUserId || "");

  if (!/^[1-9]\d{0,19}$/.test(userId)) {
    return res.status(400).json({ error: "Invalid Roblox UserId" });
  }

  const baseUrl = SUPABASE_URL.replace(/\/$/, "");

  const headers = {
    apikey: SUPABASE_SERVICE_ROLE_KEY,
    Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    "Content-Type": "application/json"
  };

  try {
    // Check whether the account already has a key
    const lookupUrl = new URL(`${baseUrl}/rest/v1/keys`);
    lookupUrl.searchParams.set("select", "id,status,expires_at");
    lookupUrl.searchParams.set("roblox_user_id", `eq.${userId}`);

    const lookup = await fetch(lookupUrl, { headers });

    if (!lookup.ok) throw new Error("Database lookup failed");

    const existing = await lookup.json();

    if (existing.length > 0) {
      return res.status(409).json({
        error: "Account already has a key",
        status: existing[0].status,
        expiresAt: existing[0].expires_at
      });
    }

    // Generate a new unique key
    const key = "SCR-" + randomBytes(24).toString("hex").toUpperCase();

    const keyHash = createHash("sha256")
      .update(key)
      .digest("hex");

    const expiresAt = new Date(
      Date.now() + 30 * 24 * 60 * 60 * 1000
    ).toISOString();

    // Save the key hash and Roblox account assignment
    const insert = await fetch(`${baseUrl}/rest/v1/keys`, {
      method: "POST",
      headers: {
        ...headers,
        Prefer: "return=minimal"
      },
      body: JSON.stringify({
        key_hash: keyHash,
        roblox_user_id: userId,
        status: "active",
        expires_at: expiresAt,
        label: `Roblox User ${userId}`
      })
    });

    if (!insert.ok) throw new Error("Could not save key");

    return res.status(200).json({
      success: true,
      key,
      expiresAt
    });

  } catch (error) {
    console.error("Get key error:", error);
    return res.status(500).json({ error: "Could not create key" });
  }
}
