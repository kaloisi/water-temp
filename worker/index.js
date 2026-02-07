const ALLOWED_ORIGIN = "api.weather.com";

export default {
  async fetch(request) {
    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(request) });
    }

    const url = new URL(request.url);
    const targetUrl = url.searchParams.get("url");

    if (!targetUrl) {
      return new Response(JSON.stringify({ error: "Missing ?url= parameter" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders(request) },
      });
    }

    // Only allow requests to api.weather.com
    let parsed;
    try {
      parsed = new URL(targetUrl);
    } catch {
      return new Response(JSON.stringify({ error: "Invalid URL" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders(request) },
      });
    }

    if (parsed.hostname !== ALLOWED_ORIGIN) {
      return new Response(JSON.stringify({ error: "Domain not allowed" }), {
        status: 403,
        headers: { "Content-Type": "application/json", ...corsHeaders(request) },
      });
    }

    // Forward the request to the weather API
    let apiResponse;
    try {
      apiResponse = await fetch(targetUrl, {
        headers: {
          "Accept": "application/json",
          "Accept-Encoding": "identity",
        },
      });
    } catch (err) {
      return new Response(JSON.stringify({ error: "Upstream fetch failed", message: err.message }), {
        status: 502,
        headers: { "Content-Type": "application/json", ...corsHeaders(request) },
      });
    }

    const body = await apiResponse.text();

    // Debug endpoint: add ?debug to the worker URL to see upstream details
    if (url.searchParams.has("debug")) {
      const debugInfo = {
        upstreamStatus: apiResponse.status,
        upstreamHeaders: Object.fromEntries(apiResponse.headers.entries()),
        bodyLength: body.length,
        bodyPreview: body.substring(0, 500),
      };
      return new Response(JSON.stringify(debugInfo, null, 2), {
        status: 200,
        headers: { "Content-Type": "application/json", ...corsHeaders(request) },
      });
    }

    return new Response(body, {
      status: apiResponse.status,
      headers: {
        "Content-Type": "application/json",
        ...corsHeaders(request),
      },
    });
  },
};

function corsHeaders(request) {
  return {
    "Access-Control-Allow-Origin": request.headers.get("Origin") || "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  };
}
