/**
 * Site metadata configuration - SIMPLE AND WORKING
 */

const baseUrl = process.env.KORTIX_PUBLIC_APP_URL || process.env.NEXT_PUBLIC_APP_URL || process.env.NEXT_PUBLIC_URL || 'http://localhost:3000';

export const siteMetadata = {
  name: 'The Company',
  title: 'The Company – The Autonomous Company Operating System',
  description:
    'A cloud computer where AI agents run your company. Connect 3,000+ tools, configure autonomous agents, set triggers — and the machine operates 24/7 with persistent memory.',
  url: baseUrl,
  keywords:
    'The Company, autonomous company operating system, AI agents, self-driving company, cloud computer, AI automation, agent orchestration, goal loops, AI triggers, persistent memory, autonomous workforce, AI operations',
};
