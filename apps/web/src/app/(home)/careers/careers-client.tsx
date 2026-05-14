'use client';

import { Reveal } from '@/components/home/reveal';

// TEMPLATE PLACEHOLDER — replace with your company's own roles and contact.
// This page ships intentionally generic so every clone starts empty.
export default function CareersPageClient() {
  return (
    <main className="min-h-screen bg-background">
      <div className="max-w-3xl mx-auto px-6 pt-24 sm:pt-32 pb-24 sm:pb-32">

        {/* Hero */}
        <Reveal>
          <h1 className="text-3xl sm:text-4xl md:text-5xl font-medium tracking-tight text-foreground mb-5">
            Careers
          </h1>
        </Reveal>
        <Reveal delay={0.08}>
          <p className="text-base text-muted-foreground leading-relaxed max-w-xl">
            This is your Careers page — a template, ready for your roles.
            Describe the kind of people you want to work with and what your
            company is building.
          </p>
        </Reveal>
        <Reveal delay={0.16}>
          <p className="text-base text-muted-foreground leading-relaxed max-w-xl mt-4">
            Edit this content in apps/web/src/app/(home)/careers/careers-client.tsx
            and the page metadata in careers/page.tsx.
          </p>
        </Reveal>

        {/* Position */}
        <Reveal>
          <div className="mt-14">
            <h2 className="text-xs uppercase tracking-widest text-muted-foreground mb-5">
              Open Positions
            </h2>
            <div>
              <p className="text-base font-semibold text-foreground">
                Example Role
              </p>
              <p className="text-base text-muted-foreground leading-relaxed mt-1.5">
                Replace this with a real role: what the person will do, what
                you are looking for, and where the role is based.
              </p>
            </div>
          </div>
        </Reveal>

        {/* Contact */}
        <Reveal>
          <div className="mt-14 pt-8 border-t border-border">
            <p className="text-base text-muted-foreground leading-relaxed">
              Add your hiring contact here — an email address or a link to
              your application form.
            </p>
          </div>
        </Reveal>

      </div>
    </main>
  );
}
