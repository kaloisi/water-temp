import { useState, useEffect, useCallback } from 'react';
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
import { fetchAllCurrentConditions, fetchLastNDaysData, STATIONS } from './weatherService';
import './App.css';

const AUTO_REFRESH_INTERVAL = 5 * 60 * 1000; // 5 minutes

function App() {
  const [currentConditions, setCurrentConditions] = useState({});
  const [chartData, setChartData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingChart, setLoadingChart] = useState(false);
  const [error, setError] = useState(null);
  const [lastUpdated, setLastUpdated] = useState(null);
  const [selectedDays, setSelectedDays] = useState(3);

  const loadData = useCallback(async (isManualRefresh = false, days = 3) => {
    try {
      if (isManualRefresh) {
        setRefreshing(true);
        setError(null);

        // Fetch current conditions and today's data to append new samples
        const [current, todayData] = await Promise.all([
          fetchAllCurrentConditions(),
          fetchLastNDaysData(1)
        ]);
        setCurrentConditions(current);

        // Merge new samples into existing chart data
        const newSamples = mergeHistoricalData(todayData);
        setChartData(prevData => {
          const timeMap = new Map();
          for (const point of prevData) {
            timeMap.set(point.time, point);
          }
          for (const point of newSamples) {
            timeMap.set(point.time, point);
          }
          return Array.from(timeMap.values()).sort((a, b) => a.timestamp - b.timestamp);
        });

        setLastUpdated(new Date());
      } else {
        setLoading(true);
        setError(null);

        const [current, historical] = await Promise.all([
          fetchAllCurrentConditions(),
          fetchLastNDaysData(days)
        ]);

        setCurrentConditions(current);

        const mergedData = mergeHistoricalData(historical);
        setChartData(mergedData);
        setLastUpdated(new Date());
      }
    } catch (err) {
      setError(err.message);
      console.error('Error loading data:', err);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    loadData();

    // Set up auto-refresh
    const intervalId = setInterval(() => {
      loadData(true);
    }, AUTO_REFRESH_INTERVAL);

    return () => clearInterval(intervalId);
  }, [loadData]);

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
        // Historical API returns tempAvg directly on the observation for imperial units
        const temp = obs.tempAvg ?? obs.imperial?.tempAvg ?? obs.imperial?.temp ?? obs.metric?.tempAvg;
        if (temp !== undefined && temp !== null) {
          timeMap.get(time)[station.id] = temp;
        }
      }
    }

    return Array.from(timeMap.values())
      .sort((a, b) => a.timestamp - b.timestamp);
  }

  function formatXAxis(timeStr) {
    const date = new Date(timeStr);
    return `${date.getMonth() + 1}/${date.getDate()} ${date.getHours()}:${String(date.getMinutes()).padStart(2, '0')}`;
  }

  function handleRefresh() {
    loadData(true);
  }

  async function handleDaysChange(event) {
    const days = parseInt(event.target.value, 10);
    setSelectedDays(days);

    try {
      setLoadingChart(true);
      const historical = await fetchLastNDaysData(days);
      const mergedData = mergeHistoricalData(historical);
      setChartData(mergedData);
    } catch (err) {
      console.error('Error fetching historical data:', err);
    } finally {
      setLoadingChart(false);
    }
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
        <button className="refresh-button" onClick={handleRefresh}>
          Try Again
        </button>
      </div>
    );
  }

  return (
    <div className="app">
      <header className="header">
        <h1>Weather Station Temperatures</h1>
        <div className="refresh-section">
          <button
            className="refresh-button"
            onClick={handleRefresh}
            disabled={refreshing || loadingChart}
          >
            {refreshing ? 'Refreshing...' : 'Refresh'}
          </button>
          {lastUpdated && (
            <span className="last-updated">
              Last updated: {lastUpdated.toLocaleTimeString()}
            </span>
          )}
        </div>
      </header>

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
                  <p className="temperature">{temp.toFixed(1)}°F</p>
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
        <div className="chart-header">
          <h2>Temperature History</h2>
          <select
            className="days-select"
            value={selectedDays}
            onChange={handleDaysChange}
            disabled={refreshing || loadingChart}
          >
            <option value={3}>3 days</option>
            <option value={7}>7 days</option>
            <option value={14}>14 days</option>
            <option value={28}>28 days</option>
            <option value={45}>45 days</option>
          </select>
          {loadingChart && <span className="loading-indicator">Loading...</span>}
        </div>
        {chartData.length > 0 ? (
          <ResponsiveContainer width="100%" height={400}>
            <LineChart data={chartData} margin={{ top: 20, right: 30, left: 20, bottom: 20 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#334" />
              <XAxis
                dataKey="time"
                tickFormatter={formatXAxis}
                angle={-45}
                textAnchor="end"
                height={80}
                interval="preserveStartEnd"
                stroke="#888"
                tick={{ fill: '#aaa' }}
              />
              <YAxis
                label={{ value: 'Temperature (°F)', angle: -90, position: 'insideLeft', fill: '#aaa' }}
                domain={['auto', 'auto']}
                stroke="#888"
                tick={{ fill: '#aaa' }}
              />
              <Tooltip
                labelFormatter={(label) => new Date(label).toLocaleString()}
                formatter={(value, name) => {
                  const station = STATIONS.find(s => s.id === name);
                  return [`${Number(value).toFixed(1)}°F`, station?.name || name];
                }}
                contentStyle={{ backgroundColor: '#1a1a2e', border: '1px solid #334', color: '#eaeaea' }}
                labelStyle={{ color: '#eaeaea' }}
              />
              <Legend
                formatter={(value) => {
                  const station = STATIONS.find(s => s.id === value);
                  return station?.name || value;
                }}
                wrapperStyle={{ color: '#eaeaea' }}
              />
              <Line
                type="monotone"
                dataKey="KMAWEBST38"
                name="KMAWEBST38"
                stroke="#4ecca3"
                strokeWidth={2}
                dot={false}
                connectNulls
              />
              <Line
                type="monotone"
                dataKey="KMAWEBST37"
                name="KMAWEBST37"
                stroke="#ff6b6b"
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
