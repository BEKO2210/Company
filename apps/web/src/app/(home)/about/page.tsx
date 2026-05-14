import type { Metadata } from 'next';
import AboutPageClient from './about-client';

// TEMPLATE PLACEHOLDER — replace with your company's own About metadata.
export const metadata: Metadata = {
  title: 'About',
  description: 'About this company — a template page, ready for your story.',
  keywords: 'about, company, autonomous company',
  openGraph: {
    title: 'About',
    description: 'About this company — a template page, ready for your story.',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'About',
    description: 'About this company — a template page, ready for your story.',
  },
};

export default function AboutPage() {
  return <AboutPageClient />;
}
