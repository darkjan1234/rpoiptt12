import React, { createContext, useContext, useState, useEffect } from 'react';
import axios from 'axios';

const AuthContext = createContext();

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [accessToken, setAccessToken] = useState(localStorage.getItem('access_token'));

  // Setup axios interceptors
  useEffect(() => {
    // Request interceptor to add auth header
    const requestInterceptor = axios.interceptors.request.use(
      (config) => {
        if (accessToken) {
          config.headers.Authorization = `Bearer ${accessToken}`;
        }
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor to handle token expiration
    const responseInterceptor = axios.interceptors.response.use(
      (response) => response,
      async (error) => {
        if (error.response?.status === 401 && accessToken) {
          // Token expired, try to refresh
          try {
            const refreshToken = localStorage.getItem('refresh_token');
            if (refreshToken) {
              const response = await axios.post('/api/auth/refresh', {}, {
                headers: { Authorization: `Bearer ${refreshToken}` }
              });
              
              const newAccessToken = response.data.access_token;
              setAccessToken(newAccessToken);
              localStorage.setItem('access_token', newAccessToken);
              
              // Retry the original request
              error.config.headers.Authorization = `Bearer ${newAccessToken}`;
              return axios.request(error.config);
            }
          } catch (refreshError) {
            // Refresh failed, logout user
            logout();
          }
        }
        return Promise.reject(error);
      }
    );

    return () => {
      axios.interceptors.request.eject(requestInterceptor);
      axios.interceptors.response.eject(responseInterceptor);
    };
  }, [accessToken]);

  // Check if user is authenticated on mount
  useEffect(() => {
    const checkAuth = async () => {
      if (accessToken) {
        try {
          const response = await axios.get('/api/auth/me');
          setUser(response.data.user);
        } catch (error) {
          console.error('Auth check failed:', error);
          logout();
        }
      }
      setLoading(false);
    };

    checkAuth();
  }, [accessToken]);

  const login = async (username, password) => {
    try {
      const response = await axios.post('/api/auth/login', {
        username,
        password,
      });

      const { access_token, refresh_token, user } = response.data;
      
      setAccessToken(access_token);
      setUser(user);
      
      localStorage.setItem('access_token', access_token);
      localStorage.setItem('refresh_token', refresh_token);
      
      return { success: true };
    } catch (error) {
      console.error('Login failed:', error);
      return {
        success: false,
        error: error.response?.data?.error || 'Login failed',
      };
    }
  };

  const logout = () => {
    setUser(null);
    setAccessToken(null);
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    
    // Call logout endpoint
    if (accessToken) {
      axios.post('/api/auth/logout').catch(console.error);
    }
  };

  const value = {
    user,
    accessToken,
    isAuthenticated: !!user,
    loading,
    login,
    logout,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};
