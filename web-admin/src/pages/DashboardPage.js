import React, { useState, useEffect } from 'react';
import {
  Box,
  Grid,
  Card,
  CardContent,
  Typography,
  List,
  ListItem,
  ListItemText,
  ListItemIcon,
  Chip,
  Avatar,
  Paper,
  Divider,
} from '@mui/material';
import {
  People,
  Chat,
  Mic,
  MicOff,
  TrendingUp,
  AccessTime,
} from '@mui/icons-material';

import { useWebSocket } from '../hooks/useWebSocket';
import axios from 'axios';

const DashboardPage = () => {
  const { isConnected, onlineUsers, activeChannels, speakingUsers } = useWebSocket();
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalChannels: 0,
    activeUsers: 0,
    speakingUsers: 0,
  });
  const [recentActivity, setRecentActivity] = useState([]);

  // Fetch dashboard stats
  useEffect(() => {
    const fetchStats = async () => {
      try {
        const [usersResponse, channelsResponse] = await Promise.all([
          axios.get('/api/users'),
          axios.get('/api/channels'),
        ]);

        const activeUsersCount = onlineUsers.length;
        const speakingUsersCount = Object.values(speakingUsers).filter(Boolean).length;

        setStats({
          totalUsers: usersResponse.data.total || 0,
          totalChannels: channelsResponse.data.total || 0,
          activeUsers: activeUsersCount,
          speakingUsers: speakingUsersCount,
        });
      } catch (error) {
        console.error('Failed to fetch stats:', error);
      }
    };

    fetchStats();
    const interval = setInterval(fetchStats, 30000); // Refresh every 30 seconds

    return () => clearInterval(interval);
  }, [onlineUsers.length, speakingUsers]);

  // Update speaking users count when it changes
  useEffect(() => {
    const speakingUsersCount = Object.values(speakingUsers).filter(Boolean).length;
    setStats(prev => ({
      ...prev,
      speakingUsers: speakingUsersCount,
    }));
  }, [speakingUsers]);

  const StatCard = ({ title, value, icon, color = 'primary' }) => (
    <Card>
      <CardContent>
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <Box>
            <Typography color="text.secondary" gutterBottom variant="h6">
              {title}
            </Typography>
            <Typography variant="h4" component="div">
              {value}
            </Typography>
          </Box>
          <Avatar sx={{ bgcolor: `${color}.main`, width: 56, height: 56 }}>
            {icon}
          </Avatar>
        </Box>
      </CardContent>
    </Card>
  );

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Dashboard
      </Typography>

      {/* Connection Status */}
      <Paper sx={{ p: 2, mb: 3 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
          <Chip
            icon={isConnected ? <TrendingUp /> : <MicOff />}
            label={isConnected ? 'Real-time Connected' : 'Real-time Disconnected'}
            color={isConnected ? 'success' : 'error'}
          />
          <Typography variant="body2" color="text.secondary">
            {isConnected 
              ? 'Receiving live updates from the PTT system'
              : 'Not connected to real-time updates'
            }
          </Typography>
        </Box>
      </Paper>

      {/* Stats Cards */}
      <Grid container spacing={3} sx={{ mb: 3 }}>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Users"
            value={stats.totalUsers}
            icon={<People />}
            color="primary"
          />
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Channels"
            value={stats.totalChannels}
            icon={<Chat />}
            color="secondary"
          />
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Online Users"
            value={stats.activeUsers}
            icon={<TrendingUp />}
            color="success"
          />
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Speaking Now"
            value={stats.speakingUsers}
            icon={<Mic />}
            color="error"
          />
        </Grid>
      </Grid>

      <Grid container spacing={3}>
        {/* Online Users */}
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Online Users ({onlineUsers.length})
              </Typography>
              
              {onlineUsers.length === 0 ? (
                <Typography color="text.secondary">
                  No users currently online
                </Typography>
              ) : (
                <List dense>
                  {onlineUsers.slice(0, 10).map((user, index) => (
                    <ListItem key={`${user.user_id}-${user.channel_id}`}>
                      <ListItemIcon>
                        <Avatar sx={{ width: 32, height: 32 }}>
                          {user.username?.charAt(0).toUpperCase() || '?'}
                        </Avatar>
                      </ListItemIcon>
                      
                      <ListItemText
                        primary={
                          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                            <Typography variant="body2">
                              {user.username}
                            </Typography>
                            {user.is_speaking && (
                              <Chip
                                icon={<Mic />}
                                label="Speaking"
                                size="small"
                                color="error"
                                variant="outlined"
                              />
                            )}
                          </Box>
                        }
                        secondary={`Channel ID: ${user.channel_id || 'None'}`}
                      />
                    </ListItem>
                  ))}
                  
                  {onlineUsers.length > 10 && (
                    <ListItem>
                      <ListItemText
                        primary={
                          <Typography variant="body2" color="text.secondary">
                            ... and {onlineUsers.length - 10} more users
                          </Typography>
                        }
                      />
                    </ListItem>
                  )}
                </List>
              )}
            </CardContent>
          </Card>
        </Grid>

        {/* Active Channels */}
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Active Channels ({activeChannels.length})
              </Typography>
              
              {activeChannels.length === 0 ? (
                <Typography color="text.secondary">
                  No active channels
                </Typography>
              ) : (
                <List dense>
                  {activeChannels.map((channel) => {
                    const channelUsers = onlineUsers.filter(u => u.channel_id === channel.id);
                    const speakingInChannel = channelUsers.filter(u => u.is_speaking).length;
                    
                    return (
                      <ListItem key={channel.id}>
                        <ListItemIcon>
                          <Chat color="primary" />
                        </ListItemIcon>
                        
                        <ListItemText
                          primary={
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                              <Typography variant="body2">
                                {channel.name}
                              </Typography>
                              {speakingInChannel > 0 && (
                                <Chip
                                  icon={<Mic />}
                                  label={`${speakingInChannel} speaking`}
                                  size="small"
                                  color="error"
                                  variant="outlined"
                                />
                              )}
                            </Box>
                          }
                          secondary={`${channelUsers.length} users online`}
                        />
                      </ListItem>
                    );
                  })}
                </List>
              )}
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
};

export default DashboardPage;
