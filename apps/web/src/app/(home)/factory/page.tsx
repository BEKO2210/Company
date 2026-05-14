import type { Metadata } from 'next';
import FactoryPageClient from './factory-client';

// TEMPLATE PLACEHOLDER — replace with your company's own content.
export const metadata: Metadata = {
  title: 'Factory',
  description: 'A template page, ready for your content.',
  keywords: 'company, autonomous company',
  openGraph: {
    title: 'Factory',
    description: 'A template page, ready for your content.',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Factory',
    description: 'A template page, ready for your content.',
  },
};

export default function FactoryPage() {
  return <FactoryPageClient />;
}
