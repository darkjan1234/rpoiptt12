import React, { createContext, useContext, useState, useEffect, useRef } from 'react';
import { io } from 'socket.io-client';
import { useAuth } from './useAuth';

const WebSocketContext = createContext();

export const useWebSocket = () => {
  const context = useContext(WebSocketContext);
  if (!context) {
    throw new Error('useWebSocket must be used within a WebSocketProvider');
  }
  return context;
};

export const WebSocketProvider = ({ children }) => {
  const { accessToken, isAuthenticated } = useAuth();
  const [isConnected, setIsConnected] = useState(false);
  const [onlineUsers, setOnlineUsers] = useState([]);
  const [activeChannels, setActiveChannels] = useState([]);
  const [speakingUsers, setSpeakingUsers] = useState({});
  const socketRef = useRef(null);

  // Connect to WebSocket
  useEffect(() => {
    if (isAuthenticated && accessToken && !socketRef.current) {
      const wsUrl = process.env.NODE_ENV === 'production' 
        ? 'wss://yourdomain.com/api/ws'
        : 'ws://localhost:5000/api/ws';

      socketRef.current = io(wsUrl, {
        auth: {
          token: accessToken,
        },
        transports: ['websocket'],
      });

      const socket = socketRef.current;

      socket.on('connect', () => {
        console.log('Connected to WebSocket');
        setIsConnected(true);
      });

      socket.on('disconnect', () => {
        console.log('Disconnected from WebSocket');
        setIsConnected(false);
      });

      socket.on('connect_error', (error) => {
        console.error('WebSocket connection error:', error);
        setIsConnected(false);
      });

      // Listen for real-time updates
      socket.on('user_joined', (data) => {
        console.log('User joined:', data);
        // Update online users list
        setOnlineUsers(prev => {
          const exists = prev.find(u => u.user_id === data.user.id);
          if (!exists) {
            return [...prev, {
              user_id: data.user.id,
              username: data.user.username,
              channel_id: data.channel_id,
              is_speaking: false,
              joined_at: new Date().toISOString(),
            }];
          }
          return prev;
        });
      });

      socket.on('user_left', (data) => {
        console.log('User left:', data);
        setOnlineUsers(prev => 
          prev.filter(u => !(u.user_id === data.user.id && u.channel_id === data.channel_id))
        );
      });

      socket.on('user_speaking', (data) => {
        console.log('User speaking status changed:', data);
        setSpeakingUsers(prev => ({
          ...prev,
          [data.user_id]: data.is_speaking,
        }));

        // Update online users speaking status
        setOnlineUsers(prev => 
          prev.map(user => 
            user.user_id === data.user_id 
              ? { ...user, is_speaking: data.is_speaking }
              : user
          )
        );
      });

      // Listen for channel updates
      socket.on('channel_state', (data) => {
        console.log('Channel state updated:', data);
        const channelData = data.channel;
        setActiveChannels(prev => {
          const exists = prev.find(c => c.id === channelData.id);
          if (exists) {
            return prev.map(c => c.id === channelData.id ? channelData : c);
          } else {
            return [...prev, channelData];
          }
        });
      });

      return () => {
        socket.disconnect();
      };
    }

    return () => {
      if (socketRef.current) {
        socketRef.current.disconnect();
        socketRef.current = null;
        setIsConnected(false);
      }
    };
  }, [isAuthenticated, accessToken]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (socketRef.current) {
        socketRef.current.disconnect();
      }
    };
  }, []);

  const value = {
    isConnected,
    onlineUsers,
    activeChannels,
    speakingUsers,
    socket: socketRef.current,
  };

  return (
    <WebSocketContext.Provider value={value}>
      {children}
    </WebSocketContext.Provider>
  );
};
