<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

require_once 'config.php';

$conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);

if ($conn->connect_error) {
    die(json_encode(["error" => "Database connection failed", "success" => false]));
}

$json = file_get_contents('php://input');
$data = json_decode($json, true);

if (json_last_error() !== JSON_ERROR_NONE) {
    die(json_encode(["error" => "Invalid JSON input", "success" => false]));
}

$contactNumber = $data['contactNumber'] ?? '';

// Validate contact number format (should be 10 digits starting with 9)
if (!preg_match('/^9\d{9}$/', $contactNumber)) {
    die(json_encode(["error" => "Invalid contact number format. Must be 10 digits starting with 9", "success" => false]));
}

// Format the contact number with +63 prefix for database checking
$formattedContactNumber = '+63' . $contactNumber;

// Check in candidate table using formatted number
$stmt = $conn->prepare("SELECT candidateID FROM candidate WHERE contactNumber = ?");
$stmt->bind_param("s", $formattedContactNumber);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    echo json_encode(["exists" => true, "type" => "candidate", "success" => true]);
    exit();
}

// Check in voter table using formatted number
$stmt = $conn->prepare("SELECT voterID FROM voter WHERE contactNumber = ?");
$stmt->bind_param("s", $formattedContactNumber);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    echo json_encode(["exists" => true, "type" => "voter", "success" => true]);
    exit();
}

echo json_encode(["exists" => false, "success" => true]);
$conn->close();
?>