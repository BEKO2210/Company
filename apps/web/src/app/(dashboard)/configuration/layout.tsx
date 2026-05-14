import { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Configuration | The Company',
  description: 'OpenCode configuration settings',
};

export default function ConfigurationLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <>{children}</>;
}
