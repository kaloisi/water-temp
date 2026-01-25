const API_KEY = '76ac86a6e10f44d6ac86a6e10ff4d6e6';

const STATIONS = [
  { id: 'KMAWEBST38', name: 'Water Temp' },
  { id: 'KMAWEBST37', name: 'Air Temp' }
];

const CORS_PROXY = 'https://proxy.corsfix.com/?';

const NO_CACHE_HEADERS = {
  'Cache-Control': 'no-cache, no-store, must-revalidate',
  'Pragma': 'no-cache',
  'Expires': '0',
  "x-corsfix-cache": "false"
};

export async function fetchCurrentConditions(stationId) {
  const url = `https://api.weather.com/v2/pws/observations/current?stationId=${stationId}&format=json&units=e&numericPrecision=decimal&apiKey=${API_KEY}`;
  console.log(`Fetching current conditions from URL: ${url}`);
  const proxyUrl = CORS_PROXY + url;
  const response = await fetch(proxyUrl, { headers: NO_CACHE_HEADERS });
  if (!response.ok) {
    throw new Error(`Failed to fetch current conditions for ${stationId}`);
  }
  return response.json();
}


export async function fetchHistoricalData(stationId, date) {
  const formattedDate = date.toISOString().split('T')[0].replace(/-/g, '');
  const url = `https://api.weather.com/v2/pws/history/all?stationId=${stationId}&format=json&units=e&numericPrecision=decimal&date=${formattedDate}&apiKey=${API_KEY}`;
  const proxyUrl = CORS_PROXY + url;
  const response = await fetch(proxyUrl, { headers: NO_CACHE_HEADERS });
  if (!response.ok) {
    throw new Error(`Failed to fetch historical data for ${stationId} on ${formattedDate}`);
  }
  return response.json();
}

export async function fetchLastNDaysData(days = 3) {
  const today = new Date();
  const dates = [];

  for (let i = 0; i < days; i++) {
    const date = new Date(today);
    date.setDate(date.getDate() - i);
    dates.push(date);
  }

  const allData = {};

  for (const station of STATIONS) {
    allData[station.id] = {
      name: station.name,
      data: []
    };

    for (const date of dates) {
      try {
        const result = await fetchHistoricalData(station.id, date);
        if (result.observations) {
          allData[station.id].data.push(...result.observations);
        }
      } catch (error) {
        console.error(`Error fetching data for ${station.id} on ${date}:`, error);
      }
    }

    allData[station.id].data.sort((a, b) =>
      new Date(a.obsTimeLocal) - new Date(b.obsTimeLocal)
    );
  }

  return allData;
}

export async function fetchAllCurrentConditions() {
  const results = {};

  for (const station of STATIONS) {
    try {
      const data = await fetchCurrentConditions(station.id);
      results[station.id] = {
        name: station.name,
        data: data.observations?.[0] || null
      };
    } catch (error) {
      console.error(`Error fetching current conditions for ${station.id}:`, error);
      results[station.id] = {
        name: station.name,
        data: null,
        error: error.message
      };
    }
  }

  return results;
}

export { STATIONS };
