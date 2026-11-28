
import { randomBytes, createHash } from "node:crypto";

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const {
    SUPABASE_URL,
    SUPABASE_ANON_KEY,
    SUPABASE_SERVICE_ROLE_KEY,
    ADMIN_EMAIL
  } = process.env;

  if (
    !SUPABASE_URL ||
    !SUPABASE_ANON_KEY ||
    !SUPABASE_SERVICE_ROLE_KEY ||
    !ADMIN_EMAIL
  ) {
    return res.status(500).json({
      error: "Server environment variables are missing"
    });
  }

  try {
    // Verify the logged-in Supabase user
    const authHeader = req.headers.authorization || "";
    const token = authHeader.startsWith("Bearer ")
      ? authHeader.slice(7)
      : "";

    if (!token) {
      return res.status(401).json({
        error: "Authentication required"
      });
    }

    const authResponse = await fetch(
      `${SUPABASE_URL}/auth/v1/user`,
      {
        headers: {
          apikey: SUPABASE_ANON_KEY,
          Authorization: `Bearer ${token}`
        }
      }
    );

    if (!authResponse.ok) {
      return res.status(401).json({
        error: "Invalid login session"
      });
    }

    const user = await authResponse.json();

    if (
      !user.email ||
      user.email.toLowerCase() !== ADMIN_EMAIL.toLowerCase()
    ) {
      return res.status(403).json({
        error: "Admin access required"
      });
    }

    // Validate expiration
    const days = Number(req.body?.expiresInDays ?? 30);

    if (
      !Number.isInteger(days) ||
      days < 1 ||
      days > 365
    ) {
      return res.status(400).json({
        error: "Expiration must be between 1 and 365 days"
      });
    }

    const label = String(req.body?.label || "New Key")
      .trim()
      .slice(0, 80);

    // Generate a unique key
    const key =
      "SCR-" + randomBytes(24).toString("hex").toUpperCase();

    // Hash it before storing it
    const keyHash = createHash("sha256")
      .update(key)
      .digest("hex");

    const expiresAt = new Date(
      Date.now() + days * 24 * 60 * 60 * 1000
    ).toISOString();

    // Save the key in Supabase
    const databaseResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/keys`,
      {
        method: "POST",
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          "Content-Type": "application/json",
          Prefer: "return=minimal"
        },
        body: JSON.stringify({
          key_hash: keyHash,
          status: "active",
          expires_at: expiresAt,
          label
        })
      }
    );

    if (!databaseResponse.ok) {
      const error = await databaseResponse.text();
      console.error("Supabase insert failed:", error);

      return res.status(500).json({
        error: "Could not save key"
      });
    }

    return res.status(200).json({
      success: true,
      key,
      label,
      expiresAt
    });

  } catch (error) {
    console.error("Create key error:", error);

    return res.status(500).json({
      error: "Internal server error"
    });
  }
}
