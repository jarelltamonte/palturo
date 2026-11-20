// Cloudflare Worker for palturo.app.
// Redirects every plaintext request to HTTPS before serving the static build.

const GEO_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, OPTIONS",
  "access-control-allow-headers": "content-type",
  "cache-control": "no-store",
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.protocol === "http:") {
      url.protocol = "https:";
      return Response.redirect(url.toString(), 301);
    }

    // Coarse location for the signed-in user. Cloudflare derives this from the
    // request IP; the IP itself is never returned or stored.
    if (url.pathname === "/geo") {
      if (request.method === "OPTIONS") {
        return new Response(null, { headers: GEO_HEADERS });
      }
      const cf = request.cf ?? {};
      return new Response(
        JSON.stringify({
          country: cf.country ?? request.headers.get("cf-ipcountry") ?? null,
          region: cf.region ?? null,
          regionCode: cf.regionCode ?? null,
          city: cf.city ?? null,
          timezone: cf.timezone ?? null,
        }),
        {
          headers: {
            ...GEO_HEADERS,
            "content-type": "application/json; charset=utf-8",
          },
        },
      );
    }

    return env.ASSETS.fetch(request);
  },
};
