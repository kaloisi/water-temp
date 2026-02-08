import { useState, useEffect, useCallback } from 'react';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts';
import Box from '@mui/material/Box';
import Typography from '@mui/material/Typography';
import Button from '@mui/material/Button';
import Card from '@mui/material/Card';
import CardContent from '@mui/material/CardContent';
import Select, { SelectChangeEvent } from '@mui/material/Select';
import MenuItem from '@mui/material/MenuItem';
import CircularProgress from '@mui/material/CircularProgress';
import Alert from '@mui/material/Alert';
import Link from '@mui/material/Link';
import Container from '@mui/material/Container';
import Stack from '@mui/material/Stack';
import Grid from '@mui/material/Grid';
import RefreshIcon from '@mui/icons-material/Refresh';
import {
  fetchAllCurrentConditions,
  fetchLastNDaysData,
  STATIONS,
  WUNDERGROUND_DASHBOARD_URL,
  CurrentConditionsMap,
  HistoricalDataMap,
} from './weatherService';

const AUTO_REFRESH_INTERVAL = 5 * 60 * 1000;

interface ChartDataPoint {
  time: string;
  timestamp: number;
  [stationId: string]: string | number;
}

const STATION_COLORS: Record<string, string> = {
  KMAWEBST38: '#4ecca3',
  KMAWEBST37: '#ff6b6b',
};

function App() {
  const [currentConditions, setCurrentConditions] = useState<CurrentConditionsMap>({});
  const [chartData, setChartData] = useState<ChartDataPoint[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingChart, setLoadingChart] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);
  const [selectedDays, setSelectedDays] = useState(3);
  const [hiddenSeries, setHiddenSeries] = useState<Set<string>>(new Set());

  const loadData = useCallback(async (isManualRefresh = false, days = 3) => {
    try {
      if (isManualRefresh) {
        setRefreshing(true);
        setError(null);

        const [current, todayData] = await Promise.all([
          fetchAllCurrentConditions(),
          fetchLastNDaysData(1),
        ]);
        setCurrentConditions(current);

        const now = new Date();
        const currentTimeStr = now.toISOString();
        const currentSample: ChartDataPoint = {
          time: currentTimeStr,
          timestamp: now.getTime(),
        };
        for (const station of STATIONS) {
          const temp = current[station.id]?.data?.imperial?.temp;
          if (temp !== undefined && temp !== null) {
            currentSample[station.id] = temp;
          }
        }

        const newSamples = mergeHistoricalData(todayData);
        setChartData((prevData) => {
          const timeMap = new Map<string, ChartDataPoint>();
          for (const point of prevData) {
            timeMap.set(point.time, point);
          }
          for (const point of newSamples) {
            timeMap.set(point.time, point);
          }
          timeMap.set(currentTimeStr, currentSample);
          return Array.from(timeMap.values()).sort((a, b) => a.timestamp - b.timestamp);
        });

        setLastUpdated(now);
      } else {
        setLoading(true);
        setError(null);

        const [current, historical] = await Promise.all([
          fetchAllCurrentConditions(),
          fetchLastNDaysData(days),
        ]);

        setCurrentConditions(current);

        const mergedData = mergeHistoricalData(historical);
        setChartData(mergedData);
        setLastUpdated(new Date());
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      console.error('Error loading data:', err);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    loadData();

    const intervalId = setInterval(() => {
      loadData(true);
    }, AUTO_REFRESH_INTERVAL);

    return () => clearInterval(intervalId);
  }, [loadData]);

  function mergeHistoricalData(historical: HistoricalDataMap): ChartDataPoint[] {
    const timeMap = new Map<string, ChartDataPoint>();

    for (const station of STATIONS) {
      const stationData = historical[station.id]?.data || [];

      for (const obs of stationData) {
        const time = obs.obsTimeLocal;
        if (!timeMap.has(time)) {
          timeMap.set(time, {
            time,
            timestamp: new Date(time).getTime(),
          });
        }
        const temp =
          obs.tempAvg ?? obs.imperial?.tempAvg ?? obs.imperial?.temp ?? obs.metric?.tempAvg;
        if (temp !== undefined && temp !== null) {
          timeMap.get(time)![station.id] = temp;
        }
      }
    }

    return Array.from(timeMap.values()).sort((a, b) => a.timestamp - b.timestamp);
  }

  function formatXAxis(timeStr: string): string {
    const date = new Date(timeStr);
    return `${date.getMonth() + 1}/${date.getDate()} ${date.getHours()}:${String(date.getMinutes()).padStart(2, '0')}`;
  }

  function handleRefresh() {
    loadData(true);
  }

  async function handleDaysChange(event: SelectChangeEvent<number>) {
    const days = Number(event.target.value);
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

  function handleLegendClick(dataKey: string) {
    setHiddenSeries((prev) => {
      const next = new Set(prev);
      if (next.has(dataKey)) {
        next.delete(dataKey);
      } else {
        next.add(dataKey);
      }
      return next;
    });
  }

  if (loading) {
    return (
      <Box
        sx={{
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          height: '100vh',
          flexDirection: 'column',
          gap: 2,
        }}
      >
        <CircularProgress />
        <Typography color="text.secondary">Loading weather data...</Typography>
      </Box>
    );
  }

  if (error) {
    return (
      <Container maxWidth="md" sx={{ mt: 8 }}>
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
        <Button variant="contained" onClick={handleRefresh} startIcon={<RefreshIcon />}>
          Try Again
        </Button>
      </Container>
    );
  }

  return (
    <Container maxWidth="lg" sx={{ py: 3 }}>
      <Box sx={{ textAlign: 'center', mb: 4 }}>
        <Typography variant="h4" component="h1" gutterBottom>
          Weather Station Temperatures
        </Typography>
        <Stack direction="row" spacing={2} justifyContent="center" alignItems="center">
          <Button
            variant="contained"
            onClick={handleRefresh}
            disabled={refreshing || loadingChart}
            startIcon={refreshing ? <CircularProgress size={16} color="inherit" /> : <RefreshIcon />}
          >
            {refreshing ? 'Refreshing...' : 'Refresh'}
          </Button>
          {lastUpdated && (
            <Typography variant="body2" color="text.secondary">
              Last updated: {lastUpdated.toLocaleTimeString()}
            </Typography>
          )}
        </Stack>
      </Box>

      <Grid container spacing={3} justifyContent="center" sx={{ mb: 5 }}>
        {STATIONS.map((station) => {
          const data = currentConditions[station.id];
          const temp = data?.data?.imperial?.temp;
          const obsTime = data?.data?.obsTimeLocal;

          return (
            <Grid key={station.id} size={{ xs: 12, sm: 6, md: 4 }}>
              <Card sx={{ textAlign: 'center' }}>
                <CardContent>
                  <Typography variant="h5" color="primary" sx={{ mb: 0.5 }}>
                    {station.name}
                  </Typography>
                  <Link
                    href={`${WUNDERGROUND_DASHBOARD_URL}${station.id}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    sx={{ fontSize: '0.85rem', opacity: 0.7 }}
                  >
                    {station.id}
                  </Link>
                  {temp !== undefined ? (
                    <>
                      <Typography
                        variant="h2"
                        color="success.main"
                        sx={{ fontWeight: 'bold', my: 1 }}
                      >
                        {temp.toFixed(1)}°F
                      </Typography>
                      <Typography variant="body2" color="text.secondary">
                        {obsTime ? new Date(obsTime).toLocaleString() : 'N/A'}
                      </Typography>
                    </>
                  ) : (
                    <Typography variant="body1" color="error" sx={{ fontStyle: 'italic', mt: 2 }}>
                      No data available
                    </Typography>
                  )}
                </CardContent>
              </Card>
            </Grid>
          );
        })}
      </Grid>

      <Card sx={{ p: 3 }}>
        <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 2 }}>
          <Typography variant="h5">Temperature History</Typography>
          <Stack direction="row" alignItems="center" spacing={1}>
            {loadingChart && <CircularProgress size={20} />}
            <Select<number>
              value={selectedDays}
              onChange={handleDaysChange}
              disabled={refreshing || loadingChart}
              size="small"
              sx={{ minWidth: 130 }}
            >
              <MenuItem value={1}>Current day</MenuItem>
              <MenuItem value={3}>3 days</MenuItem>
              <MenuItem value={7}>7 days</MenuItem>
              <MenuItem value={14}>14 days</MenuItem>
              <MenuItem value={28}>28 days</MenuItem>
              <MenuItem value={45}>45 days</MenuItem>
            </Select>
          </Stack>
        </Stack>

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
                label={{
                  value: 'Temperature (°F)',
                  angle: -90,
                  position: 'insideLeft',
                  fill: '#aaa',
                }}
                domain={['auto', 'auto']}
                stroke="#888"
                tick={{ fill: '#aaa' }}
              />
              <Tooltip
                labelFormatter={(label) => new Date(label).toLocaleString()}
                formatter={(value?: number, name?: string) => {
                  const station = STATIONS.find((s) => s.id === name);
                  return [`${Number(value ?? 0).toFixed(1)}°F`, station?.name || name || ''];
                }}
                contentStyle={{
                  backgroundColor: '#121212',
                  border: '1px solid #333',
                  color: '#fff',
                }}
                labelStyle={{ color: '#fff' }}
              />
              <Legend
                onClick={(e) => {
                  if (e && e.dataKey) {
                    handleLegendClick(e.dataKey as string);
                  }
                }}
                formatter={(value: string) => {
                  const station = STATIONS.find((s) => s.id === value);
                  const isHidden = hiddenSeries.has(value);
                  return (
                    <span style={{ color: isHidden ? '#666' : '#fff', cursor: 'pointer' }}>
                      {station?.name || value}
                    </span>
                  );
                }}
                wrapperStyle={{ cursor: 'pointer' }}
              />
              {STATIONS.map((station) => (
                <Line
                  key={station.id}
                  type="monotone"
                  dataKey={station.id}
                  name={station.id}
                  stroke={STATION_COLORS[station.id] || '#8884d8'}
                  strokeWidth={2}
                  dot={false}
                  connectNulls
                  hide={hiddenSeries.has(station.id)}
                />
              ))}
            </LineChart>
          </ResponsiveContainer>
        ) : (
          <Typography
            variant="body1"
            sx={{ textAlign: 'center', color: 'text.secondary', fontStyle: 'italic', py: 5 }}
          >
            No historical data available
          </Typography>
        )}
      </Card>
    </Container>
  );
}

export default App;
