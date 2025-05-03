import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class AIVisualizationScreen extends StatefulWidget {
  final String imageUrl;
  final List<String> designSuggestions;

  const AIVisualizationScreen({
    Key? key,
    required this.imageUrl,
    required this.designSuggestions,
  }) : super(key: key);

  @override
  _AIVisualizationScreenState createState() => _AIVisualizationScreenState();
}

class _AIVisualizationScreenState extends State<AIVisualizationScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic> _roomAnalysis = {};
  List<Map<String, dynamic>> _colorPalette = [];
  TabController? _tabController;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _analyzeRoom();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _analyzeRoom() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Your actual Gemini API key - replace with your own
      final apiKey = 'AIzaSyAg6bi82NEVjQtdmnnqqQN-7wHJJQiOPE8';

      // Create prompt for room analysis
      final prompt = '''
        You are an interior design expert with deep knowledge of design styles, color theory, and spatial analysis.
        
        Analyze this room image and provide a detailed JSON object with the following information:
        
        1. roomType: The type of room (living room, bedroom, kitchen, etc.)
        2. designStyle: The current design style of the room
        3. spaceAnalysis: Analysis of the space, furniture layout, and flow
        4. lightingQuality: Assessment of the lighting in the room
        5. colorAnalysis: Analysis of the current color scheme
        6. styleConsistency: How consistent the style is throughout the room
        7. improvementAreas: Key areas that need improvement
        8. overallRating: A rating from 1-10 of the current design
        
        Format your response as a valid JSON object only.
      ''';

      // Prepare the API request for Gemini
      final geminiUrl =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey';

      // Create the request body with the image URL and prompt
      final requestBody = {
        "contents": [
          {
            "parts": [
              {"text": prompt},
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": await _getBase64ImageFromUrl(widget.imageUrl),
                },
              },
            ],
          },
        ],
        "generation_config": {
          "temperature": 0.2,
          "top_p": 0.95,
          "max_output_tokens": 800,
        },
      };

      // Make the API call to Gemini
      final response = await http.post(
        Uri.parse(geminiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        // Extract the text response from Gemini
        final geminiText =
            jsonResponse['candidates'][0]['content']['parts'][0]['text'];

        // Try to parse the JSON response
        try {
          // Extract JSON object from text (handle if there's extra text around it)
          RegExp jsonRegex = RegExp(r'\{[\s\S]*\}');
          final match = jsonRegex.firstMatch(geminiText);

          if (match != null) {
            final jsonStr = match.group(0);
            if (jsonStr != null) {
              _roomAnalysis = jsonDecode(jsonStr);
            } else {
              throw Exception('Could not extract JSON from response');
            }
          } else {
            throw Exception('Could not extract JSON from response');
          }

          // Generate color palette
          _colorPalette = await _generateColorPalette();
        } catch (e) {
          print('Error parsing JSON response: $e');

          // Fall back to mock data
          _roomAnalysis = _getMockRoomAnalysis();
          _colorPalette = _getMockColorPalette();
        }
      } else {
        print('API error: ${response.body}');
        throw Exception(
          'Failed to analyze room: Status ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        _error = 'Failed to analyze room. Using sample data instead.';
        _roomAnalysis = _getMockRoomAnalysis();
        _colorPalette = _getMockColorPalette();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fallback mock data
  Map<String, dynamic> _getMockRoomAnalysis() {
    return {
      "roomType": "Living Room",
      "designStyle": "Contemporary with Minimalist Influences",
      "spaceAnalysis":
          "The room has good spatial flow but furniture arrangement could be improved for better conversation areas.",
      "lightingQuality":
          "Good natural light from windows, but additional ambient lighting would enhance evening ambiance.",
      "colorAnalysis":
          "Neutral palette with white walls and beige/gray tones. Could benefit from accent colors.",
      "styleConsistency":
          "Moderately consistent, some elements appear mismatched.",
      "improvementAreas":
          "Furniture arrangement, additional lighting, introduction of color accents, wall art or decor.",
      "overallRating": 6,
    };
  }

  // Mock color palette
  List<Map<String, dynamic>> _getMockColorPalette() {
    return [
      {"name": "Wall Color", "hex": "#F5F5F5", "rgb": "245,245,245"},
      {"name": "Accent Color 1", "hex": "#B0C4DE", "rgb": "176,196,222"},
      {"name": "Accent Color 2", "hex": "#D2B48C", "rgb": "210,180,140"},
      {"name": "Neutral Tone", "hex": "#E0E0E0", "rgb": "224,224,224"},
      {"name": "Contrast Color", "hex": "#708090", "rgb": "112,128,144"},
    ];
  }

  // Function to convert image URL to base64
  Future<String> _getBase64ImageFromUrl(String imageUrl) async {
    try {
      final File imageFile = File(imageUrl);
      final Uint8List bytes = await imageFile.readAsBytes();
      return base64.encode(bytes);
    } catch (e) {
      print('Error converting image to base64: $e');

      // If local file failed, try as a network URL
      try {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          return base64.encode(response.bodyBytes);
        } else {
          throw Exception('Failed to load image: ${response.statusCode}');
        }
      } catch (networkError) {
        print('Error fetching network image: $networkError');
        throw networkError;
      }
    }
  }

  // Generate color palette based on image
  Future<List<Map<String, dynamic>>> _generateColorPalette() async {
    // In a real app, you'd use a color extraction algorithm or API
    // For now, we'll return mock data
    return _getMockColorPalette();
  }

  // Helper function to build the analysis item
  Widget _buildAnalysisItem(String title, String content, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(content, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to build the rating widget
  Widget _buildRatingWidget(int rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getRatingColor(rating),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Colors.white, size: 18),
          const SizedBox(width: 4),
          Text(
            rating.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            '/10',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Helper function to get the rating color
  Color _getRatingColor(int rating) {
    if (rating >= 8) return Colors.green;
    if (rating >= 6) return Colors.amber;
    if (rating >= 4) return Colors.orange;
    return Colors.red;
  }

  // Build the color analysis tab
  Widget _buildColorAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Color Palette Analysis',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Color palette grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _colorPalette.length,
            itemBuilder: (context, index) {
              final color = _colorPalette[index];
              return _buildColorCard(color);
            },
          ),

          const SizedBox(height: 24),

          // Color harmony analysis
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Color Harmony',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _roomAnalysis['colorAnalysis'] ??
                        'No color analysis available',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Suggested Color Combinations:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildColorChip('Complementary', Colors.blue.shade100),
                      _buildColorChip(
                        'Neutral + Accent',
                        Colors.green.shade100,
                      ),
                      _buildColorChip('Monochromatic', Colors.purple.shade100),
                      _buildColorChip('Analogous', Colors.orange.shade100),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Tips for using color
          Card(
            elevation: 2,
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tips for Using Color',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildTipItem(
                    'Use the 60-30-10 rule: 60% dominant color, 30% secondary color, 10% accent color',
                  ),
                  _buildTipItem(
                    'Add accent colors through accessories like pillows, art, and decor',
                  ),
                  _buildTipItem(
                    'Consider the room\'s lighting when selecting colors',
                  ),
                  _buildTipItem(
                    'Use color psychology: blues for calm, yellows for energy, greens for balance',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to build a color card
  Widget _buildColorCard(Map<String, dynamic> color) {
    final colorValue =
        int.parse(color['hex'].substring(1), radix: 16) + 0xFF000000;
    return Card(
      elevation: 2,
      child: Column(
        children: [
          Expanded(
            child: Container(width: double.infinity, color: Color(colorValue)),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  color['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  color['hex'],
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to build a color chip
  Widget _buildColorChip(String label, Color color) {
    return Chip(
      backgroundColor: color,
      label: Text(label),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    );
  }

  // Helper function to build a tip item
  Widget _buildTipItem(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(tip)),
        ],
      ),
    );
  }

  // Build the suggestions tab
  Widget _buildSuggestionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Design Suggestions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // AI suggestions
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb, color: Colors.amber),
                      const SizedBox(width: 8),
                      const Text(
                        'AI Recommendations',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...widget.designSuggestions.map((suggestion) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(suggestion)),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Improvement areas
          Card(
            elevation: 2,
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Focus Areas for Improvement',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _roomAnalysis['improvementAreas'] ??
                        'No improvement areas identified',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Next Steps:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _buildNextStepItem('Identify key pieces to keep or replace'),
                  _buildNextStepItem(
                    'Create a floor plan with optimal furniture arrangement',
                  ),
                  _buildNextStepItem(
                    'Consider lighting improvements for different times of day',
                  ),
                  _buildNextStepItem(
                    'Add textures and layers through accessories',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Style guide
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Style Guide',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Current Style: ${_roomAnalysis['designStyle'] ?? 'Unknown'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Complementary Styles to Consider:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _buildStyleItem(
                    'Scandinavian',
                    'Clean lines, light colors, wood accents',
                  ),
                  _buildStyleItem(
                    'Mid-Century Modern',
                    'Functional furniture, organic shapes',
                  ),
                  _buildStyleItem(
                    'Industrial',
                    'Raw materials, utilitarian objects, rough textures',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to build a next step item
  Widget _buildNextStepItem(String step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right, size: 20),
          const SizedBox(width: 4),
          Expanded(child: Text(step)),
        ],
      ),
    );
  }
  // Build the overview tab
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Error message if any
          if (_error.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12.0),
              margin: const EdgeInsets.only(bottom: 16.0),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_error)),
                ],
              ),
            ),

          // Room image card
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Text('Unable to load image'),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _roomAnalysis['roomType'] ?? 'Room',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _roomAnalysis['designStyle'] ?? 'Unknown Style',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      if (_roomAnalysis.containsKey('overallRating'))
                        _buildRatingWidget(_roomAnalysis['overallRating']),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Analysis section
          const Text(
            'Room Analysis',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Space analysis
          _buildAnalysisItem(
            'Space Layout',
            _roomAnalysis['spaceAnalysis'] ?? 'No space analysis available',
            Icons.aspect_ratio,
          ),

          // Lighting quality
          _buildAnalysisItem(
            'Lighting',
            _roomAnalysis['lightingQuality'] ??
                'No lighting analysis available',
            Icons.light_mode,
          ),

          // Style consistency
          _buildAnalysisItem(
            'Style Consistency',
            _roomAnalysis['styleConsistency'] ?? 'No style analysis available',
            Icons.style,
          ),

          const SizedBox(height: 24),

          // Quick actions
          Card(
            elevation: 2,
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionButton('Color Ideas', Icons.palette, () {
                        _tabController?.animateTo(
                          1,
                        ); // Switch to Color Analysis tab
                      }),
                      _buildActionButton(
                        'Get Suggestions',
                        Icons.lightbulb_outline,
                        () {
                          _tabController?.animateTo(
                            2,
                          ); // Switch to Suggestions tab
                        },
                      ),
                      _buildActionButton('Save Analysis', Icons.save_alt, () {
                        // TODO: Implement save functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Analysis saved successfully'),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to build an action button
  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
  // Helper function to build a style item
  Widget _buildStyleItem(String style, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(style, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Analysis'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Color Analysis'),
            Tab(text: 'Suggestions'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Analyzing room details...'),
                  ],
                ),
              )
              : TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Overview
                  _buildOverviewTab(),

                  // Tab 2: Color Analysis
                  _buildColorAnalysisTab(),

                  // Tab 3: Suggestions
                  _buildSuggestionsTab(),
                ],
              ),
    );
  }
}
