import { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'API Keys | The Company',
  description: 'Manage your API keys for programmatic access to The Company',
  openGraph: {
    title: 'API Keys | The Company',
    description: 'Manage your API keys for programmatic access to The Company',
    type: 'website',
  },
};

export default async function APIKeysLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <>{children}</>;
}
