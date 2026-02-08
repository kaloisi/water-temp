const DEFAULT_API_KEY = '76ac86a6e10f44d6ac86a6e10ff4d6e6';

const urlParams = new URLSearchParams(window.location.search);
const API_KEY = urlParams.get('apiKey') || DEFAULT_API_KEY;

export interface Station {
  id: string;
  name: string;
}

export const STATIONS: Station[] = [
  { id: 'KMAWEBST38', name: 'Water Temp' },
  { id: 'KMAWEBST37', name: 'Air Temp' },
];

const PROXY_BASE = 'https://kaloisi.white-hat-de0d.workers.dev/?url=';

export const WUNDERGROUND_DASHBOARD_URL = 'https://www.wunderground.com/dashboard/pws/';

interface ImperialData {
  temp: number;
  tempAvg?: number;
}

interface Observation {
  imperial: ImperialData;
  obsTimeLocal: string;
  tempAvg?: number;
  metric?: { tempAvg?: number };
}

interface CurrentConditionsResponse {
  observations: Observation[];
}

interface HistoricalResponse {
  observations: Observation[];
}

export interface StationCurrentData {
  name: string;
  data: Observation | null;
  error?: string;
}

export interface StationHistoricalData {
  name: string;
  data: Observation[];
}

export type CurrentConditionsMap = Record<string, StationCurrentData>;
export type HistoricalDataMap = Record<string, StationHistoricalData>;

export async function fetchCurrentConditions(stationId: string): Promise<CurrentConditionsResponse> {
  const url = `https://api.weather.com/v2/pws/observations/current?stationId=${stationId}&format=json&units=e&numericPrecision=decimal&apiKey=${API_KEY}`;
  console.log(`Fetching current conditions from URL: ${url}`);
  const response = await fetch(PROXY_BASE + encodeURIComponent(url));
  if (!response.ok) {
    throw new Error(`Failed to fetch current conditions for ${stationId}`);
  }
  return response.json();
}

async function fetchTodayRapidData(stationId: string): Promise<HistoricalResponse> {
  const url = `https://api.weather.com/v2/pws/observations/all/1day?stationId=${stationId}&format=json&units=e&numericPrecision=decimal&apiKey=${API_KEY}`;
  const response = await fetch(PROXY_BASE + encodeURIComponent(url));
  if (!response.ok) {
    throw new Error(`Failed to fetch today's data for ${stationId}`);
  }
  return response.json();
}

function formatDateLocal(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}${m}${d}`;
}

export async function fetchHistoricalData(stationId: string, date: Date): Promise<HistoricalResponse> {
  const formattedDate = formatDateLocal(date);
  const url = `https://api.weather.com/v2/pws/history/all?stationId=${stationId}&format=json&units=e&numericPrecision=decimal&date=${formattedDate}&apiKey=${API_KEY}`;
  const response = await fetch(PROXY_BASE + encodeURIComponent(url));
  if (!response.ok) {
    throw new Error(`Failed to fetch historical data for ${stationId} on ${formattedDate}`);
  }
  return response.json();
}

function isToday(date: Date): boolean {
  const today = new Date();
  return (
    date.getFullYear() === today.getFullYear() &&
    date.getMonth() === today.getMonth() &&
    date.getDate() === today.getDate()
  );
}

export async function fetchLastNDaysData(days = 3): Promise<HistoricalDataMap> {
  const today = new Date();
  const dates: Date[] = [];

  for (let i = 0; i < days; i++) {
    const date = new Date(today);
    date.setDate(date.getDate() - i);
    dates.push(date);
  }

  const allData: HistoricalDataMap = {};

  for (const station of STATIONS) {
    allData[station.id] = {
      name: station.name,
      data: [],
    };

    for (const date of dates) {
      try {
        const result = isToday(date)
          ? await fetchTodayRapidData(station.id)
          : await fetchHistoricalData(station.id, date);
        if (result.observations) {
          allData[station.id].data.push(...result.observations);
        }
      } catch (error) {
        console.error(`Error fetching data for ${station.id} on ${date}:`, error);
      }
    }

    allData[station.id].data.sort(
      (a, b) => new Date(a.obsTimeLocal).getTime() - new Date(b.obsTimeLocal).getTime()
    );
  }

  return allData;
}

export async function fetchAllCurrentConditions(): Promise<CurrentConditionsMap> {
  const results: CurrentConditionsMap = {};

  for (const station of STATIONS) {
    try {
      const data = await fetchCurrentConditions(station.id);
      results[station.id] = {
        name: station.name,
        data: data.observations?.[0] || null,
      };
    } catch (error) {
      console.error(`Error fetching current conditions for ${station.id}:`, error);
      results[station.id] = {
        name: station.name,
        data: null,
        error: error instanceof Error ? error.message : String(error),
      };
    }
  }

  return results;
}
