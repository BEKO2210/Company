'use client';

import Link from 'next/link';
import { Reveal } from '@/components/home/reveal';

// TEMPLATE PLACEHOLDER — replace with your company's own content.
// This page ships intentionally generic so every clone starts empty.
export default function FactoryPageClient() {
  return (
    <main className="min-h-screen bg-background">
      <article className="max-w-3xl mx-auto px-6 pt-28 sm:pt-36 pb-28 sm:pb-36">
        <Reveal>
          <h1 className="text-3xl sm:text-4xl md:text-5xl font-medium tracking-tight text-foreground mb-8">
            Factory
          </h1>
        </Reveal>

        <div className="space-y-5">
          <Reveal delay={0.05}>
            <p className="text-base text-muted-foreground leading-relaxed">
              This is a template page, ready for your content. Use it for a
              deep-dive, a manifesto, a playbook — whatever your company needs.
            </p>
          </Reveal>
          <Reveal delay={0.1}>
            <p className="text-base text-muted-foreground leading-relaxed">
              Edit this content in
              apps/web/src/app/(home)/factory/factory-client.tsx and the page
              metadata in factory/page.tsx — or remove the route entirely if you
              don&apos;t need it.
            </p>
          </Reveal>
          <Reveal delay={0.15}>
            <p className="text-base text-muted-foreground leading-relaxed">
              <Link
                href="/"
                className="text-foreground font-medium underline underline-offset-4 decoration-foreground/40 hover:decoration-foreground transition-colors"
              >
                Back home.
              </Link>
            </p>
          </Reveal>
        </div>
      </article>
    </main>
  );
}
