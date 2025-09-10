import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../models/channel.dart';
import '../services/auth_service.dart';
import '../services/websocket_service.dart';
import '../utils/constants.dart';

class ChannelList extends StatefulWidget {
  const ChannelList({Key? key}) : super(key: key);

  @override
  State<ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends State<ChannelList> {
  List<Channel> _channels = [];
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final response = await http.get(
        Uri.parse('${Constants.currentApiBaseUrl}/channels'),
        headers: authService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final channelsData = data['channels'] as List;
        
        setState(() {
          _channels = channelsData.map((ch) => Channel.fromJson(ch)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load channels';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _joinChannel(Channel channel) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final websocketService = Provider.of<WebSocketService>(context, listen: false);
      
      // First join via API
      final response = await http.post(
        Uri.parse('${Constants.currentApiBaseUrl}/channels/${channel.id}/join'),
        headers: authService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        // Then join via WebSocket
        websocketService.joinChannel(channel.id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined ${channel.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to join channel');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join channel: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _leaveChannel() async {
    try {
      final websocketService = Provider.of<WebSocketService>(context, listen: false);
      final currentChannel = websocketService.currentChannel;
      
      if (currentChannel == null) return;
      
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // First leave via WebSocket
      websocketService.leaveChannel();
      
      // Then leave via API
      final response = await http.post(
        Uri.parse('${Constants.currentApiBaseUrl}/channels/${currentChannel.id}/leave'),
        headers: authService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Left ${currentChannel.name}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to leave channel: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  List<Channel> get _filteredChannels {
    if (_searchController.text.isEmpty) {
      return _channels;
    }
    
    final query = _searchController.text.toLowerCase();
    return _channels.where((channel) {
      return channel.name.toLowerCase().contains(query) ||
             (channel.description?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(Constants.defaultPadding),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search channels',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        
        // Current channel info
        Consumer<WebSocketService>(
          builder: (context, websocketService, _) {
            final currentChannel = websocketService.currentChannel;
            
            if (currentChannel != null) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: Constants.defaultPadding),
                padding: const EdgeInsets.all(Constants.defaultPadding),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(Constants.defaultBorderRadius),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: Constants.smallPadding),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Channel',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            currentChannel.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _leaveChannel,
                      child: const Text('Leave'),
                    ),
                  ],
                ),
              );
            }
            
            return const SizedBox.shrink();
          },
        ),
        
        // Channels list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: Constants.defaultPadding),
                          Text(
                            _errorMessage!,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: Constants.defaultPadding),
                          ElevatedButton(
                            onPressed: _loadChannels,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadChannels,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(Constants.defaultPadding),
                        itemCount: _filteredChannels.length,
                        itemBuilder: (context, index) {
                          final channel = _filteredChannels[index];
                          
                          return Consumer<WebSocketService>(
                            builder: (context, websocketService, _) {
                              final isCurrentChannel = websocketService.currentChannel?.id == channel.id;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: Constants.smallPadding),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isCurrentChannel
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.surfaceVariant,
                                    child: Icon(
                                      isCurrentChannel ? Icons.chat : Icons.chat_outlined,
                                      color: isCurrentChannel
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  title: Text(
                                    channel.name,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: isCurrentChannel ? FontWeight.bold : null,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (channel.description != null && channel.description!.isNotEmpty)
                                        Text(channel.description!),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.people,
                                            size: 16,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${channel.onlineUsers ?? 0}/${channel.memberCount} online',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: isCurrentChannel
                                      ? Icon(
                                          Icons.check_circle,
                                          color: Theme.of(context).colorScheme.primary,
                                        )
                                      : const Icon(Icons.arrow_forward_ios),
                                  onTap: isCurrentChannel ? null : () => _joinChannel(channel),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
