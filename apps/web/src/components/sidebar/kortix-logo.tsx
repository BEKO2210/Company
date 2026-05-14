'use client';

import { cn } from '@/lib/utils';

interface KortixLogoProps {
  size?: number;
  variant?: 'symbol' | 'logomark';
  className?: string;
}

// The Company logo — a full-colour emblem (black + gold). Unlike the old
// monochrome marks it is NOT inverted for dark mode. One emblem asset covers
// both the `symbol` and `logomark` slots.
export function KortixLogo({ size = 24, variant = 'symbol', className }: KortixLogoProps) {
  void variant;
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src="/the-company-logo.png"
      alt="The Company"
      className={cn('flex-shrink-0 object-contain', className)}
      style={{ width: `${size}px`, height: `${size}px` }}
      suppressHydrationWarning
    />
  );
}
