import { NextResponse } from 'next/server';

export const revalidate = 300; // cache for 5 minutes

export async function GET() {
  try {
    const res = await fetch('https://api.github.com/repos/beko2210/company', {
      headers: { 'Accept': 'application/vnd.github.v3+json' },
      next: { revalidate: 300 },
    });

    if (!res.ok) throw new Error(`GitHub API error: ${res.status}`);

    const data = await res.json();
    return NextResponse.json({ stars: data.stargazers_count });
  } catch {
    // GitHub unreachable — report 0 rather than a fabricated count
    return NextResponse.json({ stars: 0 });
  }
}
