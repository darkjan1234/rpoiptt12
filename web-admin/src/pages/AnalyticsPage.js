import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Grid,
  Card,
  CardContent,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Alert,
} from '@mui/material';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  PieChart,
  Pie,
  Cell,
  LineChart,
  Line,
  ResponsiveContainer,
} from 'recharts';

import axios from 'axios';
import { format, subDays, startOfDay } from 'date-fns';

const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884D8'];

const AnalyticsPage = () => {
  const [timeRange, setTimeRange] = useState('7d');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [analytics, setAnalytics] = useState({
    userTalkTime: [],
    channelUsage: [],
    dailyActivity: [],
    totalStats: {
      totalTalkTime: 0,
      totalSessions: 0,
      averageSessionLength: 0,
      activeUsers: 0,
    },
  });

  // Fetch analytics data
  const fetchAnalytics = async () => {
    setLoading(true);
    setError('');
    
    try {
      // Since we don't have a dedicated analytics endpoint, 
      // we'll simulate analytics data based on activity logs
      const [usersResponse, channelsResponse] = await Promise.all([
        axios.get('/api/users'),
        axios.get('/api/channels'),
      ]);

      // Simulate analytics data
      const users = usersResponse.data.users || [];
      const channels = channelsResponse.data.channels || [];

      // Generate mock user talk time data
      const userTalkTime = users.slice(0, 10).map((user, index) => ({
        username: user.username,
        talkTime: Math.floor(Math.random() * 3600) + 300, // 5 minutes to 1 hour
        sessions: Math.floor(Math.random() * 50) + 5,
      }));

      // Generate mock channel usage data
      const channelUsage = channels.slice(0, 8).map((channel, index) => ({
        name: channel.name,
        usage: Math.floor(Math.random() * 100) + 10,
        members: channel.member_count || 0,
      }));

      // Generate mock daily activity data
      const dailyActivity = Array.from({ length: 7 }, (_, index) => {
        const date = subDays(new Date(), 6 - index);
        return {
          date: format(date, 'MMM dd'),
          sessions: Math.floor(Math.random() * 100) + 20,
          talkTime: Math.floor(Math.random() * 7200) + 1800, // 30 minutes to 2 hours
          users: Math.floor(Math.random() * 30) + 10,
        };
      });

      // Calculate total stats
      const totalTalkTime = userTalkTime.reduce((sum, user) => sum + user.talkTime, 0);
      const totalSessions = userTalkTime.reduce((sum, user) => sum + user.sessions, 0);
      const averageSessionLength = totalSessions > 0 ? totalTalkTime / totalSessions : 0;

      setAnalytics({
        userTalkTime,
        channelUsage,
        dailyActivity,
        totalStats: {
          totalTalkTime,
          totalSessions,
          averageSessionLength,
          activeUsers: users.filter(u => u.is_active).length,
        },
      });

    } catch (error) {
      console.error('Failed to fetch analytics:', error);
      setError('Failed to load analytics data');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAnalytics();
  }, [timeRange]);

  const formatTime = (seconds) => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    }
    return `${minutes}m`;
  };

  const formatTalkTime = (seconds) => {
    return formatTime(seconds);
  };

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4">
          Analytics
        </Typography>
        
        <FormControl sx={{ minWidth: 120 }}>
          <InputLabel>Time Range</InputLabel>
          <Select
            value={timeRange}
            label="Time Range"
            onChange={(e) => setTimeRange(e.target.value)}
          >
            <MenuItem value="1d">Last 24 Hours</MenuItem>
            <MenuItem value="7d">Last 7 Days</MenuItem>
            <MenuItem value="30d">Last 30 Days</MenuItem>
            <MenuItem value="90d">Last 90 Days</MenuItem>
          </Select>
        </FormControl>
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}

      {/* Summary Stats */}
      <Grid container spacing={3} sx={{ mb: 3 }}>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography color="text.secondary" gutterBottom>
                Total Talk Time
              </Typography>
              <Typography variant="h4">
                {formatTalkTime(analytics.totalStats.totalTalkTime)}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography color="text.secondary" gutterBottom>
                Total Sessions
              </Typography>
              <Typography variant="h4">
                {analytics.totalStats.totalSessions}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography color="text.secondary" gutterBottom>
                Avg Session Length
              </Typography>
              <Typography variant="h4">
                {formatTalkTime(analytics.totalStats.averageSessionLength)}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography color="text.secondary" gutterBottom>
                Active Users
              </Typography>
              <Typography variant="h4">
                {analytics.totalStats.activeUsers}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Charts */}
      <Grid container spacing={3}>
        {/* Daily Activity */}
        <Grid item xs={12} lg={8}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Daily Activity
              </Typography>
              <ResponsiveContainer width="100%" height={300}>
                <LineChart data={analytics.dailyActivity}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="date" />
                  <YAxis />
                  <Tooltip />
                  <Legend />
                  <Line type="monotone" dataKey="sessions" stroke="#8884d8" name="Sessions" />
                  <Line type="monotone" dataKey="users" stroke="#82ca9d" name="Active Users" />
                </LineChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </Grid>

        {/* Channel Usage */}
        <Grid item xs={12} lg={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Channel Usage
              </Typography>
              <ResponsiveContainer width="100%" height={300}>
                <PieChart>
                  <Pie
                    data={analytics.channelUsage}
                    cx="50%"
                    cy="50%"
                    labelLine={false}
                    label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                    outerRadius={80}
                    fill="#8884d8"
                    dataKey="usage"
                  >
                    {analytics.channelUsage.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </Grid>

        {/* User Talk Time */}
        <Grid item xs={12}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Top Users by Talk Time
              </Typography>
              <ResponsiveContainer width="100%" height={400}>
                <BarChart data={analytics.userTalkTime}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="username" />
                  <YAxis tickFormatter={formatTalkTime} />
                  <Tooltip formatter={(value) => [formatTalkTime(value), 'Talk Time']} />
                  <Legend />
                  <Bar dataKey="talkTime" fill="#8884d8" name="Talk Time (seconds)" />
                </BarChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
};

export default AnalyticsPage;
