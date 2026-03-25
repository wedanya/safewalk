class IncidentModel {
  final String? id;
  final String type;
  final String location;
  final String timestamp;
  final String status; // e.g., "Pending", "Verified"
  final String? description;

  IncidentModel({
    this.id,
    required this.type,
    required this.location,
    required this.timestamp,
    required this.status,
    this.description,
  });

  // Convert JSON from Flask into this Dart object
  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      id: json['id']?.toString(),
      type: json['type'] ?? 'Unknown',
      location: json['location'] ?? 'Unknown Location',
      timestamp: json['timestamp'] ?? '',
      status: json['status'] ?? 'Pending',
      description: json['description'],
    );
  }

  // Convert this Dart object into JSON to send to Flask
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'location': location,
      'timestamp': timestamp,
      'status': status,
      'description': description,
    };
  }
}