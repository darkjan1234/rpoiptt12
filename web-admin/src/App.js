import React, { useState, useEffect } from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { Box } from '@mui/material';

import Navbar from './components/Navbar';
import Sidebar from './components/Sidebar';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import UsersPage from './pages/UsersPage';
import ChannelsPage from './pages/ChannelsPage';
import AnalyticsPage from './pages/AnalyticsPage';

import { AuthProvider, useAuth } from './hooks/useAuth';
import { WebSocketProvider } from './hooks/useWebSocket';

const DRAWER_WIDTH = 240;

function AppContent() {
  const { isAuthenticated, loading } = useAuth();
  const [mobileOpen, setMobileOpen] = useState(false);

  const handleDrawerToggle = () => {
    setMobileOpen(!mobileOpen);
  };

  if (loading) {
    return (
      <Box
        display="flex"
        justifyContent="center"
        alignItems="center"
        minHeight="100vh"
      >
        Loading...
      </Box>
    );
  }

  if (!isAuthenticated) {
    return <LoginPage />;
  }

  return (
    <WebSocketProvider>
      <Box sx={{ display: 'flex' }}>
        <Navbar 
          drawerWidth={DRAWER_WIDTH}
          handleDrawerToggle={handleDrawerToggle}
        />
        
        <Sidebar
          drawerWidth={DRAWER_WIDTH}
          mobileOpen={mobileOpen}
          handleDrawerToggle={handleDrawerToggle}
        />
        
        <Box
          component="main"
          sx={{
            flexGrow: 1,
            p: 3,
            width: { sm: `calc(100% - ${DRAWER_WIDTH}px)` },
            mt: 8, // Account for AppBar height
          }}
        >
          <Routes>
            <Route path="/" element={<Navigate to="/dashboard" replace />} />
            <Route path="/dashboard" element={<DashboardPage />} />
            <Route path="/users" element={<UsersPage />} />
            <Route path="/channels" element={<ChannelsPage />} />
            <Route path="/analytics" element={<AnalyticsPage />} />
            <Route path="*" element={<Navigate to="/dashboard" replace />} />
          </Routes>
        </Box>
      </Box>
    </WebSocketProvider>
  );
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}

export default App;
