import { apiFetch } from './apiClient';

export interface StatsOverview {
  totalUsers: number;
  totalServers: number;
  totalChannels: number;
  totalMessages: number;
  activeVoiceParticipants: number;
  bannedUsers: number;
  newUsersLast7Days: number;
  newServersLast7Days: number;
  messagesLast24h: number;
  generatedAt: string;
}

export interface DailyCount {
  date: string;
  count: number;
}

export function getOverview(): Promise<StatsOverview> {
  return apiFetch<StatsOverview>('/admin/stats/overview');
}

export function getDailySignups(days = 30): Promise<DailyCount[]> {
  return apiFetch<DailyCount[]>(`/admin/stats/signups?days=${days}`);
}

export function getDailyMessages(days = 30): Promise<DailyCount[]> {
  return apiFetch<DailyCount[]>(`/admin/stats/messages?days=${days}`);
}
