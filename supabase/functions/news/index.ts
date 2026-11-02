// Proxy for the g1 Maranhão RSS feed, used by web/print.html's "Notícias".
// The feed sends no CORS headers, so a browser page can't read it
// directly. The URL is fixed here: this is not an open proxy.
//
// Deploy: supabase functions deploy news --project-ref jixjuabvprbyupmaqtma

// The old /dynamo/ma/maranhao/rss2.xml address redirects here.
const FEED = "https://g1.globo.com/rss/g1/ma/maranhao/";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const res = await fetch(FEED);
    if (!res.ok) {
      return new Response(`feed returned ${res.status}`, {
        status: 502,
        headers: cors,
      });
    }
    return new Response(await res.text(), {
      headers: {
        ...cors,
        "Content-Type": "application/xml; charset=utf-8",
        // g1 itself caches for 10 minutes.
        "Cache-Control": "public, max-age=600",
      },
    });
  } catch (e) {
    return new Response(String(e), { status: 502, headers: cors });
  }
});
