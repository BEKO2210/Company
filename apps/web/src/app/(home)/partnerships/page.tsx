import type { Metadata } from 'next';
import PartnershipsPageClient from './partnerships-client';

// TEMPLATE PLACEHOLDER — replace with your company's own content.
export const metadata: Metadata = {
  title: 'Partnerships',
  description: 'A template page, ready for your content.',
  keywords: 'partnerships, company',
  openGraph: {
    title: 'Partnerships',
    description: 'A template page, ready for your content.',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Partnerships',
    description: 'A template page, ready for your content.',
  },
};

export default function PartnershipsPage() {
  return <PartnershipsPageClient />;
}
