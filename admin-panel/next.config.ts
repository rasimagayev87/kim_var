import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // firebase-admin pulls in jwks-rsa -> jose, which Turbopack's production
  // bundler mis-transforms into a broken CJS/ESM require() at runtime
  // ("ERR_REQUIRE_ESM"). Keeping it external skips bundling it and loads it
  // straight from node_modules instead, where Node's own resolver handles it.
  serverExternalPackages: ["firebase-admin"],
};

export default nextConfig;
