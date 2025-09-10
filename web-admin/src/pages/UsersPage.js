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
  FormControlLabel,
  Switch,
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
  AdminPanelSettings,
  Person,
  CheckCircle,
  Cancel,
} from '@mui/icons-material';

import axios from 'axios';
import { format } from 'date-fns';

const UsersPage = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [formData, setFormData] = useState({
    username: '',
    email: '',
    password: '',
    is_admin: false,
    is_active: true,
  });
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Fetch users
  const fetchUsers = async () => {
    setLoading(true);
    try {
      const response = await axios.get('/api/users');
      setUsers(response.data.users || []);
    } catch (error) {
      console.error('Failed to fetch users:', error);
      setError('Failed to load users');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, []);

  // Handle form submission
  const handleSubmit = async () => {
    try {
      setError('');
      
      if (editingUser) {
        // Update user
        await axios.put(`/api/users/${editingUser.id}`, formData);
        setSuccess('User updated successfully');
      } else {
        // Create user
        await axios.post('/api/users', formData);
        setSuccess('User created successfully');
      }
      
      setDialogOpen(false);
      setEditingUser(null);
      setFormData({
        username: '',
        email: '',
        password: '',
        is_admin: false,
        is_active: true,
      });
      fetchUsers();
    } catch (error) {
      setError(error.response?.data?.error || 'Operation failed');
    }
  };

  // Handle edit
  const handleEdit = (user) => {
    setEditingUser(user);
    setFormData({
      username: user.username,
      email: user.email || '',
      password: '', // Don't pre-fill password
      is_admin: user.is_admin,
      is_active: user.is_active,
    });
    setDialogOpen(true);
  };

  // Handle delete (deactivate)
  const handleDelete = async (userId) => {
    if (window.confirm('Are you sure you want to deactivate this user?')) {
      try {
        await axios.delete(`/api/users/${userId}`);
        setSuccess('User deactivated successfully');
        fetchUsers();
      } catch (error) {
        setError(error.response?.data?.error || 'Failed to deactivate user');
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
      field: 'username',
      headerName: 'Username',
      width: 150,
      renderCell: (params) => (
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <Person fontSize="small" />
          {params.value}
        </Box>
      ),
    },
    {
      field: 'email',
      headerName: 'Email',
      width: 200,
    },
    {
      field: 'is_admin',
      headerName: 'Role',
      width: 120,
      renderCell: (params) => (
        <Chip
          icon={params.value ? <AdminPanelSettings /> : <Person />}
          label={params.value ? 'Admin' : 'User'}
          color={params.value ? 'primary' : 'default'}
          size="small"
        />
      ),
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
      field: 'last_seen',
      headerName: 'Last Seen',
      width: 150,
      renderCell: (params) => (
        params.value ? format(new Date(params.value), 'MMM dd, yyyy') : 'Never'
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
          Users Management
        </Typography>
        
        <Button
          variant="contained"
          startIcon={<Add />}
          onClick={() => {
            setEditingUser(null);
            setFormData({
              username: '',
              email: '',
              password: '',
              is_admin: false,
              is_active: true,
            });
            setDialogOpen(true);
          }}
        >
          Add User
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
          rows={users}
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

      {/* User Dialog */}
      <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          {editingUser ? 'Edit User' : 'Add New User'}
        </DialogTitle>

        <DialogContent>
          <Box sx={{ pt: 1 }}>
            <TextField
              fullWidth
              label="Username"
              value={formData.username}
              onChange={(e) => setFormData({ ...formData, username: e.target.value })}
              margin="normal"
              required
            />

            <TextField
              fullWidth
              label="Email"
              type="email"
              value={formData.email}
              onChange={(e) => setFormData({ ...formData, email: e.target.value })}
              margin="normal"
            />

            <TextField
              fullWidth
              label={editingUser ? 'New Password (leave blank to keep current)' : 'Password'}
              type="password"
              value={formData.password}
              onChange={(e) => setFormData({ ...formData, password: e.target.value })}
              margin="normal"
              required={!editingUser}
            />

            <FormControlLabel
              control={
                <Switch
                  checked={formData.is_admin}
                  onChange={(e) => setFormData({ ...formData, is_admin: e.target.checked })}
                />
              }
              label="Administrator"
              sx={{ mt: 2 }}
            />

            <FormControlLabel
              control={
                <Switch
                  checked={formData.is_active}
                  onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
                />
              }
              label="Active"
              sx={{ mt: 1 }}
            />
          </Box>
        </DialogContent>

        <DialogActions>
          <Button onClick={() => setDialogOpen(false)}>
            Cancel
          </Button>
          <Button onClick={handleSubmit} variant="contained">
            {editingUser ? 'Update' : 'Create'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default UsersPage;
