import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Alert,
  Chip,
  IconButton,
  Tooltip,
} from '@mui/material';
import { DataGrid } from '@mui/x-data-grid';
import {
  Add,
  Edit,
  Delete,
  Chat,
  People,
  CheckCircle,
  Cancel,
} from '@mui/icons-material';

import axios from 'axios';
import { format } from 'date-fns';

const ChannelsPage = () => {
  const [channels, setChannels] = useState([]);
  const [loading, setLoading] = useState(false);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingChannel, setEditingChannel] = useState(null);
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    max_users: 50,
  });
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Fetch channels
  const fetchChannels = async () => {
    setLoading(true);
    try {
      const response = await axios.get('/api/channels');
      setChannels(response.data.channels || []);
    } catch (error) {
      console.error('Failed to fetch channels:', error);
      setError('Failed to load channels');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchChannels();
  }, []);

  // Handle form submission
  const handleSubmit = async () => {
    try {
      setError('');
      
      if (editingChannel) {
        // Update channel
        await axios.put(`/api/channels/${editingChannel.id}`, formData);
        setSuccess('Channel updated successfully');
      } else {
        // Create channel
        await axios.post('/api/channels', formData);
        setSuccess('Channel created successfully');
      }
      
      setDialogOpen(false);
      setEditingChannel(null);
      setFormData({
        name: '',
        description: '',
        max_users: 50,
      });
      fetchChannels();
    } catch (error) {
      setError(error.response?.data?.error || 'Operation failed');
    }
  };

  // Handle edit
  const handleEdit = (channel) => {
    setEditingChannel(channel);
    setFormData({
      name: channel.name,
      description: channel.description || '',
      max_users: channel.max_users,
    });
    setDialogOpen(true);
  };

  // Handle delete (deactivate)
  const handleDelete = async (channelId) => {
    if (window.confirm('Are you sure you want to deactivate this channel?')) {
      try {
        await axios.delete(`/api/channels/${channelId}`);
        setSuccess('Channel deactivated successfully');
        fetchChannels();
      } catch (error) {
        setError(error.response?.data?.error || 'Failed to deactivate channel');
      }
    }
  };

  const columns = [
    {
      field: 'id',
      headerName: 'ID',
      width: 70,
    },
    {
      field: 'name',
      headerName: 'Channel Name',
      width: 200,
      renderCell: (params) => (
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <Chat fontSize="small" />
          {params.value}
        </Box>
      ),
    },
    {
      field: 'description',
      headerName: 'Description',
      width: 250,
      renderCell: (params) => (
        params.value || <em>No description</em>
      ),
    },
    {
      field: 'member_count',
      headerName: 'Members',
      width: 100,
      renderCell: (params) => (
        <Chip
          icon={<People />}
          label={params.value || 0}
          size="small"
          color="primary"
        />
      ),
    },
    {
      field: 'online_users',
      headerName: 'Online',
      width: 100,
      renderCell: (params) => (
        <Chip
          label={params.value || 0}
          size="small"
          color="success"
        />
      ),
    },
    {
      field: 'max_users',
      headerName: 'Max Users',
      width: 100,
    },
    {
      field: 'is_active',
      headerName: 'Status',
      width: 120,
      renderCell: (params) => (
        <Chip
          icon={params.value ? <CheckCircle /> : <Cancel />}
          label={params.value ? 'Active' : 'Inactive'}
          color={params.value ? 'success' : 'error'}
          size="small"
        />
      ),
    },
    {
      field: 'created_at',
      headerName: 'Created',
      width: 150,
      renderCell: (params) => (
        format(new Date(params.value), 'MMM dd, yyyy')
      ),
    },
    {
      field: 'actions',
      headerName: 'Actions',
      width: 120,
      sortable: false,
      renderCell: (params) => (
        <Box>
          <Tooltip title="Edit">
            <IconButton
              size="small"
              onClick={() => handleEdit(params.row)}
            >
              <Edit />
            </IconButton>
          </Tooltip>
          
          <Tooltip title="Deactivate">
            <IconButton
              size="small"
              onClick={() => handleDelete(params.row.id)}
              disabled={!params.row.is_active}
            >
              <Delete />
            </IconButton>
          </Tooltip>
        </Box>
      ),
    },
  ];

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4">
          Channels Management
        </Typography>
        
        <Button
          variant="contained"
          startIcon={<Add />}
          onClick={() => {
            setEditingChannel(null);
            setFormData({
              name: '',
              description: '',
              max_users: 50,
            });
            setDialogOpen(true);
          }}
        >
          Add Channel
        </Button>
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError('')}>
          {error}
        </Alert>
      )}

      {success && (
        <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSuccess('')}>
          {success}
        </Alert>
      )}

      <Box sx={{ height: 600, width: '100%' }}>
        <DataGrid
          rows={channels}
          columns={columns}
          pageSize={10}
          rowsPerPageOptions={[10, 25, 50]}
          loading={loading}
          disableSelectionOnClick
          sx={{
            '& .MuiDataGrid-cell:focus': {
              outline: 'none',
            },
          }}
        />
      </Box>

      {/* Channel Dialog */}
      <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          {editingChannel ? 'Edit Channel' : 'Add New Channel'}
        </DialogTitle>
        
        <DialogContent>
          <Box sx={{ pt: 1 }}>
            <TextField
              fullWidth
              label="Channel Name"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              margin="normal"
              required
            />
            
            <TextField
              fullWidth
              label="Description"
              multiline
              rows={3}
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              margin="normal"
            />
            
            <TextField
              fullWidth
              label="Maximum Users"
              type="number"
              value={formData.max_users}
              onChange={(e) => setFormData({ ...formData, max_users: parseInt(e.target.value) || 50 })}
              margin="normal"
              inputProps={{ min: 1, max: 1000 }}
            />
          </Box>
        </DialogContent>
        
        <DialogActions>
          <Button onClick={() => setDialogOpen(false)}>
            Cancel
          </Button>
          <Button onClick={handleSubmit} variant="contained">
            {editingChannel ? 'Update' : 'Create'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default ChannelsPage;
