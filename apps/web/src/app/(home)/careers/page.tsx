import type { Metadata } from 'next';
import CareersPageClient from './careers-client';

// TEMPLATE PLACEHOLDER — replace with your company's own Careers metadata.
export const metadata: Metadata = {
  title: 'Careers',
  description: 'Open roles at this company — a template page, ready for your listings.',
  keywords: 'careers, jobs, hiring',
  openGraph: {
    title: 'Careers',
    description: 'Open roles at this company — a template page, ready for your listings.',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Careers',
    description: 'Open roles at this company — a template page, ready for your listings.',
  },
};

export default function CareersPage() {
  return <CareersPageClient />;
}
