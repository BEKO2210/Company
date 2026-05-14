export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (url.pathname === '/' || url.pathname === '/registry.json') {
      return jsonResponse(registryJson);
    }

    if (url.pathname === '/index.json') {
      return jsonResponse(indexJson);
    }

    if (url.pathname === '/ocx.json' || url.pathname === '/ocx.jsonc') {
      return jsonResponse(ocxJson);
    }

    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, OPTIONS',
        },
      });
    }

    return new Response('Not Found', { status: 404 });
  },
};

function jsonResponse(payload) {
  return new Response(JSON.stringify(payload, null, 2), {
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'public, max-age=60',
    },
  });
}

const indexJson = {
  "name": "kortix-ocx-registry",
  "version": "1.0.0",
  "namespace": "kortix",
  "author": "kortix",
  "description": "Kortix Marketplace - Skills for Kortix AI Agents",
  "components": []
};

const registryJson = {
  "$schema": "https://registry.kortix.com/schema.json",
  "version": "1.0.0",
  "name": "kortix-ocx-registry",
  "description": "Kortix Marketplace - Skills for Kortix AI Agents",
  "updated": "2026-03-22",
  "registryUrl": "https://kortix-registry-6om.pages.dev",
  "repository": "https://github.com/kortix-ai/kortix-ocx-registry",
  "skills": []
};

const ocxJson = {
  "$schema": "https://ocx.kdco.dev/schemas/ocx.json",
  "namespace": "kortix",
  "author": "kortix",
  "name": "kortix-ocx-registry",
  "description": "Kortix Marketplace - Skills for Kortix AI Agents",
  "registries": {
    "kortix": {
      "url": "https://kortix-registry-6om.pages.dev"
    }
  },
  "lockRegistries": false,
  "skipCompatCheck": false,
  "components": {
    "skills": []
  }
};
