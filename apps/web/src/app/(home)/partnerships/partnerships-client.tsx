'use client';

import Link from 'next/link';
import { Reveal } from '@/components/home/reveal';

// TEMPLATE PLACEHOLDER — replace with your company's own partnerships content
// and contact details. This page ships intentionally generic so every clone
// starts empty.
export default function PartnershipsPageClient() {
  return (
    <main className="min-h-screen bg-background">
      <div className="max-w-3xl mx-auto px-6 pt-24 sm:pt-32 pb-24 sm:pb-32">
        <Reveal>
          <h1 className="text-3xl sm:text-4xl md:text-5xl font-medium tracking-tight text-foreground mb-5">
            Partnerships
          </h1>
        </Reveal>

        <Reveal delay={0.08}>
          <p className="text-base text-muted-foreground leading-relaxed max-w-xl">
            This is a template page, ready for your content. Describe how
            people can work with your company — partnerships, services, or
            joint ventures.
          </p>
        </Reveal>

        <Reveal delay={0.16}>
          <p className="text-base text-muted-foreground leading-relaxed max-w-xl mt-4">
            Edit this content in
            apps/web/src/app/(home)/partnerships/partnerships-client.tsx and the
            page metadata in partnerships/page.tsx — or remove the route if you
            don&apos;t need it.
          </p>
        </Reveal>

        <Reveal>
          <div className="mt-14 pt-8 border-t border-border">
            <p className="text-base text-muted-foreground leading-relaxed">
              Add your contact details here, then{' '}
              <Link
                href="/"
                className="text-foreground font-medium underline underline-offset-4 decoration-foreground/40 hover:decoration-foreground transition-colors"
              >
                head back home
              </Link>
              .
            </p>
          </div>
        </Reveal>
      </div>
    </main>
  );
}
