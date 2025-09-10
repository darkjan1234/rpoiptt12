import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/channel.dart';
import '../services/websocket_service.dart';
import '../utils/constants.dart';

class OnlineUsersList extends StatelessWidget {
  const OnlineUsersList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WebSocketService>(
      builder: (context, websocketService, _) {
        final currentChannel = websocketService.currentChannel;
        final onlineUsers = websocketService.onlineUsers;
        final speakingUsers = websocketService.speakingUsers;
        
        if (currentChannel == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: Constants.defaultPadding),
                Text(
                  'Join a channel to see online users',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        return Column(
          children: [
            // Channel header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Constants.defaultPadding),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.chat,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: Constants.smallPadding),
                      Expanded(
                        child: Text(
                          currentChannel.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  
                  if (currentChannel.description != null && 
                      currentChannel.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: Constants.smallPadding),
                      child: Text(
                        currentChannel.description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  
                  const SizedBox(height: Constants.smallPadding),
                  
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${onlineUsers.length} online',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: Constants.defaultPadding),
                      Icon(
                        Icons.mic,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${speakingUsers.values.where((speaking) => speaking).length} speaking',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Users list
            Expanded(
              child: onlineUsers.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: Constants.defaultPadding),
                          Text(
                            'No users online',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(Constants.defaultPadding),
                      itemCount: onlineUsers.length,
                      itemBuilder: (context, index) {
                        final onlineUser = onlineUsers[index];
                        final user = onlineUser.user;
                        final isSpeaking = speakingUsers[onlineUser.userId] ?? false;
                        
                        if (user == null) {
                          return const SizedBox.shrink();
                        }
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: Constants.smallPadding),
                          child: ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isSpeaking
                                      ? Colors.red
                                      : Theme.of(context).colorScheme.primary,
                                  child: Text(
                                    user.username.isNotEmpty
                                        ? user.username[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                
                                // Speaking indicator
                                if (isSpeaking)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Theme.of(context).cardColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.mic,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    user.username,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: isSpeaking ? FontWeight.bold : null,
                                    ),
                                  ),
                                ),
                                
                                if (user.isAdmin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'ADMIN',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isSpeaking)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.mic,
                                        size: 16,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Speaking...',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatJoinTime(onlineUser.joinedAt),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            
                            trailing: isSpeaking
                                ? AnimatedContainer(
                                    duration: const Duration(milliseconds: 500),
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
  
  String _formatJoinTime(DateTime joinTime) {
    final now = DateTime.now();
    final difference = now.difference(joinTime);
    
    if (difference.inMinutes < 1) {
      return 'Just joined';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
