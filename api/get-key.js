
import {
  randomBytes,
  createHash
} from "node:crypto";

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({
      success: false,
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
      error: "Server configuration missing"
    });
  }

  // Do not trust a Roblox UserId supplied by a public browser.
  // Account ownership verification must be completed first.
  return res.status(403).json({
    success: false,
    error: "Roblox account verification is required before issuing a key."
  });
}
