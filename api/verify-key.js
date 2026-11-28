
import { createHash } from "node:crypto";

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({
      success: false,
      error: "Method not allowed"
    });
  }

  const {
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
    GAME_SERVER_SECRET
  } = process.env;

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY ||
      !GAME_SERVER_SECRET) {
    return res.status(500).json({
      success: false,
      error: "Server configuration missing"
    });
  }

  // Authenticate the caller
  const suppliedSecret = req.headers["x-game-server-secret"];

  if (
    typeof suppliedSecret !== "string" ||
    suppliedSecret !== GAME_SERVER_SECRET
  ) {
    return res.status(401).json({
      success: false,
      error: "Unauthorized"
    });
  }

  const key = String(req.body?.key || "").trim();
  const userId = String(req.body?.robloxUserId || "");

  if (!key || !/^[1-9]\d{0,19}$/.test(userId)) {
    return res.status(400).json({
      success: false,
      error: "Invalid key or Roblox UserId"
    });
  }

  const keyHash = createHash("sha256")
    .update(key)
    .digest("hex");

  const baseUrl = SUPABASE_URL.replace(/\/$/, "");

  const url = new URL(`${baseUrl}/rest/v1/keys`);

  url.searchParams.set(
    "select",
    "status,expires_at,roblox_user_id"
  );

  url.searchParams.set("key_hash", `eq.${keyHash}`);

  const headers = {
    apikey: SUPABASE_SERVICE_ROLE_KEY,
    Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
  };

  try {
    const response = await fetch(url, { headers });

    if (!response.ok) {
      throw new Error("Database lookup failed");
    }

    const rows = await response.json();

    if (rows.length === 0) {
      return res.status(200).json({
        success: false,
        valid: false,
        error: "Key not found"
      });
    }

    const record = rows[0];

    if (record.status !== "active") {
      return res.status(200).json({
        success: false,
        valid: false,
        error: "Key revoked"
      });
    }

    if (new Date(record.expires_at).getTime() <= Date.now()) {
      return res.status(200).json({
        success: false,
        valid: false,
        error: "Key expired"
      });
    }

    if (record.roblox_user_id !== userId) {
      return res.status(200).json({
        success: false,
        valid: false,
        error: "Key belongs to another Roblox account"
      });
    }

    return res.status(200).json({
      success: true,
      valid: true,
      expiresAt: record.expires_at
    });

  } catch (error) {
    console.error("Verify key error:", error);

    return res.status(500).json({
      success: false,
      error: "Verification failed"
    });
  }
}
