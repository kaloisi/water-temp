const API_KEY = '76ac86a6e10f44d6ac86a6e10ff4d6e6';

const STATIONS = [
  { id: 'KMAWEBST38', name: 'Water Temp' },
  { id: 'KMAWEBST37', name: 'Air Temp' }
];

const CORS_PROXY = 'https://corsproxy.io/?';

export async function fetchCurrentConditions(stationId) {
  const url = `https://api.weather.com/v2/pws/observations/current?stationId=${stationId}&format=json&units=e&apiKey=${API_KEY}`;
  const response = await fetch(CORS_PROXY + encodeURIComponent(url));
  if (!response.ok) {
    throw new Error(`Failed to fetch current conditions for ${stationId}`);
  }
  return response.json();
}

export async function fetchHistoricalData(stationId, date) {
  const formattedDate = date.toISOString().split('T')[0].replace(/-/g, '');
  const url = `https://api.weather.com/v2/pws/history/all?stationId=${stationId}&format=json&units=e&date=${formattedDate}&apiKey=${API_KEY}`;
  const response = await fetch(CORS_PROXY + encodeURIComponent(url));
  if (!response.ok) {
    throw new Error(`Failed to fetch historical data for ${stationId} on ${formattedDate}`);
  }
  return response.json();
}

export async function fetchLast3DaysData() {
  const today = new Date();
  const dates = [];

  for (let i = 0; i < 3; i++) {
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

export async function fetchLast24HoursData() {
  const now = new Date();
  const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

  // Fetch today and yesterday to cover the full 24-hour window
  const dates = [new Date(), new Date(now.getTime() - 24 * 60 * 60 * 1000)];

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

    // Filter to only include data from the last 24 hours
    allData[station.id].data = allData[station.id].data.filter(obs => {
      const obsTime = new Date(obs.obsTimeLocal);
      return obsTime >= twentyFourHoursAgo && obsTime <= now;
    });

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
