import { useState, useEffect } from 'react';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer
} from 'recharts';
import { fetchAllCurrentConditions, fetchLast3DaysData, STATIONS } from './weatherService';
import './App.css';

function App() {
  const [currentConditions, setCurrentConditions] = useState({});
  const [chartData, setChartData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    async function loadData() {
      try {
        setLoading(true);
        setError(null);

        const [current, historical] = await Promise.all([
          fetchAllCurrentConditions(),
          fetchLast3DaysData()
        ]);

        setCurrentConditions(current);

        const mergedData = mergeHistoricalData(historical);
        setChartData(mergedData);
      } catch (err) {
        setError(err.message);
        console.error('Error loading data:', err);
      } finally {
        setLoading(false);
      }
    }

    loadData();
  }, []);

  function mergeHistoricalData(historical) {
    const timeMap = new Map();

    for (const station of STATIONS) {
      const stationData = historical[station.id]?.data || [];

      for (const obs of stationData) {
        const time = obs.obsTimeLocal;
        if (!timeMap.has(time)) {
          timeMap.set(time, {
            time,
            timestamp: new Date(time).getTime()
          });
        }
        timeMap.get(time)[station.id] = obs.imperial?.temp ?? obs.metric?.temp;
      }
    }

    return Array.from(timeMap.values())
      .sort((a, b) => a.timestamp - b.timestamp);
  }

  function formatXAxis(timeStr) {
    const date = new Date(timeStr);
    return `${date.getMonth() + 1}/${date.getDate()} ${date.getHours()}:${String(date.getMinutes()).padStart(2, '0')}`;
  }

  if (loading) {
    return (
      <div className="app">
        <div className="loading">Loading weather data...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="app">
        <div className="error">Error: {error}</div>
      </div>
    );
  }

  return (
    <div className="app">
      <h1>Weather Station Temperatures</h1>

      <div className="current-temps">
        {STATIONS.map((station) => {
          const data = currentConditions[station.id];
          const temp = data?.data?.imperial?.temp;
          const obsTime = data?.data?.obsTimeLocal;

          return (
            <div key={station.id} className="temp-card">
              <h2>{station.name}</h2>
              <p className="station-id">{station.id}</p>
              {temp !== undefined ? (
                <>
                  <p className="temperature">{temp}°F</p>
                  <p className="obs-time">
                    {obsTime ? new Date(obsTime).toLocaleString() : 'N/A'}
                  </p>
                </>
              ) : (
                <p className="no-data">No data available</p>
              )}
            </div>
          );
        })}
      </div>

      <div className="chart-container">
        <h2>Temperature History (Last 3 Days)</h2>
        {chartData.length > 0 ? (
          <ResponsiveContainer width="100%" height={400}>
            <LineChart data={chartData} margin={{ top: 20, right: 30, left: 20, bottom: 20 }}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis
                dataKey="time"
                tickFormatter={formatXAxis}
                angle={-45}
                textAnchor="end"
                height={80}
                interval="preserveStartEnd"
              />
              <YAxis
                label={{ value: 'Temperature (°F)', angle: -90, position: 'insideLeft' }}
                domain={['auto', 'auto']}
              />
              <Tooltip
                labelFormatter={(label) => new Date(label).toLocaleString()}
                formatter={(value, name) => {
                  const station = STATIONS.find(s => s.id === name);
                  return [`${value}°F`, station?.name || name];
                }}
              />
              <Legend
                formatter={(value) => {
                  const station = STATIONS.find(s => s.id === value);
                  return station?.name || value;
                }}
              />
              <Line
                type="monotone"
                dataKey="KMAWEBST38"
                stroke="#2196F3"
                strokeWidth={2}
                dot={false}
                connectNulls
              />
              <Line
                type="monotone"
                dataKey="KMAWEBST37"
                stroke="#FF5722"
                strokeWidth={2}
                dot={false}
                connectNulls
              />
            </LineChart>
          </ResponsiveContainer>
        ) : (
          <p className="no-data">No historical data available</p>
        )}
      </div>
    </div>
  );
}

export default App;
