'use client';

import Link from 'next/link';
import { Reveal } from '@/components/home/reveal';

// TEMPLATE PLACEHOLDER — replace with your company's own story.
// This page ships intentionally generic so every clone starts empty.
type ParagraphItem =
  | string
  | { text: string; linkText: string; linkHref: string };

const paragraphs: ParagraphItem[] = [
  'This is your About page — a template, ready for your story.',
  'Describe what your company does, who it is for, and why it exists. The more specific and honest you are, the more it will resonate.',
  'Edit this content in apps/web/src/app/(home)/about/about-client.tsx and the page metadata in about/page.tsx.',
  { text: 'Looking to join? ', linkText: 'See open roles.', linkHref: '/careers' },
];

export default function AboutPageClient() {
  return (
    <main className="min-h-screen bg-background">
      <article className="max-w-3xl mx-auto px-6 pt-24 sm:pt-32 pb-24 sm:pb-32">
        <Reveal>
          <h1 className="text-3xl sm:text-4xl md:text-5xl font-medium tracking-tight text-foreground mb-8">
            About
          </h1>
        </Reveal>

        <div className="space-y-5">
          {paragraphs.map((paragraph, index) => (
            <Reveal key={index} delay={index * 0.08}>
              <p className="text-base text-muted-foreground leading-relaxed">
                {typeof paragraph === 'string' ? (
                  paragraph
                ) : (
                  <>
                    {paragraph.text}
                    <Link
                      href={paragraph.linkHref}
                      className="text-foreground font-medium underline underline-offset-4 decoration-foreground/40 hover:decoration-foreground transition-colors"
                    >
                      {paragraph.linkText}
                    </Link>
                  </>
                )}
              </p>
            </Reveal>
          ))}
        </div>
      </article>
    </main>
  );
}
