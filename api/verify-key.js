
import { createHash } from "node:crypto";

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({
      success: false,
      valid: false,
      error: "Method not allowed"
    });
  }

  const {
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY
  } = process.env;

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return res.status(500).json({
      success: false,
      valid: false,
      error: "Server configuration missing"
    });
  }

  const key = String(req.body?.key || "").trim();
  const userId = String(req.body?.robloxUserId || "");

  if (!/^SCR-[A-F0-9]{48}$/.test(key)) {
    return res.status(400).json({
      success: false,
      valid: false,
      error: "Invalid key format"
    });
  }

  if (!/^[1-9]\d{0,19}$/.test(userId)) {
    return res.status(400).json({
      success: false,
      valid: false,
      error: "Invalid Roblox UserId"
    });
  }

  const keyHash = createHash("sha256")
    .update(key)
    .digest("hex");

  const url = new URL(
    `${SUPABASE_URL.replace(/\/$/, "")}/rest/v1/keys`
  );

  url.searchParams.set(
    "select",
    "status,expires_at,roblox_user_id"
  );

  url.searchParams.set("key_hash", `eq.${keyHash}`);

  try {
    const response = await fetch(url, {
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
      }
    });

    if (!response.ok) {
      throw new Error("Database lookup failed");
    }

    const rows = await response.json();

    if (rows.length === 0) {
      return res.status(200).json({
        success: true,
        valid: false,
        error: "Key not found"
      });
    }

    const record = rows[0];

    if (record.roblox_user_id !== userId) {
      return res.status(200).json({
        success: true,
        valid: false,
        error: "Key belongs to another account"
      });
    }

    if (
      record.status !== "active" ||
      new Date(record.expires_at).getTime() <= Date.now()
    ) {
      return res.status(200).json({
        success: true,
        valid: false,
        error: "Key expired or revoked"
      });
    }

    return res.status(200).json({
      success: true,
      valid: true,
      expiresAt: record.expires_at
    });

  } catch (error) {
    console.error("Verify error:", error);

    return res.status(500).json({
      success: false,
      valid: false,
      error: "Verification failed"
    });
  }
}
