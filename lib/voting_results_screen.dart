import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;

class VotingResultsScreen extends StatefulWidget {
  const VotingResultsScreen({super.key});

  @override
  VotingResultsScreenState createState() => VotingResultsScreenState();
}

class VotingResultsScreenState extends State<VotingResultsScreen> {
  Map<String, int> votes = {};
  bool isLoading = true;
  String? errorMessage;
  Map<String, Map<String, dynamic>> candidateDetails = {};
  String? selectedCandidateCode;

  @override
  void initState() {
    super.initState();
    fetchVotes();
    fetchCandidateDetails();
    Timer.periodic(const Duration(seconds: 5), (timer) {
      fetchVotes();
    });
  }

  Future<void> fetchCandidateDetails() async {
    try {
      final response = await http
          .get(Uri.parse('http://192.168.100.186/voting/get_candidates.php'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          candidateDetails = Map<String, Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      // Error fetching candidate details
      debugPrint('Error fetching candidate details: $e');
    }
  }

  Future<void> fetchVotes() async {
    try {
      final response = await http
          .get(Uri.parse('http://192.168.100.186/voting/get_votes.php'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          votes = Map<String, int>.from(json.decode(response.body));
          isLoading = false;
          errorMessage = null;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load data: ${response.statusCode}';
        });
      }
    } on TimeoutException {
      setState(() {
        isLoading = false;
        errorMessage = 'Request timed out. Check your connection.';
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'No data for all positions available.';
      });
    }
  }

  List<PieChartSectionData> getChartData(String prefix) {
    final relevantEntries =
        votes.entries.where((e) {
          if (prefix == 'PRO') {
            return e.key.startsWith('PRO');
          }
          return e.key.startsWith(prefix) &&
              e.key.length > 1 &&
              !e.key.startsWith('PRO');
        }).toList();

    if (relevantEntries.isEmpty) return [];

    int total = relevantEntries.fold(0, (sum, e) => sum + e.value);
    if (total == 0) return [];

    final List<Color> customColors = [
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.redAccent,
      Colors.purpleAccent,
      Colors.tealAccent,
      Colors.amberAccent,
      Colors.cyanAccent,
    ];

    return relevantEntries
        .asMap()
        .map(
          (index, e) => MapEntry(
            index,
            PieChartSectionData(
              value: (e.value / total) * 100,
              title:
                  '${e.key}\n${e.value} votes\n${(e.value / total * 100).toStringAsFixed(1)}%',
              color: customColors[index % customColors.length],
              radius: 80,
              badgeWidget: _buildBadge(e.key),
              badgePositionPercentageOffset: 0.98,
              showTitle: true,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        )
        .values
        .toList();
  }

  Widget _buildBadge(String candidateCode) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCandidateCode = candidateCode;
        });
        _showCandidateDetails(candidateCode);
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.info_outline, size: 16, color: Colors.black),
      ),
    );
  }

  void _showCandidateDetails(String candidateCode) {
    if (!candidateDetails.containsKey(candidateCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Candidate details not available')),
      );
      return;
    }

    final candidate = candidateDetails[candidateCode]!;
    final imageBytes =
        candidate['picture'] != null
            ? base64.decode(candidate['picture'])
            : null;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('${candidate['position']} Candidate'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (imageBytes != null)
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          fit: BoxFit.cover,
                          image: MemoryImage(imageBytes),
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.person, size: 120),
                  const SizedBox(height: 16),
                  Text(
                    '${candidate['firstName']} ${candidate['middleName']} ${candidate['lastName']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Running for: ${candidate['position']}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Candidate Code: $candidateCode',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget buildPieChart(String title, String prefix) {
    final chartData = getChartData(prefix);
    if (chartData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: ListTile(
          title: Text(title),
          subtitle: const Text('No data available'),
        ),
      );
    }

    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sections: chartData,
                  centerSpaceRadius: 50,
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voting Results'), centerTitle: true),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Center(
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 18),
                ),
              )
              : SingleChildScrollView(
                child: Column(
                  children: [
                    buildPieChart('President', 'P'),
                    buildPieChart('Vice President', 'V'),
                    buildPieChart('Secretary', 'S'),
                    buildPieChart('Treasurer', 'T'),
                    buildPieChart('Auditor', 'A'),
                    buildPieChart('Business Manager', 'B'),
                    buildPieChart('Press Relation Officer', 'PRO'),
                  ],
                ),
              ),
    );
  }
}
