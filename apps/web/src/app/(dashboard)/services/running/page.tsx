'use client';

import { useEffect, useRef } from 'react';
import { useTabStore } from '@/stores/tab-store';

/**
 * /services/running — redirects to service-manager tab.
 * Kept for backwards compatibility with old bookmarks/links.
 */
export default function RunningServicesPage() {
  const { tabs, openTab, setActiveTab } = useTabStore();
  const handledRef = useRef(false);

  useEffect(() => {
    if (handledRef.current) return;
    handledRef.current = true;

    const tabId = 'service-manager';

    if (tabs[tabId]) {
      setActiveTab(tabId);
    } else {
      openTab({
        id: tabId,
        title: 'Service Manager',
        type: 'services',
        href: '/service-manager',
      });
    }
  }, [tabs, openTab, setActiveTab]);

  return null;
}
