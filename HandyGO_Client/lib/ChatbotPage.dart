import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatbotPage extends StatefulWidget {
  final String userName;
  final String userId;

  const ChatbotPage({
    Key? key,
    required this.userName,
    required this.userId,
  }) : super(key: key);

  @override
  _ChatbotPageState createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _showOptionsMenu = true; // Added to control options menu visibility
  
  // Default API URL - will be replaced with stored value if available
  String _apiUrl = 'https://f318-2001-f40-960-ab4-b8b3-78fa-690e-39ab.ngrok-free.app/webhooks/rest/webhook';

  @override
  void initState() {
    super.initState();
    // Load saved API URL
    _loadApiUrl();
    // Initialize user session with backend
    _initializeUserSession();
    // Add welcome message
    _addBotMessage("Hi ${widget.userName}!! I'm HandyBot 🤖. How can I help you today?\n\n"
                  "You can ask me things like:\n"
                  "• \"My pipe is leaking\"\n"
                  "• \"I want to book a handyman because my wooden fence needs repair, I want to book at 29/5 at 3pm\"\n"
                  "• \"I need someone to fix my door that won't close properly\"");
  }

  // Load saved API URL from SharedPreferences
  Future<void> _loadApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('rasa_api_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      setState(() {
        _apiUrl = savedUrl;
      });
      print('Loaded API URL: $_apiUrl');
    }
  }

  // Save API URL to SharedPreferences
  Future<void> _saveApiUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rasa_api_url', url);
    print('Saved API URL: $url');
  }

  // Initialize user session with RASA server
  Future<void> _initializeUserSession() async {
    try {
      // Send initialization request to RASA
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sender': widget.userId,
          'message': '/initialize_user_session',
          'metadata': {
            'user_id': widget.userId,
            'user_name': widget.userName,
          }
        }),
      );

      if (response.statusCode != 200) {
        print('Failed to initialize user session: ${response.statusCode}');
      }
    } catch (e) {
      print('Error initializing user session: $e');
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    // Get user message
    final userMessage = _messageController.text.trim();
    
    // Clear text field
    _messageController.clear();
    
    // Add user message to chat
    setState(() {
      _messages.add(ChatMessage(
        text: userMessage,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });

    // Scroll to bottom
    _scrollToBottom();

    try {
      // Send message to RASA server
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sender': widget.userId,
          'message': userMessage,
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> botResponses = json.decode(response.body);
        
        // Add slight delay to feel more natural
        await Future.delayed(const Duration(milliseconds: 500));
        
        setState(() {
          _isTyping = false;
          
          if (botResponses.isEmpty) {
            _messages.add(ChatMessage(
              text: "I'm sorry, I didn't understand that. Can you try rephrasing?",
              isUser: false,
              timestamp: DateTime.now(),
            ));
          } else {
            for (var botResponse in botResponses) {
              // Get the message text once at the beginning
              final messageText = botResponse['text'] ?? "";
              
              // Check if this is a handyman list response in the json_message structure
              if (botResponse.containsKey('json_message')) {
                if (botResponse['json_message'] != null && 
                    botResponse['json_message'] is Map &&
                    botResponse['json_message']['custom'] == 'handyman_list') {
                  
                  try {
                    var handymenList = botResponse['json_message']['handymen'];
                    if (handymenList is List) {
                      final handymen = List<Map<String, dynamic>>.from(handymenList);
                      
                      _messages.add(ChatMessage(
                        text: messageText,
                        isUser: false,
                        timestamp: DateTime.now(),
                        handymen: handymen,
                      ));
                      continue;  // Skip further processing for this message
                    }
                  } catch (e) {
                    print("Error processing handymen from json_message: $e");
                  }
                }
              }
              
              // Check if this is a handyman list response in custom field
              if (botResponse.containsKey('custom') && 
                  botResponse['custom'] is Map &&
                  botResponse['custom']['custom'] == 'handyman_list' &&
                  botResponse['custom']['handymen'] is List) {
                  
                final handymen = List<Map<String, dynamic>>.from(botResponse['custom']['handymen'] as List);
                
                _messages.add(ChatMessage(
                  text: messageText,
                  isUser: false,
                  timestamp: DateTime.now(),
                  handymen: handymen,
                ));
              } else if (botResponse.containsKey('custom_json') && 
                        botResponse['custom_json'] is Map &&
                        botResponse['custom_json']['custom'] == 'handyman_list' &&
                        botResponse['custom_json']['handymen'] is List) {
                        
                final handymen = List<Map<String, dynamic>>.from(botResponse['custom_json']['handymen'] as List);
                
                _messages.add(ChatMessage(
                  text: messageText,
                  isUser: false,
                  timestamp: DateTime.now(),
                  handymen: handymen,
                ));
              } else {
                // Regular text message
                _messages.add(ChatMessage(
                  text: messageText,
                  isUser: false,
                  timestamp: DateTime.now(),
                  buttons: botResponse['buttons'] != null 
                      ? List<Map<String, dynamic>>.from(botResponse['buttons'])
                      : null,
                ));
              }
            }
          }
        });
        
        _scrollToBottom();
      }
      else {
        _addBotMessage("Sorry, I'm having trouble connecting. Please try again later.");
      }
    } catch (e) {
      _addBotMessage("Sorry, I'm having trouble connecting. Please try again later.");
    } finally {
      setState(() {
        _isTyping = false;
      });
    }
  }

  // Modified button handling
  void _handleButtonClick(Map<String, dynamic> button) {
    setState(() {
      _showOptionsMenu = false;
    });
    
    // Use payload instead of title
    String payload = button['payload'] ?? button['title'];
    _messageController.text = payload;
    _sendMessage();
    
    // Restore options menu after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showOptionsMenu = true;
        });
      }
    });
  }
  
  // Function to handle handyman selection from cards
  void _handleHandymanSelected(String handymanName, String handymanId) {
    setState(() {
      _showOptionsMenu = false;
    });
    
    // Store the full structured command
    String fullCommand = "/select_handyman{\"handyman_id\":\"" + handymanId + "\",\"handyman_name\":\"" + handymanName + "\"}";
    
    // Display a user-friendly message in the chat
    setState(() {
      _messages.add(ChatMessage(
        text: "Selected $handymanName",
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });
    
    _scrollToBottom();
    
    // Send the structured command directly without updating the text field
    _sendStructuredCommand(fullCommand);
    
    // Restore options menu after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showOptionsMenu = true;
        });
      }
    });
  }

  // Helper method to send structured commands without showing them in the UI
  void _sendStructuredCommand(String command) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sender': widget.userId,
          'message': command,
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> botResponses = json.decode(response.body);
        
        // Add slight delay to feel more natural
        await Future.delayed(const Duration(milliseconds: 500));
        
        setState(() {
          _isTyping = false;
          
          if (botResponses.isEmpty) {
            _messages.add(ChatMessage(
              text: "I'm sorry, I didn't understand that. Can you try rephrasing?",
              isUser: false,
              timestamp: DateTime.now(),
            ));
          } else {
            // Process bot responses exactly as in _sendMessage
            // This is the same code from your _sendMessage method
            for (var botResponse in botResponses) {
              // Get the message text once at the beginning
              final messageText = botResponse['text'] ?? "";
              
              // Check if this is a handyman list response in the json_message structure
              if (botResponse.containsKey('json_message')) {
                if (botResponse['json_message'] != null && 
                    botResponse['json_message'] is Map &&
                    botResponse['json_message']['custom'] == 'handyman_list') {
                  
                  try {
                    var handymenList = botResponse['json_message']['handymen'];
                    if (handymenList is List) {
                      final handymen = List<Map<String, dynamic>>.from(handymenList);
                      
                      _messages.add(ChatMessage(
                        text: messageText,
                        isUser: false,
                        timestamp: DateTime.now(),
                        handymen: handymen,
                      ));
                      continue;  // Skip further processing for this message
                    }
                  } catch (e) {
                    print("Error processing handymen from json_message: $e");
                  }
                }
              }
              
              // Check if this is a handyman list response in custom field
              if (botResponse.containsKey('custom') && 
                  botResponse['custom'] is Map &&
                  botResponse['custom']['custom'] == 'handyman_list' &&
                  botResponse['custom']['handymen'] is List) {
                  
                final handymen = List<Map<String, dynamic>>.from(botResponse['custom']['handymen'] as List);
                
                _messages.add(ChatMessage(
                  text: messageText,
                  isUser: false,
                  timestamp: DateTime.now(),
                  handymen: handymen,
                ));
              } else if (botResponse.containsKey('custom_json') && 
                        botResponse['custom_json'] is Map &&
                        botResponse['custom_json']['custom'] == 'handyman_list' &&
                        botResponse['custom_json']['handymen'] is List) {
                        
                final handymen = List<Map<String, dynamic>>.from(botResponse['custom_json']['handymen'] as List);
                
                _messages.add(ChatMessage(
                  text: messageText,
                  isUser: false,
                  timestamp: DateTime.now(),
                  handymen: handymen,
                ));
              } else {
                // Regular text message
                _messages.add(ChatMessage(
                  text: messageText,
                  isUser: false,
                  timestamp: DateTime.now(),
                  buttons: botResponse['buttons'] != null 
                      ? List<Map<String, dynamic>>.from(botResponse['buttons'])
                      : null,
                ));
              }
            }
          }
        });
        
        _scrollToBottom();
      }
      else {
        _addBotMessage("Sorry, I'm having trouble connecting. Please try again later.");
      }
    } catch (e) {
      _addBotMessage("Sorry, I'm having trouble connecting. Please try again later.");
    } finally {
      setState(() {
        _isTyping = false;
      });
    }
  }

  void _addBotMessage(String message) {
    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Open dialog to change API URL
  void _showChangeApiUrlDialog() {
    final TextEditingController urlController = TextEditingController(text: _apiUrl);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Change API URL'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter the new Rasa API URL:'),
              SizedBox(height: 10),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  hintText: 'https://your-rasa-url.com/webhooks/rest/webhook',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                autocorrect: false,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                final newUrl = urlController.text.trim();
                if (newUrl.isNotEmpty) {
                  setState(() {
                    _apiUrl = newUrl;
                  });
                  _saveApiUrl(newUrl);
                  
                  // Add system message indicating URL change
                  _addBotMessage("API URL has been updated to:\n$newUrl");
                }
                Navigator.of(context).pop();
              },
              child: Text('SAVE'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'HandyBot Assistant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          // Conditionally show the 3-dot menu button
          if (_showOptionsMenu)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'change_api') {
                  _showChangeApiUrlDialog();
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'change_api',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: Colors.grey[700]),
                      SizedBox(width: 8),
                      Text('Change API URL'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.grey.shade100,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _buildMessageWidget(message);
                },
              ),
            ),
          ),
          
          // Bot "typing" indicator
          if (_isTyping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPulsingDot(),
                    SizedBox(width: 4),
                    _buildPulsingDot(delay: 100),
                    SizedBox(width: 4),
                    _buildPulsingDot(delay: 200),
                  ],
                ),
              ),
            ),
          
          // Input area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  mini: true,
                  backgroundColor: Colors.blue,
                  child: Icon(
                    Icons.send,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Add padding for iPhones with notch
          MediaQuery.of(context).padding.bottom > 0
              ? SizedBox(height: MediaQuery.of(context).padding.bottom)
              : const SizedBox(height: 0),
        ],
      ),
    );
  }

  Widget _buildPulsingDot({int delay = 0}) {
    return TweenAnimationBuilder(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      builder: (context, double value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.withOpacity(0.5 + (value * 0.5)),
          ),
        );
      },
    );
  }

  Widget _buildMessageWidget(ChatMessage message) {
    // Create a simplified text version for handyman data or booking slots
    Widget messageContent;
    
    // Check if this is a message containing booking slots
    if (message.text.contains("is available at the following times:") && !message.isUser) {
      // This is a booking availability message - parse and format it
      List<Widget> slotWidgets = [];
      
      // Add the title
      slotWidgets.add(
        Text(
          message.text.split("\n")[0], // Just the first line "X is available at the following times:"
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        )
      );
      
      slotWidgets.add(SizedBox(height: 12));
      
      // Parse the slot information from the rest of the text
      List<String> daySlots = message.text.split("\n");
      daySlots.removeAt(0); // Remove the first line (title)
      
      // Group slots by day
      Map<String, List<String>> slotsByDay = {};
      RegExp dateRegex = RegExp(r'(\w+) \((\d{4}-\d{2}-\d{2})\): (.+)');
      
      for (var daySlot in daySlots) {
        var match = dateRegex.firstMatch(daySlot);
        if (match != null) {
          String dayName = match.group(1)!;
          String dateStr = match.group(2)!;
          String slotsStr = match.group(3)!;
          
          List<String> slotsList = slotsStr.split(', ');
          
          // Map slot names to friendly times
          Map<String, String> slotToTime = {
            "Slot 1": "8:00 AM - 12:00 PM",
            "Slot 2": "1:00 PM - 5:00 PM",
            "Slot 3": "6:00 PM - 10:00 PM",
          };
          
          // Create a day container with its available slots
          slotWidgets.add(
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$dayName (${_formatDateString(dateStr)})",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Divider(),
                  ...slotsList.map((slotName) => 
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.symmetric(vertical: 4),
                      child: ElevatedButton(
                        onPressed: () {
                          // Format a structured command to book this slot
                          String command = "book ${dateStr} ${slotName}";
                          _messageController.text = command;
                          _sendMessage();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.blue.shade200),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(slotToTime[slotName] ?? slotName),
                      ),
                    )
                  ).toList(),
                ],
              ),
            )
          );
        }
      }
      
      messageContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: slotWidgets,
      );
    }
    else if (message.handymen != null && message.handymen!.isNotEmpty) {
      // Existing handyman display code...
      List<Widget> handymenTexts = [];
      
      // Add the main message first
      handymenTexts.add(
        Text(
          message.text,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
          ),
        )
      );
      
      handymenTexts.add(SizedBox(height: 8));
      
      // Add each handyman as a text entry with button
      for (var handyman in message.handymen!) {
        handymenTexts.add(
          Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "- ${handyman['name'] ?? 'Unknown'} (${handyman['rating'] ?? '0.0'}★)",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text("  Location: ${handyman['city'] ?? 'Unknown'}"),
                Text("  Expertise: ${handyman['expertise'] ?? 'General'}"),
                SizedBox(height: 4),
                ElevatedButton(
                  onPressed: () => _handleHandymanSelected(
                    handyman['name'] ?? 'Unknown',
                    handyman['id'] ?? ''
                  ),
                  child: Text("Select ${handyman['name']}"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          )
        );
      }
      
      messageContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: handymenTexts,
      );
    } else {
      // Regular text message
      messageContent = Text(
        message.text,
        style: TextStyle(
          color: message.isUser ? Colors.white : Colors.black87,
        ),
      );
    }
  
    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.only(
        left: message.isUser ? 80 : 0,
        right: message.isUser ? 0 : 80,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: message.isUser ? Colors.blue : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!message.isUser)
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  radius: 16,
                  child: Icon(
                    Icons.smart_toy,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              if (!message.isUser) SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    messageContent,
                    SizedBox(height: 4),
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: message.isUser ? Colors.white70 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (message.isUser)
                CircleAvatar(
                  backgroundColor: Colors.orange,
                  radius: 16,
                  child: Text(
                    "F",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
          
          // Show buttons if available and not clicked yet
          if (message.buttons != null && message.buttons!.isNotEmpty && !message.buttonsClicked)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.buttons!.map((button) {
                  return ElevatedButton(
                    onPressed: () {
                      // Mark this message's buttons as clicked
                      _markMessageButtonsClicked(message);
                      // Pass the whole button object, not just the title
                      _handleButtonClick(button);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade100,
                      foregroundColor: Colors.blue.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(button['title']),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // Method to mark a message's buttons as clicked
  void _markMessageButtonsClicked(ChatMessage message) {
    setState(() {
      // Find the message in the list and mark its buttons as clicked
      final index = _messages.indexOf(message);
      if (index != -1) {
        _messages[index] = ChatMessage(
          text: message.text,
          isUser: message.isUser,
          timestamp: message.timestamp,
          buttons: message.buttons,
          handymen: message.handymen,
          buttonsClicked: true,
        );
      }
    });
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// ChatMessage class
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<dynamic>? buttons;
  final List<Map<String, dynamic>>? handymen;
  final bool buttonsClicked;  // Added property to track button click status
  
  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.buttons,
    this.handymen,
    this.buttonsClicked = false,  // Default to false (buttons not clicked)
  });
}

// Add this helper method for better date formatting
String _formatDateString(String dateStr) {
  try {
    final date = DateTime.parse(dateStr);
    return DateFormat('MMM d, yyyy').format(date); // e.g., "May 6, 2025"
  } catch (e) {
    return dateStr; // Return original if parsing fails
  }
}